# Context Saver

> Saves a structured conversation summary when context usage exceeds 70%. One notification per session, no spam.

**Category:** Context
**Event:** PostToolUse
**Matcher:** None (fires for all tools to track overall context growth)
**Difficulty:** Intermediate
**Platform:** PowerShell (Windows) | Bash alternative included

## The Problem

You work across 5+ sessions a day. When context gets full, auto-compaction or `/clear` wipes your conversation. Key decisions, file paths, and context are lost. You find yourself re-explaining the same things in new sessions.

There is no built-in way to save a scannable summary of what happened before it disappears.

## How It Works

1. **PostToolUse fires** -- every tool call triggers the hook (no matcher)
2. **Check transcript size** -- if the transcript file is below 70% of the estimated 3MB limit, exit immediately (fast path, costs nothing)
3. **Check flag file** -- if this session already saved a summary, exit immediately (one notification per session)
4. **Parse JSONL transcript** -- extract tool names, file extensions, and directory names as topic keywords; extract file paths as files touched
5. **Save styled Markdown summary** -- write to `~/.claude/saved-conversations/` with tables, topic badges, files list, and a collapsible full transcript
6. **Show notification** -- Windows balloon tip (or macOS/Linux notification) with context percentage and file name

The hook exits at step 2 for 99% of tool calls (file size below threshold). It only does real work once per session.

## The Summary File

Each summary is saved as a Markdown file in `~/.claude/saved-conversations/`:

```
~/.claude/saved-conversations/
    2026-05-04_14-32_my-api-project.md
    2026-05-04_16-01_claude-code-hooks.md
    2026-05-05_09-15_portfolio-site.md
```

The file looks like this:

```markdown
# Session Summary

| Field | Value |
|-------|-------|
| Date | 2026-05-04 14:32:10 |
| CWD | `C:\Users\you\projects\my-api` |
| Session | `a1b2c3d4` |
| Context | ~72% used |

## Topics

`Write` `Edit` `Bash` `.py` `.ts` `src` `tests` `hooks`

## Files Touched

| Action | File |
|--------|------|
| Created | `src/auth.py` |
| Modified | `tests/test_auth.py` |
| Modified | `README.md` |

---

<details>
<summary>Full Transcript (click to expand)</summary>
(full JSONL transcript here -- hidden by default)
</details>
```

Open the file in VS Code and press `Ctrl+Shift+V` for the best experience -- tables render cleanly, topic badges are readable, and the transcript is collapsed until you need it.

## Installation

### Step 1: Copy the script

Copy `hook.ps1` to your hooks directory:

```
~/.claude/hooks/context-saver.ps1
```

### Step 2: Add to settings.json

Open `~/.claude/settings.json` and add the hook configuration. If you already have a `hooks` section, merge the `PostToolUse` entry into it.

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "name": "Hook #20 — Context Saver",
        "hooks": [
          {
            "type": "command",
            "command": "powershell -NoProfile -ExecutionPolicy Bypass -File C:/Users/YOUR_USERNAME/.claude/hooks/context-saver.ps1",
            "timeout": 10
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
  "command": "bash ~/.claude/hooks/context-saver.sh",
  "timeout": 10
}
```

### Step 3: Restart Claude Code

Close and reopen Claude Code (or start a new session) for the hook to take effect.

## Verify It Works

Lower the threshold to trigger it quickly for testing. In `hook.ps1`, change:

```powershell
$ESTIMATED_FULL_SIZE_MB = 3
```

to:

```powershell
$ESTIMATED_FULL_SIZE_MB = 0.1
```

Then start a Claude session, make a few tool calls (ask Claude to read or write a file), and check:

**Windows:**
```powershell
Get-ChildItem "$HOME\.claude\saved-conversations\"
```

**macOS/Linux:**
```bash
ls ~/.claude/saved-conversations/
```

You should see a `.md` file with today's date and your project name. Remember to set the value back to `3` after testing.

## Configuration

| Variable | Default | What It Controls |
|----------|---------|-----------------|
| `$THRESHOLD_PERCENT` | `70` | Context percentage that triggers the save. Lower = saves earlier. |
| `$ESTIMATED_FULL_SIZE_MB` | `3` | Estimated full context window size in MB. Adjust if Anthropic changes the limit. |

Both variables are at the top of the script.

The hook estimates context percentage from transcript file size. This is an approximation -- the actual context window is managed internally by Claude Code and includes system prompts, tool definitions, and other overhead that is not in the transcript file. The estimate is good enough to know when you are running low.

## What Makes This Hook Special

- **No other hook saves your conversations with a scannable summary.** Session logs (hook #15) record that a session happened. This hook records what happened in the session.
- **The `<details>` tag hides the full transcript** until you need it. The summary stays clean and scannable. Click to expand when you need the raw data.
- **Topics are extracted from tool calls and file paths** -- tool names, file extensions, directory names. No AI required. You get instant keywords like `Write` `.py` `src` `tests` that tell you what the session was about.
- **One notification per session.** The flag file mechanism means you get exactly one balloon tip when context crosses the threshold. No repeated alerts on every subsequent tool call.
- **Zero cost for 99% of tool calls.** The file size check is the first real operation. If the transcript is small, the hook exits in under 10ms.

## Limitations

- **Context percentage is estimated from file size, not exact.** The transcript file does not include system prompts, tool definitions, or internal overhead. The real context usage may be higher than what the hook reports.
- **JSONL parsing adds 1-2 seconds on large transcripts.** This only happens once per session (flag file prevents re-parsing). The 10-second timeout is generous.
- **Summary quality depends on file operations.** Sessions that are mostly conversational (no file reads/writes) will have fewer topics and no files touched. The summary still captures the context percentage and timestamp.
- **Transcript is embedded in the summary file.** For very long sessions, the summary file can be large (several MB). The `<details>` tag keeps it visually clean, but the file size is real.
- **Flag file lives in TEMP.** On Windows, `%TEMP%` is cleaned on reboot. On Linux, `/tmp` may be cleaned by the OS. This is fine -- the flag only needs to survive one session.

## Saved Files Location

```
~/.claude/saved-conversations/
```

This directory is created automatically on first save. Files are never deleted by the hook -- manage cleanup manually or add a cron job to remove files older than N days.
