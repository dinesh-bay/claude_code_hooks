# Uncommitted Work Guard

> Blocks destructive git operations when you have uncommitted changes, preventing accidental loss of work in progress.

**Category:** Safety
**Event:** PreToolUse
**Matcher:** Bash
**Difficulty:** Intermediate
**Platform:** PowerShell (Windows) | Bash alternative included

## The Problem

Claude sometimes runs `git reset --hard` or `git checkout main` to "clean up" the working tree or switch contexts. If you have uncommitted changes -- code you have been working on, staged files ready to commit, or experimental changes you have not saved yet -- those changes are gone. Git does not have an undo for uncommitted work that gets discarded by a hard reset.

This hook checks for uncommitted changes before allowing any destructive git command. If your working tree is dirty, the command is blocked and you see exactly which files would be lost.

## What It Blocks

The hook only fires for git commands that can discard uncommitted work:

| Pattern | What It Catches |
|---------|-----------------|
| `git reset --hard` | Discards all uncommitted changes (staged and unstaged) |
| `git checkout <branch>` | Switches branches, may discard conflicting changes |
| `git stash drop` | Permanently deletes a stash entry |
| `git stash clear` | Permanently deletes all stash entries |
| `git restore .` | Discards all unstaged changes in the working directory |

Safe git commands like `git status`, `git log`, `git add`, `git commit`, `git push`, and `git pull` are never blocked.

## How It Works

1. Claude calls the Bash tool with a git command
2. The PreToolUse hook fires before execution
3. The script reads the stdin JSON and extracts `tool_input.command` and `cwd`
4. It checks the command against destructive git patterns
5. **Not a destructive git command:** exits with code 0 immediately (fast path)
6. **Destructive git command detected:** runs `git status --porcelain` in the project directory
7. **Working tree is clean:** exits with code 0, the command proceeds
8. **Uncommitted changes exist:** exits with code 2 (block), lists the dirty files

The hook only runs `git status` when a destructive command is detected, so it adds zero overhead to normal git operations.

## Installation

### Step 1: Copy the script

Copy `hook.ps1` to your hooks directory:

```
~/.claude/hooks/uncommitted-work-guard.ps1
```

### Step 2: Add to settings.json

Open `~/.claude/settings.json` and add the hook configuration.

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "powershell -NoProfile -ExecutionPolicy Bypass -File C:/Users/YOUR_USERNAME/.claude/hooks/uncommitted-work-guard.ps1",
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
  "command": "bash ~/.claude/hooks/uncommitted-work-guard.sh",
  "timeout": 5
}
```

### Step 3: Restart Claude Code

Close and reopen Claude Code (or start a new session) for the hook to take effect.

## Verify It Works

1. In a git repository, make a change to any file (do not commit it)
2. Ask Claude:

> "Run git reset --hard HEAD"

You should see a block message like:

```
BLOCKED: git reset --hard HEAD
You have 2 uncommitted file(s):
   M src/index.js
  ?? new-file.txt
Commit or stash your changes first.
```

3. Commit or stash your changes, then try again -- the command will be allowed.

## Configuration

The destructive git patterns are defined in the `$dangerousGitPatterns` array. To add protection for additional git commands:

```powershell
'git\s+branch\s+-D'
```

To allow a specific command through (e.g., you want `git checkout` to work even with dirty tree), remove the corresponding pattern.

## Combining With Hook 1

This hook overlaps with the Block Destructive Commands hook (hook #1) -- both block `git reset --hard`. The difference:

- **Hook #1** blocks `git reset --hard` unconditionally, always
- **Hook #6** blocks it only when you have uncommitted changes

If you run both hooks, hook #1 fires first and blocks regardless. If you want conditional behavior (allow hard reset when tree is clean), use only this hook for git commands and remove the git patterns from hook #1.

## Limitations

- **Only Bash tool calls are checked.** If git commands are run through some other mechanism, this hook will not fire.
- **Stash entries are not checked.** The hook checks the working tree via `git status`, but it does not warn about stash entries being dropped. `git stash drop` is blocked when the working tree is dirty, but if your tree is clean and you drop a stash, that is allowed.
- **git checkout with branch name is broadly matched.** The pattern `git checkout [a-zA-Z]` matches any branch checkout, including safe ones like `git checkout -b new-branch`. This is intentional -- switching branches with uncommitted changes is the risk being guarded against.
- **Not a git repo:** If the cwd is not a git repository, `git status` fails silently and the command is allowed through. The hook does not block non-git directories.
- **Submodules are not checked.** If the destructive command targets a submodule, the parent repo's status may be clean while the submodule has changes.
