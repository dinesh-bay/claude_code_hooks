# Troubleshooting

Common problems with Claude Code hooks, their causes, and how to fix them.

For background on how hooks work, see the [Hooks Deep Dive](hooks-explained.md).

---

## 1. Hook Not Firing

**Problem:** You added a hook to `settings.json`, but it never runs. Claude executes the tool call without your hook intercepting it.

**Causes and fixes:**

- **Wrong matcher spelling.** Matchers are case-sensitive. `"Bash"` works, `"bash"` does not. The tool names are: `Bash`, `Write`, `Edit`, `Read` (capital first letter).

- **Settings file in the wrong location.** Global hooks go in `~/.claude/settings.json`. Project hooks go in `<project>/.claude/settings.json`. If the file is in the wrong place, Claude Code will not find it.

- **JSON syntax error.** If `settings.json` has invalid JSON, Claude Code may silently ignore it. Validate your JSON (check for trailing commas, missing quotes, unmatched braces). Paste it into a JSON validator like [jsonlint.com](https://jsonlint.com/).

- **Hook added mid-session.** Hooks are loaded when the session starts. If you added or changed hooks, start a new Claude Code session for them to take effect.

- **Script path does not exist.** If the `-File` path in the command points to a file that does not exist, the hook fails silently. Double-check the full path.

## 2. Hook Fires But No Visible Output

**Problem:** You know the hook is running (you can verify via a log file), but you do not see any output in the Claude Code interface.

**Cause:** PostToolUse hooks send their stdout to Claude's context, not to the user's screen. Claude can read it, but you cannot see it.

**Fix:** Do not use stdout for user-facing output. Instead:

- Write to a **log file**: `"Hook triggered at $(Get-Date)" | Out-File -Append debug_hook.log`
- Copy to **clipboard**: `$value | Set-Clipboard`
- Show a **system notification**: use `BurntToast` or `[System.Windows.Forms.NotifyIcon]`
- Write to **stderr**: `[Console]::Error.WriteLine("...")` (visibility depends on the client)

See [Limitations: PostToolUse stdout](limitations-and-gaps.md#3-posttooluse-stdout-goes-to-claudes-context-not-your-screen) for details.

## 3. PowerShell Execution Policy Error

**Problem:** The hook fails with an error like:

```
File C:\Users\you\.claude\hooks\script.ps1 cannot be loaded because running scripts
is disabled on this system.
```

**Cause:** The default execution policy on many Windows machines is `Restricted`, which blocks all scripts.

**Fix:** The `-ExecutionPolicy Bypass` flag in the hook command should handle this:

```json
{
  "command": "powershell -NoProfile -ExecutionPolicy Bypass -File C:/Users/you/.claude/hooks/script.ps1"
}
```

If this still fails, set the policy for your user once:

```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
```

## 4. Tilde Path Does Not Resolve

**Problem:** The hook command uses `~` and PowerShell cannot find the script:

```json
{
  "command": "powershell -File ~/.claude/hooks/script.ps1"
}
```

**Cause:** PowerShell does not reliably expand `~` in the `-File` argument on Windows.

**Fix:** Replace the tilde with the full path:

```json
{
  "command": "powershell -NoProfile -ExecutionPolicy Bypass -File C:/Users/YOUR_USERNAME/.claude/hooks/script.ps1"
}
```

Use forward slashes to avoid JSON backslash-escaping.

## 5. Hook Is Too Slow / Blocks Claude

**Problem:** Claude pauses noticeably before every tool call. The session feels sluggish.

**Cause:** A synchronous hook takes too long to execute. Common causes:
- PowerShell profile loading (200-500ms per invocation)
- Heavy imports in the script
- Network calls (webhook, API)
- Formatter tools (Prettier, Black)

**Fix:**

1. Add `-NoProfile` to the command if missing (saves 100-200ms):
   ```json
   { "command": "powershell -NoProfile -ExecutionPolicy Bypass -File ..." }
   ```

2. Set `"async": true` for non-critical hooks (notifications, clipboard, logging):
   ```json
   { "type": "command", "command": "...", "async": true }
   ```

3. Set a `timeout` to cap worst-case execution time:
   ```json
   { "type": "command", "command": "...", "timeout": 5 }
   ```

4. Keep scripts minimal -- avoid importing modules you do not need.

## 6. "Invalid JSON" After Editing settings.json

**Problem:** Claude Code does not load hooks, or you see a JSON parse error.

**Cause:** Common JSON syntax mistakes:

- **Trailing comma** after the last item in an array or object:
  ```json
  { "hooks": { "PreToolUse": [ { "matcher": "Bash" }, ] } }
  ```
  The comma after `}` and before `]` is invalid JSON.

- **Missing quotes** around keys or values.

- **Single quotes** instead of double quotes. JSON requires double quotes only.

- **Comments** in the file. JSON does not support `//` or `/* */` comments.

**Fix:** Paste your `settings.json` content into a JSON validator ([jsonlint.com](https://jsonlint.com/) or run `python -m json.tool settings.json` in a terminal). Fix the errors it reports.

## 7. Hook Works in Terminal But Not in Claude Code

**Problem:** You tested the script manually in PowerShell (or Bash), and it works. But when Claude Code runs it, nothing happens or it errors.

**Cause:** Claude Code passes data via **stdin JSON**, not command-line arguments. If your script reads from `$args` or `$1` instead of stdin, it will not receive any data.

**Fix:** Make sure your script reads stdin:

**PowerShell:**
```powershell
$json = $input | Out-String
$data = $json | ConvertFrom-Json
```

**Bash:**
```bash
json=$(cat)
data=$(echo "$json" | jq -r '.tool_input.command // empty')
```

Also check that the script path in `settings.json` matches exactly where the file lives on disk. Paths are case-sensitive on macOS/Linux.

## 8. Block Not Working (Claude Still Executes the Command)

**Problem:** Your PreToolUse hook should block a command, but Claude runs it anyway.

**Causes:**

- **Wrong exit code.** Only exit code `2` blocks. Exit code `1` is treated as an error, not a block. Check that your script exits with exactly `2`:
  ```powershell
  exit 2    # blocks
  exit 1    # does NOT block
  ```

- **Hook is not PreToolUse.** Blocking only works on `PreToolUse`. A `PostToolUse` hook cannot block -- the tool has already run.

- **Matcher does not match.** If your matcher says `"Write"` but Claude used the `Bash` tool to write a file (e.g., `echo "text" > file.txt`), the hook does not fire.

## 9. Script Crashes with "Cannot Convert JSON" or Similar Parse Errors

**Problem:** The PowerShell script throws an error when parsing the stdin JSON.

**Causes:**

- **Empty stdin.** Some events may not send JSON, or the pipe may close before the script reads. Add a guard:
  ```powershell
  $json = $input | Out-String
  if (-not $json) { exit 0 }
  $data = $json | ConvertFrom-Json
  ```

- **Unicode in the JSON.** If the JSON contains unusual characters (emoji, private-use-area Unicode), older PowerShell versions may choke. Ensure the script handles encoding gracefully.

## 10. Multiple Hooks Under the Same Event Conflict

**Problem:** You have two hooks under `PreToolUse` and one seems to override the other.

**Cause:** If both hooks match the same tool call, both run. But if the first one exits with code 2 (block), the tool call is blocked and the second hook may not fire (depending on execution order).

**Fix:** This is usually not a problem in practice. Hooks run sequentially for the same event. If a PreToolUse hook blocks, the tool call does not happen. If you need both hooks to always run, make sure neither blocks calls the other depends on.

---

## Still Stuck?

1. **Add logging to your script.** Write to a file at each step so you can trace what happens:
   ```powershell
   "$(Get-Date): Hook started" | Out-File -Append C:/Users/you/debug_hook.log
   $json = $input | Out-String
   "$(Get-Date): stdin = $json" | Out-File -Append C:/Users/you/debug_hook.log
   ```

2. **Test the script manually.** Pipe sample JSON into it and check the exit code:
   ```powershell
   '{"tool_name":"Bash","tool_input":{"command":"rm -rf /"}}' | powershell -NoProfile -File C:/Users/you/.claude/hooks/script.ps1
   echo $LASTEXITCODE
   ```

3. **Simplify.** Replace your hook with the simplest possible version (just `exit 0` or `exit 2`) to confirm the hook machinery works, then add logic back incrementally.

---

## Further Reading

- [Hooks Deep Dive](hooks-explained.md) -- how hooks work, stdin JSON, exit codes, matchers
- [Limitations and Gaps](limitations-and-gaps.md) -- things hooks cannot do
- [Hook Lifecycle Events](hook-lifecycle-events.md) -- all event types reference
