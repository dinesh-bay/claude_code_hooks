# Claude Code Hooks -- A Curated Collection

> Ready-to-use hooks that put you in control of Claude Code. Windows-first. Beginner-friendly.

---

## What Are Hooks?

Hooks are scripts that run automatically when Claude Code does something -- before it writes a file, after it runs a command, when a session starts. You write the script, Claude Code calls it at the right moment.

Think of it like git hooks, but for everything Claude does.

```
You ask Claude to write a file
        |
        v
Claude calls the Write tool
        |
        v
PreToolUse hook fires ----> Your script checks if it's safe
        |                         |
        |                    Block (exit 2) ----> Claude sees: "Blocked: reason"
        |                         |
        v                    Allow (exit 0)
File gets written                 |
        |                         v
        v                  Claude continues
PostToolUse hook fires ----> Your script logs/notifies/copies path
```

Your hook script receives JSON on stdin describing what Claude is about to do (or just did). You inspect it, decide whether to allow or block, and optionally print a message back to Claude's context.

## Why You Need Hooks

Claude Code is powerful. It can also:

- `rm -rf` your project directory
- `git push --force` to main
- Overwrite your `.env` with test values
- Delete test files it thinks are "unnecessary"
- Modify CI configs in ways that break your pipeline

These are not hypothetical. The community has reported real data loss from all of the above.

Clicking "Allow" on every tool call is not real control. You are pattern-matching a wall of text under time pressure. Hooks give you programmable guardrails that work every time, without fatigue.

## Quick Start

New to hooks? Start here: **[INSTALL.md](INSTALL.md)** -- a step-by-step guide to install your first hook in under 5 minutes.

Already familiar? Browse the catalog below and copy what you need.

## The Catalog

19 hooks organized by what they protect.

### Safety

| # | Hook | Event | Difficulty | Description |
|---|------|-------|------------|-------------|
| 1 | [Block Destructive Commands](hooks/safety/01-block-destructive-commands/) | PreToolUse | Starter | Blocks `rm -rf`, `git reset --hard`, and other destructive commands |
| 2 | [Critical File Guard](hooks/safety/02-critical-file-guard/) | PreToolUse | Starter | Blocks modifications to `.env`, CI configs, and other protected files |
| 3 | [Large File Overwrite Guard](hooks/safety/03-large-file-overwrite-guard/) | PreToolUse | Intermediate | Blocks overwriting files with 300+ lines without confirmation |
| 4 | [Scope Boundary Guard](hooks/safety/04-scope-boundary-guard/) | PreToolUse | Intermediate | Blocks file operations outside the project directory |
| 5 | [Secret Scanner](hooks/safety/05-secret-scanner/) | PreToolUse | Intermediate | Detects API keys, passwords, and tokens before they get written |
| 6 | [Uncommitted Work Guard](hooks/safety/06-uncommitted-work-guard/) | PreToolUse | Intermediate | Blocks destructive git operations when you have uncommitted changes |

### Git

| # | Hook | Event | Difficulty | Description |
|---|------|-------|------------|-------------|
| 7 | [Branch Protection](hooks/git/07-branch-protection/) | PreToolUse | Starter | Blocks push to main/master and blocks force push to any branch |
| 8 | [Dependency Change Guard](hooks/git/08-dependency-change-guard/) | PreToolUse | Starter | Warns when Claude modifies package.json, requirements.txt, or lock files |
| 9 | [Pre-Compact Backup](hooks/git/09-pre-compact-backup/) | PreCompact | Starter | Saves conversation transcript before Claude's auto-compaction |

### Human-in-Control

| # | Hook | Event | Difficulty | Description |
|---|------|-------|------------|-------------|
| 10 | [Mass Change Detector](hooks/human-in-control/10-mass-change-detector/) | PostToolUse | Intermediate | Warns after a single operation modifies 8 or more files |
| 11 | [Dangerous Interpreter Guard](hooks/human-in-control/11-dangerous-interpreter-guard/) | PreToolUse | Intermediate | Blocks long inline `python -c` and `node -e` commands |
| 12 | [Test File Deletion Guard](hooks/human-in-control/12-test-file-deletion-guard/) | PreToolUse | Intermediate | Prevents deletion of test files and test directories |

