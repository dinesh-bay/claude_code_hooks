# Combined PreToolUse Script

One script that replaces 10 individual PreToolUse hooks. Same protection, one process instead of ten.

## What This Replaces

This single script combines the PreToolUse checks from:

| # | Hook | What it checks |
|---|------|---------------|
| 1 | Block Destructive Commands | `rm -rf`, `git reset --hard`, `format C:` |
| 2 | Critical File Guard | `.env`, Dockerfiles, CI configs |
| 3 | Large File Overwrite Guard | Files with 300+ lines |
| 4 | Scope Boundary Guard | Writes outside project directory |
| 5 | Secret Scanner | API keys, tokens, passwords in content |
| 6 | Uncommitted Work Guard | Destructive git ops with dirty worktree |
| 7 | Branch Protection | Force push, push to main/master |
| 8 | Dependency Change Guard | package.json, requirements.txt, lock files |
| 11 | Dangerous Interpreter Guard | Long inline `python -c`, `node -e` |
| 12 | Test File Deletion Guard | Deleting or gutting test files |

## Performance Gain

| Setup | Processes per tool call | Overhead |
|-------|------------------------|----------|
| 10 individual hooks | 10 PowerShell processes | 5+ seconds |
| Combined script | 1 PowerShell process | ~0.5 seconds |

The combined script runs all checks sequentially inside a single process. PowerShell startup (~200-500ms) happens once instead of ten times.

## How To Use

Use this **instead of** the individual hooks listed above, not in addition to them. If you install both, checks will run twice.

### Step 1: Copy the script

**Windows:**
```
copy optimized\combined-pretooluse.ps1 C:\Users\YOUR_USERNAME\.claude\hooks\combined-pretooluse.ps1
```

**macOS/Linux:**
```
cp optimized/combined-pretooluse.sh ~/.claude/hooks/combined-pretooluse.sh
chmod +x ~/.claude/hooks/combined-pretooluse.sh
```

### Step 2: Update settings.json

Replace all individual PreToolUse entries for hooks #1, #2, #3, #4, #5, #6, #7, #8, #11, and #12 with a single entry.

**Windows** (`C:\Users\YOUR_USERNAME\.claude\settings.json`):
```json
{
  "hooks": {
    "PreToolUse": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "powershell -NoProfile -ExecutionPolicy Bypass -File C:/Users/YOUR_USERNAME/.claude/hooks/combined-pretooluse.ps1",
            "timeout": 10
          }
        ]
      }
    ]
  }
}
```

**macOS/Linux** (`~/.claude/settings.json`):
```json
{
  "hooks": {
    "PreToolUse": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash ~/.claude/hooks/combined-pretooluse.sh",
            "timeout": 10
          }
        ]
      }
    ]
  }
}
```

No `matcher` is specified -- the script checks `tool_name` internally and applies the right checks for each tool type (Bash, Write, Edit).

### Step 3: Keep the non-PreToolUse hooks

This script only replaces PreToolUse checks. You still need separate hooks for:

| # | Hook | Event | Still needed? |
|---|------|-------|--------------|
| 9 | Pre-Compact Backup | PreCompact | Yes -- different event |
| 10 | Mass Change Detector | PostToolUse | Yes -- runs after, not before |
| 13 | Sound on Completion | Notification | Yes -- different event |
| 14 | Desktop Toast | Notification | Yes -- different event |
| 15 | Session Summary on Exit | Stop | Yes -- different event |
| 16 | Copy File Path to Clipboard | PostToolUse | Yes -- runs after |
| 17 | Auto-Format on Save | PostToolUse | Yes -- runs after |
| 18 | Session Context Loader | SessionStart | Yes -- different event |
| 19 | Prompt Sensitive Data Audit | UserPromptSubmit | Yes -- different event |
| 20 | Context Saver | PostToolUse | Yes -- runs after |

## Customizing

The script is organized into three sections: `BASH TOOL CHECKS`, `WRITE TOOL CHECKS`, and `EDIT TOOL CHECKS`. Each check is labeled with its hook number.

**To remove a check:** Delete or comment out the block between its `# Hook #N` comment and the next hook comment.

**To add a check:** Add your pattern matching inside the appropriate tool section. Follow the existing pattern:

```powershell
# Hook #99: My Custom Check
if ($command -match 'my-dangerous-pattern') {
    [Console]::Error.WriteLine("BLOCKED [Safety]: Reason for blocking.")
    exit 2
}
```

**To make a check less strict:** Change `exit 2` (block) to a `[Console]::Error.WriteLine()` warning without exiting (log only).

## A complete settings.json with the combined script

This example uses the combined script for PreToolUse plus individual hooks for other events:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "powershell -NoProfile -ExecutionPolicy Bypass -File C:/Users/YOUR_USERNAME/.claude/hooks/combined-pretooluse.ps1",
            "timeout": 10
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Write",
        "hooks": [
          {
            "type": "command",
            "command": "powershell -NoProfile -ExecutionPolicy Bypass -File C:/Users/YOUR_USERNAME/.claude/hooks/copy-file-path.ps1",
            "timeout": 5
          }
        ],
        "async": true
      }
    ],
    "Notification": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "powershell -NoProfile -ExecutionPolicy Bypass -c \"[System.Media.SystemSounds]::Exclamation.Play()\"",
            "timeout": 5
          }
        ]
      }
    ],
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "powershell -NoProfile -ExecutionPolicy Bypass -File C:/Users/YOUR_USERNAME/.claude/hooks/prompt-sensitive-data-audit.ps1",
            "timeout": 5
          }
        ]
      }
    ]
  }
}
```

Replace `YOUR_USERNAME` with your actual Windows username.
