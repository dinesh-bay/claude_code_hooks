# Mass Change Detector

> Tracks every file Claude modifies during a session and warns when the count crosses a threshold. NOVEL -- no other hook repo has session-wide file tracking.

**Category:** Human-in-Control
**Event:** PostToolUse (main hook) + SessionStart (cleanup)
**Matcher:** Write, Edit (main hook) | none (cleanup)
**Difficulty:** Intermediate
**Platform:** PowerShell (Windows) | Bash alternative included

## The Problem

Claude is fast. It can scaffold an entire project, refactor a module, or "clean up" a test suite in seconds. By the time you notice, it has already touched 15 files. Some of those changes might be exactly what you wanted. Others might be unwanted side effects -- renaming variables you did not ask about, deleting comments it considered "unnecessary", or restructuring files that were fine as they were.

There is no built-in way to know how many files Claude has changed in the current session. You would need to manually count, or run `git diff --stat` and hope you remember to do it often enough.

This hook keeps a running tally. After every Write or Edit, it appends the file path to a session-scoped tracking file. When the unique file count hits the threshold (default: 8), it prints a warning with the full list to stderr.

## How It Works

Two scripts work together:

**hook.ps1** (PostToolUse -- fires after every Write or Edit):
1. Reads the stdin JSON and extracts `tool_input.file_path` and `session_id`
2. Appends the file path to a temp file named `.claude-hook-session-<short-id>.txt`
3. Counts unique file paths in the tracking file
4. If the count is at or above the threshold, writes a warning to stderr listing every modified file

**cleanup.ps1** (SessionStart -- fires when a new session begins):
1. Deletes all `.claude-hook-session-*.txt` files from the temp directory
2. Prevents stale counts from a previous session carrying over

Because this is a PostToolUse hook, it **observes but does not block**. The exit code is always 0. Claude sees the warning in its context and can acknowledge it, but the file modification has already happened.

## Installation

### Step 1: Copy the scripts

Copy both scripts to your hooks directory:

```
~/.claude/hooks/mass-change-detector.ps1
~/.claude/hooks/mass-change-detector-cleanup.ps1
```

### Step 2: Add to settings.json

Open `~/.claude/settings.json` and add both hook configurations. If you already have `PostToolUse` or `SessionStart` sections, merge the entries into them.

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "powershell -NoProfile -ExecutionPolicy Bypass -File C:/Users/YOUR_USERNAME/.claude/hooks/mass-change-detector.ps1",
            "timeout": 5
          }
        ]
      }
    ],
    "SessionStart": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "powershell -NoProfile -ExecutionPolicy Bypass -File C:/Users/YOUR_USERNAME/.claude/hooks/mass-change-detector-cleanup.ps1",
            "timeout": 5
          }
        ]
      }
    ]
  }
}
```

Replace `YOUR_USERNAME` with your actual Windows username.

**Linux/macOS:** Use `hook.sh` instead. There is no separate cleanup script for bash -- add a SessionStart hook that runs `rm -f ${TMPDIR:-/tmp}/.claude-hook-session-*.txt`.

### Step 3: Restart Claude Code

Close and reopen Claude Code (or start a new session) for the hooks to take effect.

## Verify It Works

Ask Claude:

> "Create 9 test files named test1.txt through test9.txt with the content 'hello' in each."

After the 8th file, you should see a warning in stderr:

```
WARNING: Claude has modified 8 files this session.
Modified files:
  test1.txt
  test2.txt
  test3.txt
  test4.txt
  test5.txt
  test6.txt
  test7.txt
  test8.txt
Review the changes before allowing more modifications.
```

The warning repeats (with an updated count) for each subsequent file modification. Claude sees this warning and may pause to check with you.

## Configuration

**Threshold:** Change the `$THRESHOLD` variable at the top of `hook.ps1`. Default is 8. Lower it for tighter control, raise it if you routinely do large refactors.

```powershell
$THRESHOLD = 8
```

**Making it blocking:** This hook ships as PostToolUse (observe-only). If you want to hard-stop Claude after the threshold, change the event from `PostToolUse` to `PreToolUse` in your settings.json and change `exit 0` to `exit 2` inside the threshold check. This turns the warning into a block -- Claude will not be able to modify any more files until you intervene.

## How the Tracking File Works

Each session gets its own tracking file in the system temp directory:

```
%TEMP%\.claude-hook-session-a1b2c3d4.txt
```

The file name uses the first 8 characters of the `session_id` to keep sessions isolated. The cleanup script deletes all tracking files at the start of each new session, so stale data never carries over.

Each Write or Edit appends one line (the file path). Duplicate paths are counted only once when checking the threshold. Editing the same file 10 times still counts as 1 unique file.

## Limitations

- **PostToolUse cannot block.** The warning fires after the modification has already happened. By the time you see it, file #8 is already written. Switch to PreToolUse + exit 2 if you need a hard stop.
- **Tracking file persistence.** If Claude Code crashes without triggering a new SessionStart, stale tracking files remain in temp. They are harmless and will be cleaned up on the next normal session start.
- **No undo.** The hook tells you what changed but does not revert anything. Use `git diff` to review and `git checkout -- <file>` to revert specific files.
- **Same file, different paths.** If Claude writes to `./src/app.ts` and `src/app.ts`, both entries appear. The hook does basic string comparison, not path normalization. In practice, Claude consistently uses the same path format within a session.