### Notifications

| # | Hook | Event | Difficulty | Description |
|---|------|-------|------------|-------------|
| 13 | [Sound on Completion](hooks/notifications/13-sound-on-completion/) | Notification | Starter | Plays a system sound when Claude needs your input |
| 14 | [Desktop Toast](hooks/notifications/14-desktop-toast/) | Notification | Starter | Shows a Windows balloon/toast notification |
| 15 | [Session Summary on Exit](hooks/notifications/15-session-summary-on-exit/) | Stop | Intermediate | Logs a session summary to a file when Claude stops |

### Productivity

| # | Hook | Event | Difficulty | Description |
|---|------|-------|------------|-------------|
| 16 | [Copy File Path to Clipboard](hooks/productivity/16-copy-file-path-to-clipboard/) | PostToolUse | Starter | Copies the path of any created/edited file to your clipboard |
| 17 | [Auto-Format on Save](hooks/productivity/17-auto-format-on-save/) | PostToolUse | Intermediate | Runs Prettier or Black automatically after Claude writes a file |
| 18 | [Session Context Loader](hooks/productivity/18-session-context-loader/) | SessionStart | Intermediate | Injects current git branch, recent commits, and project state at session start |

### Input Guard

| # | Hook | Event | Difficulty | Description |
|---|------|-------|------------|-------------|
| 19 | [Prompt Sensitive Data Audit](hooks/input-guard/19-prompt-sensitive-data-audit/) | UserPromptSubmit | Intermediate | Scans your messages for accidentally pasted secrets |

### Bonus

**[Manual Backup](hooks/bonus/manual-backup/)** -- A companion script you run yourself before `/clear` or `/compact`. These commands have no hook event, so this is a manual workaround to save your conversation transcript.

## How Hooks Work

| Concept | What it means |
|---------|---------------|
| Hook type | When it fires -- `PreToolUse` (before Claude acts), `PostToolUse` (after), `Notification`, `SessionStart`, `Stop`, `PreCompact`, etc. |
| Matcher | Which tool to filter on -- `Write`, `Edit`, `Bash`, or no matcher (fires for all tools) |
| stdin JSON | Claude Code sends event data as JSON on stdin to your script |
| stdout | Your script's stdout goes into Claude's context (Claude can read it) |
| Exit code 0 | Success -- Claude continues normally |
| Exit code 2 | Block -- the tool call is prevented, your stderr message is shown to Claude |

For a deeper explanation of the hook lifecycle, matchers, and JSON schema: **[docs/hooks-explained.md](docs/hooks-explained.md)**

## Platform

**Primary:** Windows (PowerShell 5.1+). Every hook ships as a `.ps1` file first.

**Alternative:** Bash scripts for macOS and Linux are included alongside each PowerShell version.

Both versions are functionally identical. Use whichever matches your OS.

## What Hooks Can't Do

Hooks have real limitations. A few worth knowing upfront:

- No hook fires for `/clear` or `/compact` (user-initiated) -- that is why the manual backup script exists
- Hooks cannot modify Claude's behavior or prompt -- they can only allow, block, or observe tool calls
- A slow hook blocks Claude until it finishes -- keep scripts fast
- Hooks run locally, not in any sandbox -- a buggy hook can break your workflow

Full details: **[docs/limitations-and-gaps.md](docs/limitations-and-gaps.md)**

## Contributing

Contributions welcome -- new hooks, bug fixes, docs improvements, platform coverage.

See **[CONTRIBUTING.md](CONTRIBUTING.md)** for guidelines.

## Resources

- [Claude Code Hooks -- Official Documentation](https://docs.anthropic.com/en/docs/claude-code/hooks)
- [Hook Lifecycle and Events](https://docs.anthropic.com/en/docs/claude-code/hooks#hook-types)
- [Troubleshooting Guide](docs/troubleshooting.md)

---

MIT License. See [LICENSE](LICENSE).
