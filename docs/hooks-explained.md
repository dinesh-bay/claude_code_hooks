# Hooks Deep Dive

A detailed guide to how Claude Code hooks work, what data they receive, and how to configure them.

If you are looking for a quick start, see the [Installation Guide](../INSTALL.md) first. This document covers the mechanics in depth.

---

## What Hooks Are

Hooks are event-driven scripts that Claude Code runs at specific points in its lifecycle. When Claude is about to execute a tool (write a file, run a command), or when a session event happens (start, stop, compaction), Claude Code can call your script before or after that action.

Think of it like git hooks, but instead of firing on `git commit` or `git push`, they fire on Claude's tool calls -- Bash, Write, Edit, Read, and more.

Your script receives a JSON payload on stdin describing the event. It inspects the payload, decides what to do, and communicates back through exit codes and stdout/stderr.

## Settings.json Locations

Hook configuration lives in `settings.json`. Claude Code checks three locations, each with different scope and precedence:

| Location | Scope | Precedence | Checked into git? |
|----------|-------|------------|-------------------|
| `~/.claude/settings.json` | Global (all projects) | Lowest | No -- user-specific |
| `<project>/.claude/settings.json` | Project (shared with team) | Middle | Yes |
| `<project>/.claude/settings.local.json` | Project local (personal overrides) | Highest | No -- gitignored |

**How precedence works:** All three files are read and merged. If the same hook event appears in multiple files, hooks from all files run. The "highest precedence" means that project-local settings can override global behavior -- for example, a project-local hook can add stricter guards on top of your global safety hooks.

**Practical guidance:**

- Put safety hooks (destructive command blocking, secret scanning) in **global** settings -- you want them everywhere.
- Put project-specific hooks (formatting rules, scope boundaries) in **project** settings so the whole team gets them.
- Put personal overrides (notification sounds, clipboard copy) in **project local** settings so they don't affect teammates.

## Hook Configuration Structure

A hook is defined inside the `hooks` key of `settings.json`, grouped by event type:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "powershell -NoProfile -ExecutionPolicy Bypass -File C:/Users/you/.claude/hooks/block-destructive.ps1",
            "timeout": 5
          }
        ]
      }
    ]
  }
}
```

| Field | Required | Description |
|-------|----------|-------------|
| `type` | Yes | Always `"command"` (the only supported type) |
| `command` | Yes | The shell command to run |
| `matcher` | No | Tool name filter (see below) |
| `timeout` | No | Max execution time in seconds |
| `async` | No | If `true`, runs without blocking Claude |

## Matcher Syntax

The `matcher` field filters which tool triggers the hook. It matches against the tool name.

| Matcher Value | Fires When |
|---------------|-----------|
| `"Bash"` | Claude runs a shell command |
| `"Write"` | Claude creates or overwrites a file |
| `"Edit"` | Claude edits part of a file |
| `"Read"` | Claude reads a file |
| `""` (empty string) | Fires for ALL tool calls |
| *(omitted)* | Fires for ALL tool calls |

The match is **case-sensitive**. `"Bash"` works, `"bash"` does not.

You can have multiple hook entries under the same event type with different matchers. For example, one hook that fires on `Bash` and another that fires on `Write`, both under `PreToolUse`:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [{ "type": "command", "command": "..." }]
      },
      {
        "matcher": "Write",
        "hooks": [{ "type": "command", "command": "..." }]
      }
    ]
  }
}
```

## stdin JSON Structure

Claude Code sends event data to your hook script as JSON on **stdin**. Your script must read stdin to get this data -- it is not passed as command-line arguments.

Here is a real example captured from a debug session, showing what a PostToolUse hook receives when Claude writes a file:

```json
{
  "session_id": "d641f6ac-0708-452e-9a01-22c8a866bfc4",
  "transcript_path": "C:\\Users\\gudinesh\\.claude\\projects\\...\\d641f6ac.jsonl",
  "cwd": "C:\\Users\\gudinesh",
  "hook_event_name": "PostToolUse",
  "tool_name": "Write",
  "tool_input": {
    "file_path": "C:\\Users\\gudinesh\\test_hook_output2.txt",
    "content": "Hook test attempt 2.\n"
  },
  "tool_response": { "type": "create", "filePath": "..." },
  "tool_use_id": "toolu_016CDLAkTZXvGEgpcjqWCVtK",
  "duration_ms": 21
}
```

### Key Fields by Tool

Not all fields are present for every tool. Here is what to expect:

| Field | Present When | Description |
|-------|-------------|-------------|
| `tool_input.command` | Bash | The shell command Claude is running |
| `tool_input.file_path` | Write, Edit | The file being created or modified |
| `tool_input.content` | Write | The full file content being written |
| `tool_input.old_string` | Edit | The text being replaced |
| `tool_input.new_string` | Edit | The replacement text |
| `tool_name` | Always | Which tool is being called |
| `hook_event_name` | Always | The event type (PreToolUse, PostToolUse, etc.) |
| `session_id` | Always | Unique ID for the current session |
| `transcript_path` | Always | Path to the conversation transcript file |
| `cwd` | Always | Claude's current working directory |
| `tool_response` | PostToolUse only | The tool's return value (after execution) |
| `duration_ms` | PostToolUse only | How long the tool call took |
| `tool_use_id` | Always | Unique ID for this specific tool call |

