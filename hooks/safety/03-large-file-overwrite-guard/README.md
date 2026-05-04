# Large File Overwrite Guard

> Blocks Claude from using the Write tool to overwrite files with 300 or more lines, forcing it to use Edit for targeted changes instead.

**Category:** Safety
**Event:** PreToolUse
**Matcher:** Write
**Difficulty:** Intermediate
**Platform:** PowerShell (Windows) | Bash alternative included

## The Problem

Claude's Write tool replaces the entire file content. When Claude decides to "fix" something in a 500-line file, it regenerates the whole thing from memory. This is where subtle bugs creep in -- dropped lines, changed indentation, reordered imports, removed comments. You asked for a one-line change and got a complete rewrite that silently introduced three regressions.

The Edit tool exists specifically for surgical modifications. This hook enforces that boundary: if the file already exists and is large enough that a full rewrite is risky, Claude must use Edit instead.

This is a novel hook -- no other public repository has it. It catches one of the most common failure modes of AI code editing.

## How It Works

1. Claude calls the Write tool targeting a file path
2. The PreToolUse hook fires before the file is written
3. The script reads the stdin JSON and extracts `tool_input.file_path`
4. It checks whether the file already exists on disk
5. If it exists, it counts the lines in the current file
6. **Line count >= threshold (300):** exits with code 2 (block) and reports the line count
7. **File is new or under the threshold:** exits with code 0, Claude writes normally

New files are always allowed through -- this hook only protects existing files from being overwritten.

## Installation

### Step 1: Copy the script

Copy `hook.ps1` to your hooks directory:

```
~/.claude/hooks/large-file-overwrite-guard.ps1
```

### Step 2: Add to settings.json

Open `~/.claude/settings.json` and add the hook configuration.

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Write",
        "hooks": [
          {
            "type": "command",
            "command": "powershell -NoProfile -ExecutionPolicy Bypass -File C:/Users/YOUR_USERNAME/.claude/hooks/large-file-overwrite-guard.ps1",
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
  "command": "bash ~/.claude/hooks/large-file-overwrite-guard.sh",
  "timeout": 5
}
```

### Step 3: Restart Claude Code

Close and reopen Claude Code (or start a new session) for the hook to take effect.

## Verify It Works

1. Create a test file with 400 lines:

```
python -c "for i in range(400): print(f'line {i}')" > test-large.txt
```

2. Ask Claude:

> "Rewrite test-large.txt with just the word hello"

You should see a block message:

```
BLOCKED: About to overwrite test-large.txt (400 lines).
Use the Edit tool for targeted changes instead of rewriting the entire file.
If a full rewrite is truly needed, run it manually.
```

3. Clean up: `rm test-large.txt`

## Configuration

The line count threshold is defined at the top of the script:

```powershell
$THRESHOLD = 300
```

Adjust this value to match your preference:

- **100** -- aggressive, catches most files worth protecting
- **300** -- balanced default, allows small configs through
- **500** -- conservative, only blocks large source files

## Limitations

- **Only the Write tool is checked.** The Edit tool is intentionally allowed through since it makes targeted changes rather than full rewrites.
- **Line count, not diff size.** The hook does not compare what Claude wants to write versus what is already there. Even if Claude's rewrite is identical to the original file, it will still be blocked if the file exceeds the threshold.
- **Binary files may miscount.** The line counting reads the file as text. Binary files may report incorrect line counts, but this is unlikely to cause false blocks since binary files are rarely targeted by Claude's Write tool.
- **File must exist.** New file creation is always allowed. This hook only protects existing files.
