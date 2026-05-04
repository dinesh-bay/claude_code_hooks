# Copy File Path to Clipboard

> After Claude writes a file, the full path is copied to your clipboard. Ready to paste into a terminal, browser, or file explorer.

**Category:** Productivity
**Event:** PostToolUse
**Matcher:** Write
**Difficulty:** Starter
**Platform:** PowerShell (Windows) | Bash alternative included

## The Problem

Claude tells you it created a file, but the path is buried in its output. If you are working across multiple sessions, or the file is deep in a nested directory, you end up scrolling back, selecting the path, and copying it manually. Relative paths make this worse -- `./src/components/Header.tsx` means nothing if you have five projects open.

This hook was born from a real need. Working across 5 concurrent sessions on different projects, relative paths were useless. Every time Claude wrote a file, the next step was "find that path, copy it, switch to the other window, paste." This hook removes that friction entirely.

## How It Works

1. Claude calls the Write tool to create or overwrite a file
2. The PostToolUse hook fires after the file is written
3. The script reads the stdin JSON and extracts `tool_input.file_path`
4. If a path exists, it copies it to the system clipboard
5. Exits with code 0 -- Claude continues normally

The hook runs with `async: true`, so it does not block Claude while the clipboard operation completes.

## Installation

### Step 1: Copy the script

Copy `hook.ps1` to your hooks directory:

```
~/.claude/hooks/copy-file-path-clipboard.ps1
```

### Step 2: Add to settings.json

Open `~/.claude/settings.json` and add the hook configuration. If you already have a `hooks` section, merge the `PostToolUse` entry into it.

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write",
        "hooks": [
          {
            "type": "command",
            "command": "powershell -NoProfile -ExecutionPolicy Bypass -File C:/Users/YOUR_USERNAME/.claude/hooks/copy-file-path-clipboard.ps1",
            "timeout": 5,
            "async": true
          }
        ]
      }
    ]
  }
}
```

Replace `YOUR_USERNAME` with your actual Windows username.

**Important:** Use the full path `C:/Users/YOUR_USERNAME/...` in the command, not `~/`. PowerShell does not expand tilde (`~`) the same way bash does, and the hook will silently fail to find the script.

**Linux/macOS:** Use `hook.sh` instead:

```json
{
  "type": "command",
  "command": "bash ~/.claude/hooks/copy-file-path-clipboard.sh",
  "timeout": 5,
  "async": true
}
```

### Step 3: Restart Claude Code

Close and reopen Claude Code (or start a new session) for the hook to take effect.

## Verify It Works

Ask Claude:

> "Create a file called test-clipboard.txt with the content 'hello'"

After the file is created, press Ctrl+V (or Cmd+V) in any text field. You should see the full path to `test-clipboard.txt`.

## Why async: true Is Required

PostToolUse hooks run between tool calls. Without `async: true`, Claude waits for the hook to finish before continuing. A clipboard operation is fast, but there is no reason to block Claude for it. The file is already written -- the clipboard copy is a side effect for your convenience, not something Claude needs to know about.

If you omit `async: true`, the hook still works, but you may notice a slight pause after every file write.

## PostToolUse stdout Goes to Claude

This is a PostToolUse hook. Anything written to stdout becomes part of Claude's context -- it is injected into the conversation as if Claude had read it. This hook writes nothing to stdout intentionally. If you modify it to print something (like "Copied!"), Claude will see that message and may react to it.

stderr is not injected into Claude's context for PostToolUse hooks. Use stderr for debug logging if needed.

## The Clipboard-Overwrite Tradeoff

Every file Claude writes overwrites whatever is currently in your clipboard. If you copied a URL, a code snippet, or a password, it is gone. This is the fundamental tradeoff of this hook.

In practice, this is rarely a problem. If Claude is writing files, you are probably in a coding flow where having the latest file path is more useful than whatever was in your clipboard. But if you are doing something where your clipboard contents matter, either disable the hook temporarily or be aware of the overwrite.

## Limitations

- **Only fires for Write, not Edit.** The Edit tool modifies existing files but also has `file_path` in its input. If you want clipboard copy on edits too, change the matcher to `Write|Edit`.
- **Clipboard overwrites are silent.** No notification that your clipboard was replaced. The hook is intentionally quiet.
- **Windows-only clipboard on PowerShell.** The bash version tries `pbcopy` (macOS) then `xclip` (Linux). If neither is installed, the copy silently fails.
- **Async means no guarantee of ordering.** If Claude writes two files in rapid succession, the clipboard will contain whichever one finished last. Usually the second one, but not guaranteed.
