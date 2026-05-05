# Claude Code Hooks -- A Curated Collection

> Ready-to-use hooks that put you in control of Claude Code. Windows-first. Beginner-friendly.

## What Are Hooks?

Hooks are scripts that run automatically when Claude Code does something -- before it writes a file, after it runs a command, when a session starts.

Think of it like git hooks, but for everything Claude does.

## Why You Need Hooks

Claude Code is powerful. It can also:

- `rm -rf` your project directory
- `git push --force` to main
- Overwrite your `.env` with test values
- Delete test files it thinks are "unnecessary"
- Rewrite a 2,000-line file when it only needed to change one line

These are not hypothetical. The community has reported real data loss from all of the above.

Clicking "Allow" on every tool call is not real control. You're pattern-matching a wall of text under time pressure. Hooks give you programmable guardrails that work every time, without fatigue.

## Quick Start

New to hooks? Start here: **[INSTALL.md](INSTALL.md)** -- your first hook in under 5 minutes.

Already familiar? Browse the catalog below and copy what you need.

---

## The Catalog

20 hooks organized by what they protect.

### Safety

| # | Hook | Difficulty | Description |
|---|------|------------|-------------|
| 1 | [Block Destructive Commands](hooks/safety/01-block-destructive-commands/) | Starter | Blocks `rm -rf`, `git reset --hard`, and other destructive commands |
| 2 | [Critical File Guard](hooks/safety/02-critical-file-guard/) | Starter | Blocks modifications to `.env`, CI configs, Dockerfiles |
| 3 | [Large File Overwrite Guard](hooks/safety/03-large-file-overwrite-guard/) | Intermediate | Blocks overwriting files with 300+ lines |
| 4 | [Scope Boundary Guard](hooks/safety/04-scope-boundary-guard/) | Intermediate | Blocks file operations outside the project directory |
| 5 | [Secret Scanner](hooks/safety/05-secret-scanner/) | Intermediate | Detects API keys, passwords, tokens before they're written |
| 6 | [Uncommitted Work Guard](hooks/safety/06-uncommitted-work-guard/) | Intermediate | Blocks destructive git ops when you have uncommitted changes |

### Git Protection

| # | Hook | Difficulty | Description |
|---|------|------------|-------------|
| 7 | [Branch Protection](hooks/git/07-branch-protection/) | Starter | Blocks push to main/master, blocks force push |
| 8 | [Dependency Change Guard](hooks/git/08-dependency-change-guard/) | Starter | Warns when package.json, requirements.txt, lock files are modified |
| 9 | [Pre-Compact Backup](hooks/git/09-pre-compact-backup/) | Starter | Saves conversation transcript before auto-compaction |

### Human-in-Control

| # | Hook | Difficulty | Description |
|---|------|------------|-------------|
| 10 | [Mass Change Detector](hooks/human-in-control/10-mass-change-detector/) | Intermediate | Warns after 8+ files modified in one session |
| 11 | [Dangerous Interpreter Guard](hooks/human-in-control/11-dangerous-interpreter-guard/) | Intermediate | Blocks long inline `python -c`, `node -e` one-liners |
| 12 | [Test File Deletion Guard](hooks/human-in-control/12-test-file-deletion-guard/) | Intermediate | Prevents deletion or gutting of test files |

### Notifications

| # | Hook | Difficulty | Description |
|---|------|------------|-------------|
| 13 | [Sound on Completion](hooks/notifications/13-sound-on-completion/) | Starter | Plays a system sound when Claude needs your input |
| 14 | [Desktop Toast](hooks/notifications/14-desktop-toast/) | Starter | Shows a Windows balloon notification |
| 15 | [Session Summary on Exit](hooks/notifications/15-session-summary-on-exit/) | Intermediate | Logs session summary to a file when Claude stops |

### Productivity

| # | Hook | Difficulty | Description |
|---|------|------------|-------------|
| 16 | [Copy File Path to Clipboard](hooks/productivity/16-copy-file-path-to-clipboard/) | Starter | Copies absolute path of created files to clipboard |
| 17 | [Auto-Format on Save](hooks/productivity/17-auto-format-on-save/) | Intermediate | Runs Prettier/Black after file writes |
| 18 | [Session Context Loader](hooks/productivity/18-session-context-loader/) | Intermediate | Injects git branch + recent commits at session start |

