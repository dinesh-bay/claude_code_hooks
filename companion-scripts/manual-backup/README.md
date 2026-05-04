# Manual Backup

> A companion script to save your Claude Code conversation transcript before `/clear` or `/compact`. These commands have no hook event -- this is the workaround.

**Type:** Companion script (not a hook)
**Platform:** PowerShell (Windows) | Bash alternative included

## The Problem

Claude Code's `/clear` command wipes your conversation history. `/compact` summarizes and discards the full transcript. Neither of these actions fires a hook event -- there is no `PreClear` or `PreCompact` (user-initiated) event in the hook system.

If you have a long session with important context, decisions, or code discussions, that information is gone after `/clear`. There is no built-in way to save it first.

This script is a manual workaround. Run it before `/clear` to copy your most recent transcript to a backup directory.

## How It Works

1. You run the script manually in your terminal
2. It looks for `.jsonl` transcript files in `~/.claude/projects/` (recursively)
3. It finds the most recently modified transcript
4. It copies that file to `~/.claude/backups/` with a timestamped filename
5. You can now safely run `/clear`

The backup is a raw `.jsonl` file -- the same format Claude Code uses internally. Each line is a JSON object representing one conversation turn.

## Usage

### Windows (PowerShell)

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File backup.ps1
```

### Linux/macOS (Bash)

```bash
bash backup.sh
```

### Output

```
Backed up to: C:\Users\you\.claude\backups\manual-backup-2026-05-04_14-30-22.jsonl
```

Or if no transcripts exist:

```
No transcript files found.
```

## Where Backups Go

All backups are saved to:

```
~/.claude/backups/
```

The directory is created automatically if it does not exist. Each backup is named with a timestamp:

```
manual-backup-2026-05-04_14-30-22.jsonl
manual-backup-2026-05-04_16-45-10.jsonl
```

## Custom Transcript Directory

If your transcripts are stored somewhere other than `~/.claude/projects/`, pass the path as an argument:

PowerShell:
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File backup.ps1 -TranscriptDir "C:\path\to\transcripts"
```

The bash version does not accept arguments -- edit the `TRANSCRIPT` find path directly in the script.

## When to Use This

- Before running `/clear` to start a fresh session
- Before a long break, if you want to preserve your conversation
- After a productive session where Claude made decisions you want to reference later
- As a periodic habit -- run it once a day if you have long-running sessions

## Limitations

- **Manual only.** There is no way to trigger this automatically before `/clear` -- the hook system does not support it. You have to remember to run it.
- **Backs up one file.** The script copies only the most recently modified `.jsonl` file. If you have multiple active sessions, only the latest is backed up. Run it once per session if you need backups of multiple sessions.
- **Raw format.** The `.jsonl` file is not human-readable in a friendly way. Each line is a JSON object. You can read it with `cat` or a JSON viewer, but it is not formatted as a clean conversation transcript.
- **No cleanup.** Old backups accumulate in `~/.claude/backups/`. Delete them manually when you no longer need them.
