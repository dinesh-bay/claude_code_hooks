# Block Destructive Commands

> Intercepts `rm -rf`, `git reset --hard`, and other destructive shell commands before Claude can execute them.

**Category:** Safety
**Event:** PreToolUse
**Matcher:** Bash
**Difficulty:** Starter
**Platform:** PowerShell (Windows) | Bash alternative included

## The Problem

Claude uses the Bash tool to run shell commands. Most of the time this is fine -- it runs `ls`, `git status`, `npm install`. But it can also run `rm -rf .`, `git reset --hard`, or `git clean -fd`, destroying your work with a single tool call. If you clicked "Allow" without reading the command carefully, it is already too late.

This hook inspects every Bash command before execution and blocks the ones that are known to cause data loss.

## What It Blocks

| Pattern | What It Catches | Consequence |
|---------|-----------------|-------------|
| `rm -rf` | Recursive forced deletion | Deletes files and directories without confirmation |
| `rm -r` | Recursive deletion | Deletes files and directories |
| `rm *.ext` | Wildcard deletion | Deletes all files matching a glob |
| `del /s /q` | Windows silent recursive delete | Removes files without prompting |
| `rd /s /q` | Windows directory removal | Removes entire directory trees |
| `rmdir /s /q` | Windows directory removal | Same as `rd /s /q` |
| `git reset --hard` | Hard reset | Discards all uncommitted changes permanently |
| `git checkout .` | Checkout current directory | Discards all unstaged changes |
| `git clean -f`, `-fd` | Clean untracked files | Deletes files git does not track |
| `format X:` | Disk format | Formats an entire drive |

## How It Works

1. Claude calls the Bash tool with a command string
2. The PreToolUse hook fires before execution
3. The script reads the stdin JSON and extracts `tool_input.command`
4. It checks the command against every destructive pattern using regex
5. **Match found:** exits with code 2 (block) and writes a clear reason to stderr
6. **No match:** exits with code 0, Claude runs the command normally

## Installation

### Step 1: Copy the script

Copy `hook.ps1` to your hooks directory:

```
~/.claude/hooks/block-destructive-commands.ps1
```

### Step 2: Add to settings.json

Open `~/.claude/settings.json` and add the hook configuration. If you already have a `hooks` section, merge the `PreToolUse` entry into it.

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "powershell -NoProfile -ExecutionPolicy Bypass -File C:/Users/YOUR_USERNAME/.claude/hooks/block-destructive-commands.ps1",
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
  "command": "bash ~/.claude/hooks/block-destructive-commands.sh",
  "timeout": 5
}
```

### Step 3: Restart Claude Code

Close and reopen Claude Code (or start a new session) for the hook to take effect.

## Verify It Works

Ask Claude:

> "Run `rm -rf /tmp/test` for me"

You should see a block message:

```
BLOCKED: rm -rf /tmp/test
This would recursively delete files and directories.
If intentional, run it manually in your terminal.
```

Claude will not execute the command. It will acknowledge the block and suggest alternatives.

## Configuration

The pattern list is defined at the top of the script in the `$patterns` array. To add a new pattern:

```powershell
@{ Pattern = 'your-regex-here'; Consequence = "what it would do" }
```

To remove a pattern, delete or comment out the corresponding entry.

## Limitations

- **Novel patterns are not caught.** A command like `find / -delete` or `chmod -R 000 /` is destructive but not in the pattern list. This is a blocklist, not a full security boundary.
- **Piped commands are partially covered.** The entire command string is checked, so `echo test | rm -rf /` would match. But `$(rm -rf /)` embedded in a larger command may not be caught depending on how the command is structured.
- **Obfuscation bypasses the check.** A command like `r''m -rf /` or using variables to construct the command would not match the patterns.
- **Only Bash tool calls are checked.** If Claude somehow executes a command through a different mechanism, this hook would not fire.