### Input Guard

| # | Hook | Difficulty | Description |
|---|------|------------|-------------|
| 19 | [Prompt Sensitive Data Audit](hooks/input-guard/19-prompt-sensitive-data-audit/) | Intermediate | Scans your messages for accidentally pasted secrets |

### Context

| # | Hook | Difficulty | Description |
|---|------|------------|-------------|
| 20 | [Context Saver](hooks/context/20-context-saver/) | Intermediate | Saves conversation summary when context exceeds 70% |

### Bonus

**[Manual Backup](companion-scripts/manual-backup/)** -- Run before `/clear` to save your transcript. `/clear` has no hook event, so this is a manual workaround.

---

## Platform

**Primary:** Windows (PowerShell). Every hook ships as a `.ps1` script.

**Alternative:** Bash (macOS/Linux) `.sh` scripts included in every hook folder.

Both versions are functionally identical.

## Which Hooks Do I Need?

You don't need all 20. Start small:

| Preset | Hooks | Best for |
|--------|-------|----------|
| **Starter** | #1, #7, #13 | Everyone -- install these first |
| **Safe Default** | #1, #2, #5, #6, #7, #13 | Daily users -- best protection-to-performance ratio |
| **QA / Tester** | Safe Default + #12, #19, #20 | Test-focused teams |
| **Team** | Safe Default + #3, #8, #10, #15, #18, #20 | Shared codebases |
| **Everything** | All 20 (use [combined script](optimized/)) | Maximum protection |

Full guide with performance numbers: **[docs/which-hooks-do-i-need.md](docs/which-hooks-do-i-need.md)**

## Contributing

See **[CONTRIBUTING.md](CONTRIBUTING.md)** for how to add a hook.

---

## How Hooks Actually Work -- The Full Picture

Everything above is enough to start using hooks. This section explains how they work under the hood -- read it when you want to write your own or understand what's happening.

### Where Hooks Live

Hooks are configured in `settings.json`. There are three levels:

| File | Scope | Precedence |
|------|-------|-----------|
| `~/.claude/settings.json` | Global -- applies to all projects | Lowest |
| `.claude/settings.json` | Project -- checked into git, shared with team | Middle |
| `.claude/settings.local.json` | Project local -- gitignored, machine-specific | Highest |

On Windows, `~` means `C:\Users\<username>`. The global file is the one most people use.

### Hook Types: When They Fire

Claude Code has a lifecycle. Hooks let you tap into specific moments:

```
You type a message
    │
    ▼
UserPromptSubmit fires ──► Scan message for secrets (#19)
    │
    ▼
Claude decides to call a tool (Write, Bash, Edit, etc.)
    │
    ▼
PreToolUse fires ──────► Block or allow the tool call (#1-8, #11-12)
    │
    ├── If blocked (exit 2): Claude sees your error message, tool does NOT run
    │
    ▼
Tool executes (file written, command run, etc.)
    │
    ▼
PostToolUse fires ─────► Observe, log, copy to clipboard (#10, #16-17)
    │
    ▼
Claude's turn ends
    │
    ▼
Stop fires ────────────► Log session summary (#15)
    │
    ▼
Notification fires ────► Play sound, show toast (#13-14)
```

Other lifecycle events:

