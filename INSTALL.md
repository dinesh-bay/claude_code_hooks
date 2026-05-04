# Installation Guide

Get your first hook running in under 5 minutes.

---

## Prerequisites

- **Claude Code** installed and working ([official install guide](https://docs.anthropic.com/en/docs/claude-code/overview))
- **PowerShell 5.1+** (comes with Windows 10/11) or **Bash** (macOS/Linux)
- A text editor

## Step 1: Find Your Settings File

Claude Code reads hook configuration from `settings.json`. The file lives at:

| Platform | Path |
|----------|------|
| Windows | `%USERPROFILE%\.claude\settings.json` (typically `C:\Users\<you>\.claude\settings.json`) |
| macOS | `~/.claude/settings.json` |
| Linux | `~/.claude/settings.json` |

If the file does not exist yet, create it. If it already exists, you will add to it.

## Step 2: Create a Hooks Directory

Pick a place to store your hook scripts. This guide uses a `hooks` folder next to your settings file, but any path works.

**Windows (PowerShell):**
```powershell
New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\.claude\hooks"
```

**macOS/Linux (Bash):**
```bash
mkdir -p ~/.claude/hooks
```

## Step 3: Add Your First Hook -- Sound on Completion

This hook plays a system sound whenever Claude finishes a task and needs your input. It is the simplest possible hook -- a good way to verify everything works.

### Create the Script

**Windows -- save as `%USERPROFILE%\.claude\hooks\notify-sound.ps1`:**
```powershell
# Sound on Completion hook
# Plays a system beep when Claude needs your input
[Console]::Beep(800, 300)
exit 0
```

**macOS -- save as `~/.claude/hooks/notify-sound.sh`:**
```bash
#!/bin/bash
# Sound on Completion hook
afplay /System/Library/Sounds/Glass.aiff &
exit 0
```

**Linux -- save as `~/.claude/hooks/notify-sound.sh`:**
```bash
#!/bin/bash
# Sound on Completion hook
paplay /usr/share/sounds/freedesktop/stereo/complete.oga 2>/dev/null || printf '\a'
exit 0
```

On macOS/Linux, make the script executable:
```bash
chmod +x ~/.claude/hooks/notify-sound.sh
```

### Add It to Settings

Open your `settings.json` and add the hooks configuration. If the file is empty or does not exist, use the full example below. If it already has content, merge the `hooks` key into it.

**Windows:**
```json
{
  "hooks": {
    "Notification": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "powershell -ExecutionPolicy Bypass -File \"$HOOK_DIR/notify-sound.ps1\"",
            "timeout": 5000
          }
        ]
      }
    ]
  }
}
```

> **Note:** Replace `$HOOK_DIR` with the actual path to your hooks directory, using forward slashes or escaped backslashes. Example: `C:/Users/you/.claude/hooks/notify-sound.ps1`

**macOS/Linux:**
```json
{
  "hooks": {
    "Notification": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/notify-sound.sh",
            "timeout": 5000
          }
        ]
      }
    ]
  }
}
```

## Step 4: Verify It Works

1. Open a new Claude Code session (or restart your current one -- hooks are loaded at startup)
2. Ask Claude something simple: "What is 2 + 2?"
3. When Claude responds and waits for input, you should hear a beep/sound

If you hear the sound, hooks are working. If not, see the [troubleshooting guide](docs/troubleshooting.md).

## Step 5: Add More Hooks

Browse the [full catalog](README.md#the-catalog) and pick what matters to you. Each hook folder contains:

- The PowerShell and/or Bash script
- A README explaining what it does, how it works, and how to configure it
- The JSON snippet to add to your `settings.json`

### Recommended First Set

If you are not sure where to start, these four give you solid baseline protection:

1. **[Block Destructive Commands](hooks/safety/01-block-destructive-commands/)** -- prevents `rm -rf`, `git reset --hard`, etc.
2. **[Branch Protection](hooks/git/07-branch-protection/)** -- prevents push to main and force push
3. **[Critical File Guard](hooks/safety/02-critical-file-guard/)** -- protects `.env`, CI configs
4. **[Sound on Completion](hooks/notifications/13-sound-on-completion/)** -- the one you just installed

## How to Combine Multiple Hooks

Each hook event type (`PreToolUse`, `PostToolUse`, `Notification`, etc.) is a key in the `hooks` object. Multiple hooks for the same event go in the same array. Different events get different keys.

Here is an example with hooks across three event types:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "powershell -ExecutionPolicy Bypass -File \"C:/Users/you/.claude/hooks/block-destructive.ps1\"",
            "timeout": 5000
          }
        ]
      },
      {
        "matcher": "Write",
        "hooks": [
          {
            "type": "command",
            "command": "powershell -ExecutionPolicy Bypass -File \"C:/Users/you/.claude/hooks/critical-file-guard.ps1\"",
            "timeout": 5000
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
            "command": "powershell -ExecutionPolicy Bypass -File \"C:/Users/you/.claude/hooks/copy-path.ps1\"",
            "timeout": 5000
          }
        ]
      }
    ],
    "Notification": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "powershell -ExecutionPolicy Bypass -File \"C:/Users/you/.claude/hooks/notify-sound.ps1\"",
            "timeout": 5000
          }
        ]
      }
    ]
  }
}
```

Key rules:
- Each event type appears **once** as a key -- do not duplicate keys
- Multiple hooks for the same event go as separate objects in the array
- The `matcher` field filters which tool triggers the hook (empty string = all tools)
- `timeout` is in milliseconds -- keep hooks fast (under 5 seconds)

For a complete example with all 18 hooks configured: **[examples/full-settings-example.json](examples/full-settings-example.json)**

## Project vs. Global Settings

Claude Code supports two levels of settings:

| File | Scope | Use for |
|------|-------|---------|
| `~/.claude/settings.json` | Global (all projects) | Safety hooks, notifications, personal preferences |
| `<project>/.claude/settings.json` | Project-specific | Project-specific guards, formatting rules |

Project settings merge with global settings. If a hook appears in both, both run.

Most hooks in this catalog belong in global settings. Project-specific hooks are noted in their individual READMEs.

## Troubleshooting

| Problem | Fix |
|---------|-----|
| Hook does not fire | Restart Claude Code. Hooks load at startup. |
| "execution policy" error (Windows) | The `-ExecutionPolicy Bypass` flag in the command should handle this. If not, run `Set-ExecutionPolicy RemoteSigned -Scope CurrentUser` once. |
| Permission denied (macOS/Linux) | Run `chmod +x` on the script file. |
| Hook fires but does nothing | Check the script path in settings.json. Use absolute paths. Test the script manually in a terminal. |
| Claude ignores the block | Make sure the script exits with code 2 (not 1). Only exit code 2 blocks the tool call. |
| JSON parse error in settings | Validate your JSON. Trailing commas and missing quotes are common culprits. |

Full troubleshooting guide: **[docs/troubleshooting.md](docs/troubleshooting.md)**

---

Next: [Browse the full hook catalog](README.md#the-catalog)
