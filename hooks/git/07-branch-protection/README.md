# Branch Protection

> Blocks force push to any branch and blocks direct push to main/master.

**Category:** Git
**Event:** PreToolUse
**Matcher:** Bash
**Difficulty:** Starter
**Platform:** PowerShell (Windows) | Bash alternative included

## The Problem

Claude can run any git command through the Bash tool, including `git push --force` and `git push origin main`. Force pushing rewrites remote history and can destroy work that teammates have already pulled. Direct pushes to main/master bypass code review entirely.

Both are easy to approve when you are clicking through tool calls quickly. This hook catches them before they execute.

## What It Blocks

| Pattern | What It Catches |
|---------|-----------------|
| `git push --force` | Force push to any branch -- rewrites remote history |
| `git push --force-with-lease` | Also caught -- still a force push variant |
| `git push origin main` | Direct push to main -- bypasses pull request review |
| `git push origin master` | Direct push to master -- same risk |

## How It Works

1. Claude calls the Bash tool with a git push command
2. The PreToolUse hook fires before execution
3. The script reads the stdin JSON and extracts `tool_input.command`
4. It checks for `--force` anywhere in a `git push` command
5. It checks for `main` or `master` as the branch target after a remote name
6. **Match found:** exits with code 2 (block) and writes a clear reason to stderr
7. **No match:** exits with code 0, Claude runs the command normally

## Installation

### Step 1: Copy the script

Copy `hook.ps1` to your hooks directory:

```
~/.claude/hooks/branch-protection.ps1
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
            "command": "powershell -NoProfile -ExecutionPolicy Bypass -File C:/Users/YOUR_USERNAME/.claude/hooks/branch-protection.ps1",
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
  "command": "bash ~/.claude/hooks/branch-protection.sh",
  "timeout": 5
}
```

### Step 3: Restart Claude Code

Close and reopen Claude Code (or start a new session) for the hook to take effect.

## Verify It Works

Ask Claude:

> "Run `git push origin main` for me"

You should see a block message:

```
BLOCKED: Direct push to main/master is not allowed.
Command: git push origin main
Create a feature branch and open a PR instead.
```

Also try:

> "Run `git push --force origin feature-branch`"

```
BLOCKED: Force push is not allowed.
Command: git push --force origin feature-branch
Force pushing can overwrite remote history and destroy teammates' work.
```

Claude will not execute either command.

## Limitations

- **Short-form flags are not caught.** Git does not have a single-letter alias for `--force`, but custom git aliases could bypass detection.
- **Indirect pushes are not caught.** A script or Makefile that internally runs `git push --force` would not be intercepted -- the hook only sees the outer command.
- **Branch name patterns are exact.** Only `main` and `master` are protected. If your default branch is named something else (e.g., `trunk`, `develop`), edit the regex in the script.
- **Remote name is required.** The pattern matches `git push <remote> main`. A bare `git push` that defaults to main through git config would not be caught.
