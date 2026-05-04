# Test File Deletion Guard

> Prevents Claude from deleting test files or gutting their content through overwrites. Tests are your safety net -- this hook makes sure they stay intact.

**Category:** Human-in-Control
**Event:** PreToolUse
**Matcher:** Bash, Write
**Difficulty:** Intermediate
**Platform:** PowerShell (Windows) | Bash alternative included

## The Problem

Claude sometimes decides that test files are "outdated", "redundant", or "not matching the current implementation" and deletes them. Other times it rewrites a test file from scratch, replacing 200 lines of carefully written assertions with 30 lines of trivial smoke tests.

Both outcomes are bad. Deleting tests removes your safety net. Rewriting tests to match the implementation (instead of fixing the implementation to pass the tests) defeats the purpose of having tests in the first place.

This hook blocks both scenarios:

1. **Deletion via Bash** -- `rm test_auth.py`, `del login.spec.ts`, `Remove-Item conftest.py`
2. **Gutting via Write** -- Overwriting a 150-line test file with a 40-line replacement (more than 50% content loss)

## What It Protects

The hook recognizes test files by their naming patterns:

| Pattern | Matches |
|---------|---------|
| `test_*.py` | Python pytest files (`test_auth.py`, `test_login.py`) |
| `*.spec.ts`, `*.spec.js` | Playwright/Jest/Mocha spec files (`login.spec.ts`) |
| `*.test.ts`, `*.test.js`, `*.test.tsx`, `*.test.jsx` | Jest/Vitest test files (`App.test.tsx`) |
| `*_test.go` | Go test files (`handler_test.go`) |
| `conftest.py` | pytest configuration and fixtures |
| `*.test.py` | Alternative Python test naming (`auth.test.py`) |

## How It Works

### Bash tool (deletion check)

1. Claude calls the Bash tool with a command
2. The hook checks if the command contains `rm`, `del`, or `Remove-Item`
3. If it does, the command is checked against test file patterns
4. **Match found:** exits with code 2 (block) with the message "Tests are your safety net. Fix the tests, don't delete them."
5. **No match:** exits with code 0, command runs normally

### Write tool (content gutting check)

1. Claude calls the Write tool to overwrite a file
2. The hook checks if the target file name matches a test pattern
3. If it does and the file already exists:
   - Counts the existing file's line count
   - Counts the new content's line count
   - If the existing file has more than 10 lines AND the new content is less than 50% of the original, the write is blocked
4. **Blocked:** exits with code 2, tells Claude to use Edit for targeted changes instead
5. **Allowed:** exits with code 0 for new test files, small test files (10 lines or fewer), or rewrites that preserve most of the content

## Installation

### Step 1: Copy the script

Copy `hook.ps1` to your hooks directory:

```
~/.claude/hooks/test-file-deletion-guard.ps1
```

### Step 2: Add to settings.json

Open `~/.claude/settings.json` and add the hook configuration. If you already have a `PreToolUse` section, merge the matcher entry into it.

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash|Write",
        "hooks": [
          {
            "type": "command",
            "command": "powershell -NoProfile -ExecutionPolicy Bypass -File C:/Users/YOUR_USERNAME/.claude/hooks/test-file-deletion-guard.ps1",
            "timeout": 5
          }
        ]
      }
    ]
  }
}
```

Replace `YOUR_USERNAME` with your actual Windows username.

**Linux/macOS:** Use `hook.sh` instead:

```json
{
  "type": "command",
  "command": "bash ~/.claude/hooks/test-file-deletion-guard.sh",
  "timeout": 5
}
```

### Step 3: Restart Claude Code

Close and reopen Claude Code (or start a new session) for the hook to take effect.

## Verify It Works

### Test 1: Deletion block

Create a dummy test file first, then ask Claude to delete it:

```bash
echo "def test_example(): assert True" > test_example.py
```

> "Delete the file test_example.py"

You should see:

```
BLOCKED: Attempted to delete a test file.
Command: rm test_example.py
Tests are your safety net. Fix the tests, don't delete them.
```

### Test 2: Content gutting block

Create a test file with substantial content:

```bash
python3 -c "
with open('test_big.py', 'w') as f:
    for i in range(50):
        f.write(f'def test_case_{i}(): assert True\n')
"
```

> "Rewrite test_big.py to just have one test that checks True"

You should see:

```
BLOCKED: About to overwrite test file test_big.py (50 lines -> 2 lines).
This would remove more than half the test content.
Use Edit for targeted changes instead.
```

Claude will switch to using the Edit tool for targeted modifications rather than a full rewrite.

## Configuration

**Test file patterns:** Add or remove patterns in the `$testPatterns` array at the top of `hook.ps1`:

```powershell
$testPatterns = @(
    'test_.*\.py$',
    '.*\.spec\.(ts|js)$',
    '.*\.test\.(ts|js|tsx|jsx)$',
    '.*_test\.go$',
    'conftest\.py$',
    '.*\.test\.py$'
)
```

**Content loss threshold:** The 50% threshold is hardcoded in the comparison `$newLines -lt ($existingLines * 0.5)`. Change `0.5` to a different ratio if needed. A value of `0.3` would only block rewrites that remove 70% or more of the content.

**Minimum file size:** Files with 10 or fewer lines are always allowed to be overwritten. Change the `$existingLines -gt 10` check to adjust this floor.

## Limitations

- **Pattern-based detection.** A test file named `checks.py` or `verify_auth.py` would not be caught. Only files matching the standard naming conventions are protected.
- **Deletion commands only.** `mv test_auth.py /dev/null` or `> test_auth.py` (truncate) are not caught because they do not use `rm`, `del`, or `Remove-Item`.
- **Write tool only for content check.** The Edit tool is not checked for content gutting because Edit performs targeted replacements rather than full file overwrites. A series of many small edits could gradually hollow out a test file without triggering the hook.
- **Line count is a rough proxy.** A rewrite that keeps the same number of lines but changes every assertion would not be caught. The hook guards against bulk removal, not semantic changes.
- **New test files pass through.** If the file does not exist yet, the Write tool is always allowed. This is intentional -- you want Claude to be able to create new test files.
