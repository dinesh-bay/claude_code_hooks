# Session Context Loader

> Injects your current git branch, recent commits, and TODO/FIXME/HACK count into Claude's starting context. Claude knows your project state without being asked.

**Category:** Productivity
**Event:** SessionStart
**Matcher:** None (fires for every session)
**Difficulty:** Intermediate
**Platform:** PowerShell (Windows) | Bash alternative included

## The Problem

Every new Claude Code session starts with a blank slate. Claude does not know what branch you are on, what you committed recently, or how many TODOs are scattered across your codebase. You end up typing "what branch am I on" or "show me recent commits" at the start of every session, wasting the first 30 seconds on orientation.

This hook runs at session start and prints project context to stdout. Because SessionStart stdout is injected into Claude's starting context, Claude immediately knows your branch, recent work, and outstanding markers -- without you asking.

## What It Injects

The hook gathers three pieces of information:

| Data | Source | Example Output |
|------|--------|----------------|
| Current branch | `git branch --show-current` | `Current branch: feature/auth-refactor` |
| Last 5 commits | `git log --oneline -5` | Commit hashes and messages |
| TODO count | grep across `.py`, `.ts`, `.js` files | `TODO/FIXME/HACK count: 14` |

If the current directory is not a git repo, the git fields are silently skipped. If there are no TODOs, that line is omitted.

## How It Works

1. A new Claude Code session starts
2. The SessionStart hook fires before Claude's first prompt
3. The script runs git commands and grep to gather project state
4. It prints the results to stdout
5. Claude receives this output as part of its initial context

Claude can then reference this information in its responses. For example, if you say "continue where I left off", Claude can look at the recent commits to understand what was done.

## Installation

### Step 1: Copy the script

Copy `hook.ps1` to your hooks directory:

```
~/.claude/hooks/session-context-loader.ps1
```

### Step 2: Add to settings.json

Open `~/.claude/settings.json` and add the hook configuration. If you already have a `hooks` section, merge the `SessionStart` entry into it.

```json
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "powershell -NoProfile -ExecutionPolicy Bypass -File C:/Users/YOUR_USERNAME/.claude/hooks/session-context-loader.ps1",
            "timeout": 10
          }
        ]
      }
    ]
  }
}
```

Replace `YOUR_USERNAME` with your actual Windows username.

SessionStart hooks do not have a `matcher` field -- they fire unconditionally at the start of every session.

**Linux/macOS:** Use `hook.sh` instead:

```json
{
  "type": "command",
  "command": "bash ~/.claude/hooks/session-context-loader.sh",
  "timeout": 10
}
```

### Step 3: Restart Claude Code

Close and reopen Claude Code (or start a new session). The hook fires immediately on the next session start.

## Verify It Works

Start a new Claude Code session in a git repository. Claude's first response (or internal context) should reflect your branch and recent commits. Ask Claude:

> "What branch am I on?"

Claude should answer correctly without running any commands, because the hook already provided that information.

## Configuration

**Changing the commit count:** Edit the `-5` in the git log command to show more or fewer commits:

```powershell
$recentCommits = & git -C $cwd log --oneline -10 2>$null
```

**Adding more context:** You can extend the script to include anything useful at session start. Examples:

- Uncommitted file count: `git status --porcelain | Measure-Object`
- Node/Python version: `node --version`, `python --version`
- Running services: `docker ps --format "table {{.Names}}\t{{.Status}}"`
- Last test run result: parse a test output file

Anything printed to stdout becomes part of Claude's starting context.

**File type filter:** The TODO search only covers `.py`, `.ts`, and `.js` files. Add more extensions to the `Get-ChildItem -Include` parameter (PowerShell) or `--include` flags (bash) to scan additional file types.

## Limitations

- **Runs in the hook's working directory.** The script uses `Get-Location` (PowerShell) or `.` (bash) as the working directory. This is typically the project root where you launched Claude Code. If you launched Claude from a different directory than your project, the git commands may target the wrong repo.
- **Large repos may be slow.** The TODO grep scans every `.py`, `.ts`, and `.js` file recursively. In a monorepo with thousands of files, this can take a few seconds. The 10-second timeout should be sufficient for most projects, but if it times out, the hook output is discarded and Claude starts without the context.
- **stdout is one-way.** Claude receives the output but cannot respond to it in the hook. The information is injected silently -- there is no interactive prompt.
- **Not a substitute for CLAUDE.md.** This hook provides runtime state (branch, commits). Static project documentation belongs in CLAUDE.md, which Claude reads separately.
