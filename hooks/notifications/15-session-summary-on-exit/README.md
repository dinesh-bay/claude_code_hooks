# Session Summary on Exit

> Logs each Claude Code session to a Markdown file when the session ends. Useful when you work across multiple projects and want a record of where and when you used Claude.

**Category:** Notifications
**Event:** Stop
**Matcher:** None
**Difficulty:** Intermediate
**Platform:** PowerShell (Windows) | Bash alternative included

## The Problem

You use Claude Code across multiple projects throughout the day. A week later you are trying to remember: did I use Claude on the API project on Tuesday? Which session was the one where I refactored the auth module?

There is no built-in session history that shows when and where you ran Claude. This hook creates one automatically.

## What It Logs

Each session appends one row to `~/.claude/session-logs/sessions.md`:

```markdown
# Session Log

| Timestamp | Session | Directory |
|-----------|---------|-----------|
| 2026-05-04 14:32:10 | a1b2c3d4 | my-api-project |
| 2026-05-04 15:01:45 | e5f6g7h8 | claude-code-hooks |
| 2026-05-04 16:22:03 | i9j0k1l2 | portfolio-site |
```

- **Timestamp** -- when the session ended
- **Session** -- first 8 characters of the session ID (enough to identify, short enough to scan)
- **Directory** -- the project folder name (last segment of the working directory path)

## How It Works

1. Claude's session ends and fires the Stop event
2. The hook reads the stdin JSON and extracts `session_id` and `cwd`
3. It creates `~/.claude/session-logs/` if it does not exist
4. It creates `sessions.md` with a Markdown table header if the file does not exist
5. It appends one row with the timestamp, truncated session ID, and directory name

The log file grows by one line per session. At one session per day, that is 365 lines per year -- the file stays small indefinitely.

## Installation

### Step 1: Copy the script

Copy `hook.ps1` to your hooks directory:

```
~/.claude/hooks/session-summary-on-exit.ps1
```

### Step 2: Add to settings.json

Open `~/.claude/settings.json` and add the hook configuration. If you already have a `hooks` section, merge the `Stop` entry into it.

```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "powershell -NoProfile -ExecutionPolicy Bypass -File C:/Users/YOUR_USERNAME/.claude/hooks/session-summary-on-exit.ps1",
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
  "command": "bash ~/.claude/hooks/session-summary-on-exit.sh",
  "timeout": 5
}
```

### Step 3: Restart Claude Code

Close and reopen Claude Code (or start a new session) for the hook to take effect.

## Verify It Works

Start a Claude session, ask a simple question, then exit with `/exit` or Ctrl+C. Check the log:

**Windows:**
```powershell
Get-Content "$HOME\.claude\session-logs\sessions.md"
```

**macOS/Linux:**
```bash
cat ~/.claude/session-logs/sessions.md
```

You should see the table header and one row with the session you just ended.

## Configuration

**Change the log location:** Modify the `$logDir` / `LOG_DIR` variable at the top of the script. The directory is created automatically if it does not exist.

**Add more fields:** The stdin JSON also contains `hook_event_name`. You could extend the table with additional columns by modifying both the header and the entry format:

```powershell
$entry = "| $timestamp | $shortId | $dirName | $($json.hook_event_name) |"
```

**Truncate session ID length:** Change `$sessionId.Substring(0, 8)` to a different length. The full session ID is a UUID, so 8 characters provides reasonable uniqueness.

## Limitations

- **Stop event only.** The hook fires when the session ends normally. If Claude Code crashes or the process is killed with `kill -9`, the Stop event may not fire and the session will not be logged.
- **Directory name only, not full path.** Two projects with the same folder name (e.g., both named `src`) will look identical in the log. If this is a problem, modify the script to log the full path instead of just the leaf directory.
- **No session duration.** The hook only knows when the session ended, not when it started. To get duration, you would need a companion SessionStart hook that logs the start time.
- **Append-only.** The log file only grows. There is no automatic rotation or cleanup. For most usage patterns this is fine -- a year of daily sessions produces a file under 20KB.