| Event | When | Use Case |
|-------|------|----------|
| **PreToolUse** | Before a tool runs | Block dangerous commands, protect files, validate |
| **PostToolUse** | After a tool completes | Log changes, format code, copy paths |
| **PreCompact** | Before auto-compaction | Back up conversation transcript (#9) |
| **SessionStart** | When a session begins | Inject context -- git branch, TODOs (#18) |
| **Stop** | When Claude's turn ends | Session summary, cleanup (#15) |
| **Notification** | On notification events | Sound, toast, Slack (#13-14) |
| **UserPromptSubmit** | When you send a message | Audit for secrets (#19) |
| **SessionEnd** | When session closes | Final cleanup |
| **SubagentStart/Stop** | When subagents spawn/finish | Monitor multi-agent work |
| **FileChanged** | When a watched file changes | Auto-reload, re-test |

### PreToolUse vs PostToolUse -- The Key Difference

This is the most important concept:

**PreToolUse** runs BEFORE Claude's action. It can **block** the action.
- Exit code 0 → allow, Claude proceeds
- Exit code 2 → block, tool does NOT execute, your stderr message is shown

**PostToolUse** runs AFTER Claude's action. It can only **observe**.
- Exit code 0 → always (you can't undo what already happened)
- Use it for logging, formatting, notifications -- not for prevention

Most safety hooks are PreToolUse (prevent damage). Most productivity hooks are PostToolUse (react to what happened).

### Matchers: Filtering Which Tool Fires the Hook

You don't want every hook to fire for every tool. Matchers filter:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [{ "type": "command", "command": "..." }]
      }
    ]
  }
}
```

`"matcher": "Bash"` means this hook ONLY fires when Claude runs a Bash command. It won't fire for Write, Edit, or Read.

Available matchers: `Bash`, `Write`, `Edit`, `Read`, or omit the matcher entirely to fire for all tools.

Some hooks need multiple matchers. For example, the Critical File Guard needs to fire for both Write and Edit:

```json
"PreToolUse": [
  {
    "matcher": "Write",
    "hooks": [{ "type": "command", "command": "powershell ... critical-file-guard.ps1" }]
  },
  {
    "matcher": "Edit",
    "hooks": [{ "type": "command", "command": "powershell ... critical-file-guard.ps1" }]
  }
]
```

### stdin JSON: What Your Script Receives

When your hook fires, Claude Code pipes a JSON object to your script's stdin. This is the **real** structure (captured from an actual debug session):

```json
{
  "session_id": "d641f6ac-0708-452e-9a01-22c8a866bfc4",
  "transcript_path": "C:\\Users\\gudinesh\\.claude\\projects\\...\\d641f6ac.jsonl",
  "cwd": "C:\\Users\\gudinesh",
  "hook_event_name": "PostToolUse",
  "tool_name": "Write",
  "tool_input": {
    "file_path": "C:\\Users\\gudinesh\\test_hook_output.txt",
    "content": "Hook test attempt.\n"
  },
  "tool_response": {
    "type": "create",
    "filePath": "C:\\Users\\gudinesh\\test_hook_output.txt"
  },
  "tool_use_id": "toolu_016CDLAkTZXvGEgpcjqWCVtK",
  "duration_ms": 21
}
```

Key fields your scripts will use:

| Field | Available When | Contains |
|-------|---------------|----------|
| `tool_input.command` | Bash tool | The shell command Claude wants to run |
| `tool_input.file_path` | Write/Edit tool | Full absolute path of the target file |
| `tool_input.content` | Write tool | The file content being written |
| `tool_name` | All tool events | Which tool: "Write", "Edit", "Bash", etc. |
| `cwd` | All events | Current working directory |
| `session_id` | All events | Unique session identifier |
| `transcript_path` | All events | Path to the conversation transcript file |

### stdout and stderr: What Goes Where

| Stream | PreToolUse | PostToolUse | SessionStart |
|--------|-----------|-------------|-------------|
| **stdout** | Ignored | Goes to Claude's context (Claude can read it, but user doesn't see it) | Injected into Claude's starting context |
| **stderr** | Shown as the block message when exit code is 2 | Shown as warning text | Ignored |

This is a common gotcha: if your PostToolUse hook prints something to stdout, **you** won't see it in the conversation -- it goes to Claude's internal context. Use stderr, a log file, a notification, or clipboard instead.

### Exit Codes

| Code | Meaning | Works In |
|------|---------|----------|
| **0** | Success -- continue normally | All events |
| **2** | Block -- prevent the tool from executing | PreToolUse and UserPromptSubmit only |

Any other exit code is treated as an error (hook failed, Claude continues anyway).

### Async vs Sync

By default, hooks are **synchronous** -- Claude waits for your script to finish before continuing. This is correct for safety hooks (you need to block before the action happens).

For non-critical hooks (clipboard, formatting, logging), add `"async": true` so Claude doesn't wait:

```json
{
  "matcher": "Write",
  "hooks": [{ "type": "command", "command": "...", "timeout": 5 }],
  "async": true
}
```

### Anatomy of a Hook Script (PowerShell)

Every hook follows the same pattern:

```powershell
# 1. Read the JSON from stdin
$raw = [Console]::In.ReadToEnd()
$json = $raw | ConvertFrom-Json

# 2. Extract the field you care about
$command = $json.tool_input.command

# 3. Check your condition
if ($command -match 'rm\s+-rf') {
    # 4a. Block: write to stderr + exit 2
    [Console]::Error.WriteLine("BLOCKED: $command")
    [Console]::Error.WriteLine("This would delete files recursively.")
    exit 2
}

# 4b. Allow: exit 0
exit 0
```

For Bash:

```bash
#!/usr/bin/env bash
set -euo pipefail

# 1. Read stdin
INPUT=$(cat)

# 2. Extract field (using python3 for JSON parsing)
COMMAND=$(echo "$INPUT" | python3 -c \
  "import sys,json; print(json.load(sys.stdin).get('tool_input',{}).get('command',''))")

# 3. Check condition
if echo "$COMMAND" | grep -qP 'rm\s+-rf'; then
    echo "BLOCKED: $COMMAND" >&2
    exit 2
fi

exit 0
```

### Windows-Specific Notes

- **Always use `-NoProfile -ExecutionPolicy Bypass`** in your PowerShell commands -- `-NoProfile` skips loading your profile (faster), `-ExecutionPolicy Bypass` avoids policy errors
- **Use full paths, not tilde** -- `C:/Users/username/.claude/hooks/script.ps1`, not `~/.claude/hooks/script.ps1`. PowerShell doesn't always expand `~` in `-File` arguments
- **PowerShell startup takes 200-500ms** -- this is why async matters for non-critical hooks

### The Full settings.json Structure

Multiple hooks grouped by event type:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [{
          "type": "command",
          "command": "powershell -NoProfile -ExecutionPolicy Bypass -File C:/Users/YOU/.claude/hooks/block-destructive.ps1",
          "timeout": 5
        }]
      },
      {
        "matcher": "Write",
        "hooks": [{
          "type": "command",
          "command": "powershell -NoProfile -ExecutionPolicy Bypass -File C:/Users/YOU/.claude/hooks/secret-scanner.ps1",
          "timeout": 5
        }]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Write",
        "hooks": [{
          "type": "command",
          "command": "powershell -NoProfile -ExecutionPolicy Bypass -File C:/Users/YOU/.claude/hooks/copy-path.ps1",
          "timeout": 5
        }],
        "async": true
      }
    ],
    "Notification": [
      {
        "hooks": [{
          "type": "command",
          "command": "powershell -NoProfile -c \"[System.Media.SystemSounds]::Exclamation.Play()\"",
          "timeout": 5
        }]
      }
    ]
  }
}
```

For a complete example with all 19 hooks: **[examples/full-settings-example.json](examples/full-settings-example.json)**

### What Hooks Can't Do

Hooks have real limitations:

| Limitation | Workaround |
|-----------|-----------|
| `/clear` has no hook event | Use the [manual backup](companion-scripts/manual-backup/) script |
| Hooks are safety nets, not security boundaries | Novel destructive patterns will slip through regex |
| PostToolUse stdout is invisible to you | Use stderr, clipboard, log file, or notification |
| PowerShell is slow to start | Use `-NoProfile` and `async: true` |
| Auto-formatters create feedback loops | Claude sees formatter changes and may react to them |
| Malicious `.claude/settings.json` in a cloned repo | Review project settings before trusting them |

Full details: **[docs/limitations-and-gaps.md](docs/limitations-and-gaps.md)**

### Further Reading

- **[docs/hooks-explained.md](docs/hooks-explained.md)** -- Deep dive into the hook system
- **[docs/hook-lifecycle-events.md](docs/hook-lifecycle-events.md)** -- All event types reference
- **[docs/troubleshooting.md](docs/troubleshooting.md)** -- Common issues and fixes
- **[Official Claude Code Hooks Docs](https://docs.anthropic.com/en/docs/claude-code/hooks)** -- Anthropic's documentation

---

MIT License. See [LICENSE](LICENSE).
