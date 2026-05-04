# Hook Lifecycle Events

A reference of every hook event type Claude Code supports, when it fires, and what it is commonly used for.

For a deeper explanation of how hooks work, see [Hooks Deep Dive](hooks-explained.md).

---

## Event Reference

| Event | When It Fires | stdin Contains | stdout Goes To | Common Use Cases |
|-------|--------------|----------------|----------------|-----------------|
| **PreToolUse** | Before any tool executes | Tool name, input, session info | Ignored | Block dangerous commands, protect files, validate inputs, gate operations |
| **PostToolUse** | After a tool completes successfully | Tool name, input, response, duration | Claude's context | Log changes, format files, copy to clipboard, count modifications, notify |
| **PreCompact** | Before auto-compaction starts | Session info, transcript path | Ignored | Back up conversation transcript, save session state |
| **PostCompact** | After auto-compaction completes | Session info | Ignored | Log what was compacted, verify transcript integrity |
| **SessionStart** | When a new Claude Code session begins | Session info, cwd | Injected into Claude's starting context | Inject context (git branch, TODOs, project state, recent changes) |
| **SessionEnd** | When a session ends | Session info | Ignored | Cleanup temp files, log session duration |
| **Stop** | When Claude's turn ends (response complete) | Session info | Ignored | Session summary, write logs, send notifications |
| **Notification** | When Claude sends a notification (needs input) | Notification info | Ignored | Play sound, show toast, send Slack webhook, flash taskbar |
| **UserPromptSubmit** | When the user sends a message | User message content, session info | Injected into context | Audit for sensitive data, inject additional context, log prompts |
| **SubagentStart** | When a subagent (parallel task) spawns | Subagent info, parent session | Ignored | Log subagent activity, monitor resource usage |
| **SubagentStop** | When a subagent finishes | Subagent results, duration | Ignored | Log results, aggregate metrics |
| **FileChanged** | When a watched file changes on disk | File path, change type | Ignored | Auto-reload configs, re-run tests, trigger builds |

## Event Details

### PreToolUse

The most commonly used event. Fires before Claude executes any tool call. This is your chance to inspect what Claude is about to do and block it if necessary.

**Blocking:** Exit code 2 prevents the tool from executing. Your stderr message is shown to Claude as the block reason. Exit code 0 allows it.

**Matcher filtering:** Use `"matcher": "Bash"` to fire only on shell commands, `"matcher": "Write"` for file creation, etc. An empty or absent matcher fires for all tools.

**Example hooks:** [Block Destructive Commands](../hooks/safety/01-block-destructive-commands/), [Critical File Guard](../hooks/safety/02-critical-file-guard/), [Branch Protection](../hooks/git/07-branch-protection/)

### PostToolUse

Fires after a tool call completes successfully. The tool has already executed -- you cannot block it, but you can observe the result and take follow-up actions.

**stdout behavior:** Your script's stdout is injected into Claude's context. Claude can read it and respond to it, but the user does not see it on screen. If you want the user to see something, use stderr, a log file, or a system notification.

**Example hooks:** [Copy File Path to Clipboard](../hooks/productivity/16-copy-file-path-to-clipboard/), [Auto-Format on Save](../hooks/productivity/17-auto-format-on-save/), [Mass Change Detector](../hooks/human-in-control/10-mass-change-detector/)

### PreCompact

Fires before Claude's auto-compaction process. Auto-compaction happens when the conversation gets long and Claude needs to summarize earlier context to stay within its context window.

**Why it matters:** After compaction, the full conversation transcript is trimmed. If you want to preserve the complete transcript, back it up before compaction starts. The `transcript_path` field in stdin tells you where the file is.

**Example hook:** [Pre-Compact Backup](../hooks/git/09-pre-compact-backup/)

### PostCompact

Fires after auto-compaction completes. Useful for logging or verifying what was kept after compaction.

### SessionStart

Fires once when a new Claude Code session begins. Stdout from this hook is injected directly into Claude's starting context, making it useful for giving Claude information it should know upfront.

**Example hook:** [Session Context Loader](../hooks/productivity/18-session-context-loader/) -- injects the current git branch, recent commits, and open TODOs into Claude's context at session start.

### SessionEnd

Fires when a session ends (user exits or session times out). Useful for cleanup and logging.

### Stop

Fires when Claude's turn ends -- that is, when Claude finishes generating a response and is waiting for user input. Differs from SessionEnd in that it fires after every Claude turn, not just at session end.

**Example hook:** [Session Summary on Exit](../hooks/notifications/15-session-summary-on-exit/)

### Notification

Fires when Claude sends a notification, typically when it finishes a task and needs user input. This is the event to use for attention-grabbing hooks.

**Example hooks:** [Sound on Completion](../hooks/notifications/13-sound-on-completion/), [Desktop Toast](../hooks/notifications/14-desktop-toast/)

### UserPromptSubmit

Fires when the user sends a message to Claude. Useful for auditing, logging, or injecting additional context into the conversation.

### SubagentStart / SubagentStop

Fire when Claude spawns or finishes a subagent (a parallel worker for tasks like multi-file search). Useful for monitoring and logging in complex sessions.

### FileChanged

Fires when a file on disk changes. Useful for auto-reload workflows, triggering re-tests, or watching configuration files.

## Event Timing Diagram

```
User sends a message
    |
    v
[UserPromptSubmit] ---- your hook can audit or inject context
    |
    v
Claude processes the message
    |
    v
Claude decides to call a tool (e.g., Bash)
    |
    v
[PreToolUse] ----------- your hook can BLOCK (exit 2) or allow (exit 0)
    |
    v
Tool executes (if not blocked)
    |
    v
[PostToolUse] ---------- your hook can observe, log, format, notify
    |
    v
Claude continues (may call more tools)
    |
    v
Claude finishes its response
    |
    v
[Stop] ----------------- your hook can summarize, log
    |
    v
[Notification] --------- your hook can play sound, show toast
    |
    v
Waiting for user input...
```

## Which Events Can Block?

Only **PreToolUse** supports blocking via exit code 2. All other events are observe-only -- your hook runs, but it cannot prevent the action from happening.

| Event | Can Block? |
|-------|-----------|
| PreToolUse | Yes (exit 2) |
| PostToolUse | No (tool already ran) |
| PreCompact | No |
| PostCompact | No |
| SessionStart | No |
| SessionEnd | No |
| Stop | No |
| Notification | No |
| UserPromptSubmit | No |
| SubagentStart | No |
| SubagentStop | No |
| FileChanged | No |

---

## Further Reading

- [Hooks Deep Dive](hooks-explained.md) -- how hooks work, stdin JSON structure, exit codes
- [Limitations and Gaps](limitations-and-gaps.md) -- what hooks cannot do
- [Troubleshooting](troubleshooting.md) -- common problems and fixes