### Reading stdin in Your Script

**PowerShell:**
```powershell
$json = $input | Out-String
$data = $json | ConvertFrom-Json
$command = $data.tool_input.command
```

**Bash:**
```bash
json=$(cat)
command=$(echo "$json" | jq -r '.tool_input.command // empty')
```

## stdout Behavior Per Event

What happens to your script's stdout depends on which event type fired:

| Event | stdout goes to... | Practical implication |
|-------|-------------------|---------------------|
| SessionStart | Injected into Claude's starting context | Use this to give Claude information (current branch, TODOs, project state) |
| PostToolUse | Claude's context (not visible to user) | Claude can read it and react, but the user does not see it on screen |
| PreToolUse | Ignored | Do not rely on stdout for PreToolUse hooks |
| Notification | Ignored | Use system notifications, sounds, or log files instead |
| Stop | Ignored | Write to a log file if you need output |

**Key takeaway:** If you want the *user* to see something, do not write to stdout. Write to stderr, a log file, the clipboard, or trigger a system notification. stdout only reaches Claude's context (and only for certain events).

## Exit Codes

| Exit Code | Meaning | When to Use |
|-----------|---------|-------------|
| `0` | Success, continue | The hook ran, everything is fine, Claude proceeds normally |
| `2` | Block (PreToolUse only) | Prevents the tool call from executing. Your stderr message is shown to Claude as the block reason |
| Any other | Treated as an error | Claude logs it and continues. Does not block |

Exit code 2 is **only meaningful for PreToolUse** hooks. For other event types, the tool has already executed (PostToolUse) or there is nothing to block (SessionStart, Notification).

When you exit with code 2, always write a clear reason to **stderr**. Claude sees this message and uses it to understand why the action was blocked:

```powershell
# PowerShell -- block with a reason
[Console]::Error.WriteLine("BLOCKED: rm -rf detected. This would delete files recursively.")
exit 2
```

```bash
# Bash -- block with a reason
echo "BLOCKED: rm -rf detected. This would delete files recursively." >&2
exit 2
```

## Async vs Sync

By default, hooks run **synchronously** -- Claude waits for the hook to finish before continuing. This is what you want for PreToolUse hooks (you need to decide before the tool runs) and most PostToolUse hooks.

For non-critical hooks where you do not want to slow Claude down, set `"async": true`:

```json
{
  "type": "command",
  "command": "powershell -NoProfile -ExecutionPolicy Bypass -File C:/Users/you/.claude/hooks/copy-path.ps1",
  "timeout": 5,
  "async": true
}
```

Good candidates for async:
- Clipboard copy
- Sound notifications
- Log file writes
- Desktop toast notifications

Bad candidates for async:
- Anything that blocks (PreToolUse) -- the block decision would arrive too late
- Formatters that need to finish before Claude reads the file

## Timeout

Set `timeout` to cap how long a hook can run, in seconds.

```json
{ "timeout": 5 }
```

Guidance:
- **5 seconds** is a good default for most hooks (pattern matching, file checks, clipboard)
- **15+ seconds** for hooks that run external tools (formatters like Prettier or Black)
- If a hook exceeds its timeout, it is killed and Claude continues as if it returned exit code 0

Keep hooks fast. A slow synchronous hook blocks Claude on every tool call it matches. If your hook does something expensive, consider making it async.

## PowerShell Flags

When running PowerShell scripts from Claude Code, always include these flags:

```
powershell -NoProfile -ExecutionPolicy Bypass -File "C:/Users/you/.claude/hooks/script.ps1"
```

| Flag | Why |
|------|-----|
| `-NoProfile` | Skips loading your PowerShell profile. Saves 200-500ms of startup time. Without it, every hook invocation loads your full profile first. |
| `-ExecutionPolicy Bypass` | Avoids "running scripts is disabled on this system" errors. The default execution policy on many Windows machines blocks unsigned scripts. |
| `-File` | Runs a script file (as opposed to `-Command` which takes inline code). More reliable for multi-line scripts. |

Use forward slashes in the path (`C:/Users/...`), not backslashes. JSON requires escaping backslashes (`C:\\Users\\...`), so forward slashes are simpler and work fine on Windows PowerShell.

---

## Further Reading

- [All Hook Lifecycle Events](hook-lifecycle-events.md) -- reference table of every event type
- [Limitations and Gaps](limitations-and-gaps.md) -- what hooks cannot do
- [Troubleshooting](troubleshooting.md) -- common problems and fixes
- [Installation Guide](../INSTALL.md) -- get your first hook running
