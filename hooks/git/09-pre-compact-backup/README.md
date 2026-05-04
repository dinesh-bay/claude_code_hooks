# Pre-Compact Backup

> Automatically saves a copy of your conversation transcript before Claude's auto-compaction discards it.

**Category:** Git
**Event:** PreCompact
**Matcher:** None (fires for all compaction events)
**Difficulty:** Starter
**Platform:** PowerShell (Windows) | Bash alternative included

## The Problem

Claude Code automatically compacts conversations when they get too long. Compaction summarizes the conversation into a shorter form so Claude can keep working within its context window. The problem is that the full conversation detail -- every tool call, every response, every reasoning step -- is lost in the process.

If you need to review what Claude did during a long session, debug an issue that happened earlier, or keep an audit trail, the compacted summary is not enough. The original transcript is gone.

This hook copies the full transcript to a backup directory before compaction happens, so you always have the complete record.

## What It Does

When Claude's auto-compaction triggers:

1. The PreCompact hook fires before compaction begins
2. The script reads the `transcript_path` from the stdin JSON
3. It copies the transcript file to `~/.claude/backups/` with a timestamp
4. Compaction proceeds normally -- the backup is a copy, not a move

Backup files are named `transcript-YYYY-MM-DD_HH-mm-ss.jsonl` so they sort chronologically and never collide.

## How It Works

1. Claude Code detects the conversation is too long and triggers compaction
2. The PreCompact hook fires with a JSON payload containing `transcript_path`
3. The script checks that `transcript_path` exists and points to a real file
4. It creates `~/.claude/backups/` if the directory does not exist
5. It copies the transcript with a timestamped filename
6. It exits with code 0 so compaction proceeds as normal

This hook always exits 0. It never blocks compaction -- the backup is purely additive.

## Installation

### Step 1: Copy the script

Copy `hook.ps1` to your hooks directory:

```
~/.claude/hooks/pre-compact-backup.ps1
```

### Step 2: Add to settings.json

Open `~/.claude/settings.json` and add the hook configuration. If you already have a `hooks` section, merge the `PreCompact` entry into it.

```json
{
  "hooks": {
    "PreCompact": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "powershell -NoProfile -ExecutionPolicy Bypass -File C:/Users/YOUR_USERNAME/.claude/hooks/pre-compact-backup.ps1",
            "timeout": 10
          }
        ]
      }
    ]
  }
}
```

Replace `YOUR_USERNAME` with your actual Windows username.

Note: PreCompact hooks have no `matcher` field -- they fire for all compaction events.

**Linux/macOS:** Use `hook.sh` instead:

```json
{
  "type": "command",
  "command": "bash ~/.claude/hooks/pre-compact-backup.sh",
  "timeout": 10
}
```

### Step 3: Restart Claude Code

Close and reopen Claude Code (or start a new session) for the hook to take effect.

## Verify It Works

The easiest way to verify is to check that the script runs without errors:

```powershell
# Create a test transcript file
echo '{"test": true}' > $env:TEMP\test-transcript.jsonl

# Simulate the hook input
echo '{"transcript_path": "TEMP_PATH"}' | powershell -NoProfile -ExecutionPolicy Bypass -File ~/.claude/hooks/pre-compact-backup.ps1
```

Replace `TEMP_PATH` with the actual path to your test file. Check `~/.claude/backups/` for the copied file.

In practice, this hook fires automatically when Claude compacts a long conversation. You will see the stderr message in Claude's output:

```
Transcript backed up to: C:\Users\you\.claude\backups\transcript-2026-05-04_14-30-22.jsonl
```

## Backup Location

All backups go to:

```
~/.claude/backups/transcript-YYYY-MM-DD_HH-mm-ss.jsonl
```

The directory is created automatically on first use. Transcript files are JSONL format (one JSON object per line) and can be large for long sessions.

## Cleanup

Backups accumulate over time. Periodically review and delete old ones:

```powershell
# List backups sorted by date
Get-ChildItem ~/.claude/backups/ | Sort-Object LastWriteTime

# Delete backups older than 30 days
Get-ChildItem ~/.claude/backups/ | Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-30) } | Remove-Item
```

## Limitations

- **Only fires on auto-compaction.** User-initiated `/compact` and `/clear` commands do not trigger PreCompact hooks. For those, use the manual backup script in the bonus section of this repository.
- **No deduplication.** If compaction triggers multiple times in quick succession, you get multiple backup files. They are timestamped to the second, so collisions are unlikely but not impossible.
- **Disk usage.** Transcript files for long sessions can be several megabytes. The hook does not enforce any size limit or rotation policy.
- **Transcript format may change.** The JSONL format is an internal Claude Code implementation detail. Future versions may change the structure or location of transcript files.
