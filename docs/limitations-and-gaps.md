# Limitations and Gaps

Hooks are useful. They are not bulletproof. This document covers the real limitations you should know about before relying on them.

---

## 1. /clear Has No Hook Event

There is no `PreClear`, `PostClear`, or similar event. When you run `/clear` in Claude Code, your entire conversation context is wiped and no hook fires.

The same applies to user-initiated `/compact` -- the `PreCompact` event only fires for Claude's *automatic* compaction, not when you manually trigger it.

**Workaround:** Use the [Manual Backup](../companion-scripts/manual-backup/) companion script before running `/clear` or `/compact`. It copies the transcript file to a timestamped backup. This is a manual step -- you have to remember to do it.

**Why it matters:** If you built hooks that maintain session state or rely on conversation history, a `/clear` wipes the slate with no warning to your hooks.

## 2. Hooks Are Safety Nets, Not Security Boundaries

A PreToolUse hook that blocks `rm -rf` is a safety net. It catches the obvious cases. It is not a security boundary.

**What slips through:**

- Novel destructive patterns not in your blocklist (`find / -delete`, `chmod -R 000 /`)
- Obfuscated commands (`r''m -rf /`, using variables or subshells to construct commands)
- Commands that are destructive in context but look harmless in isolation
- Prompt injection that convinces Claude to work around the hook's logic

Regex-based pattern matching will always have gaps. Treat hooks as a layer of defense that catches common mistakes, not as a guarantee against all destructive actions. Keep backups. Use git. Review the tool calls Claude makes.

## 3. PostToolUse stdout Goes to Claude's Context, Not Your Screen

When a PostToolUse hook writes to stdout, that output is injected into Claude's context. Claude can read it and respond to it. But the user never sees it on screen.

This catches people who write hooks expecting to see output in their terminal:

```powershell
# This goes to Claude, not to your terminal
Write-Output "File written: $filePath"
```

**If you want the user to see something**, use one of these instead:

- **stderr** -- some terminals show it, but it is not guaranteed to be visible in Claude Code's UI
- **A log file** -- append to a known location and check it later
- **The clipboard** -- copy the value so the user can paste it
- **A system notification** -- toast, sound, or taskbar flash
- **A separate file** -- write a summary file the user can open

## 4. PowerShell Startup Latency

PowerShell takes 200-500ms to start a new process. This happens every time a synchronous hook fires. On a busy session where Claude makes many tool calls, this adds up.

**Mitigations:**

- Always use `-NoProfile` to skip profile loading (saves ~100-200ms)
- Set `"async": true` for non-critical hooks (notifications, clipboard, logging)
- Keep hook scripts short and avoid importing heavy modules
- Consider combining multiple hooks into a single script if they fire on the same event and matcher

Bash scripts on macOS/Linux start in under 50ms, so this is primarily a Windows concern.

## 5. Tilde (~) Path Expansion on Windows

PowerShell does not always expand `~` in `-File` arguments the way Bash does. This can cause "file not found" errors that are confusing because the path *looks* correct.

```json
{
  "command": "powershell -File ~/.claude/hooks/script.ps1"
}
```

This may fail on Windows. Always use the full path:

```json
{
  "command": "powershell -NoProfile -ExecutionPolicy Bypass -File C:/Users/YOUR_USERNAME/.claude/hooks/script.ps1"
}
```

Use forward slashes -- they work in PowerShell and avoid JSON backslash-escaping issues.

## 6. Auto-Formatter Feedback Loops

If a PostToolUse hook reformats a file (runs Prettier, Black, or another formatter), Claude may notice the changes the next time it reads the file. If Claude thinks the formatting was "wrong" or different from what it intended, it may try to edit the file again, which triggers the formatter again, creating a loop.

**Mitigations:**

- Configure Claude to use the same formatting rules as your formatter (add formatting preferences to CLAUDE.md)
- Use the formatter only on file types Claude does not typically re-read immediately
- Add a guard in the hook to skip files that were recently formatted (check a temp marker file or timestamp)
- Accept that some minor friction is the cost of auto-formatting

This is less of a problem in practice than it sounds, because Claude usually does not re-read files it just wrote unless the next step specifically requires it. But it can happen.

## 7. Malicious Project settings.json

Claude Code reads `.claude/settings.json` from the project directory. If you clone a repository that contains a malicious `.claude/settings.json`, the hooks defined in it will run automatically when you use Claude Code in that project.

A malicious hook could:

- Exfiltrate environment variables or file contents
- Run arbitrary commands on your machine
- Modify files outside the project directory
- Install backdoors

**Mitigations:**

- Review `.claude/settings.json` in any new repo before using Claude Code in it, the same way you would review a Makefile or a postinstall script
- Use `.claude/settings.local.json` (gitignored) for your personal hooks instead of the shared project file
- Be cautious with repos from untrusted sources

This is fundamentally the same risk as `npm postinstall` scripts or Makefile targets -- any project can define code that runs on your machine. The difference is that hooks run not when you type a command, but when Claude uses a tool, which makes them less visible.

---

## Summary

| Limitation | Severity | Workaround Available? |
|-----------|----------|----------------------|
| No /clear hook event | Medium | Yes -- manual backup script |
| Not a security boundary | High | Partial -- layered defense, not sole defense |
| PostToolUse stdout hidden from user | Low | Yes -- use stderr, log file, clipboard, notification |
| PowerShell startup latency | Low | Yes -- `-NoProfile`, async |
| Tilde path expansion on Windows | Low | Yes -- use full paths |
| Auto-formatter feedback loops | Low | Partial -- alignment + guards |
| Malicious project settings | Medium | Yes -- review before use |

---

## Further Reading

- [Hooks Deep Dive](hooks-explained.md) -- how hooks work, stdin JSON, exit codes
- [Troubleshooting](troubleshooting.md) -- common problems and fixes
- [Manual Backup Script](../companion-scripts/manual-backup/) -- workaround for the /clear gap
