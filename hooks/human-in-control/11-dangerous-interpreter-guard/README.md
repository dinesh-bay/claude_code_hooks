# Dangerous Interpreter Guard

> Blocks long inline scripts passed to `python -c`, `node -e`, and other interpreters. NOVEL -- forces Claude to write code to a file where it can be reviewed instead of hiding it in a one-liner.

**Category:** Human-in-Control
**Event:** PreToolUse
**Matcher:** Bash
**Difficulty:** Intermediate
**Platform:** PowerShell (Windows) | Bash alternative included

## The Problem

Claude sometimes generates complex logic and runs it as a single inline command:

```bash
python3 -c "import os,sys,json;data=json.load(open('config.json'));[os.remove(f) for f in data['cleanup_targets'] if os.path.exists(f)];print('Done')"
```

This is functionally identical to writing a script file and running it, but with one critical difference: **you cannot review it before execution**. The command scrolls past in Claude's tool call, buried in a wall of text. You click "Allow" and the code runs. If it does something destructive, you only find out after the fact.

Short one-liners are fine -- `python3 -c "print('hello')"` is harmless and easy to read. The danger is when the inline code grows past the point where a human can quickly parse it. At 80+ characters of inline code, you are no longer reading -- you are guessing.

This hook draws the line. If the inline code portion exceeds the threshold (default: 80 characters), the command is blocked. Claude is told to write the code to a file first, where it shows up as a Write tool call that you can inspect properly.

## What It Catches

| Interpreter | Flag | Example |
|-------------|------|---------|
| `python` / `python3` | `-c` | `python3 -c "import os; ..."` |
| `node` | `-e` | `node -e "const fs = require('fs'); ..."` |
| `ruby` | `-e` | `ruby -e "File.readlines('data.txt').each { ... }"` |
| `perl` | `-e` | `perl -e "use File::Find; find(sub { ... }, '.')"` |
| `powershell` | `-Command` | `powershell -Command "Get-ChildItem -Recurse | ..."` |

The threshold applies to the code portion only, not the interpreter command itself. `python3 -c "print('hello')"` has 16 characters of inline code and passes. `python3 -c "import os,sys,json;data=json.load(open('config.json'));[os.remove(f)...]"` has 80+ and gets blocked.

## How It Works

1. Claude calls the Bash tool with a command string
2. The PreToolUse hook fires before execution
3. The script reads the stdin JSON and extracts `tool_input.command`
4. It checks the command against each interpreter pattern using regex
5. **Match found:** extracts the inline code after the interpreter flag, measures its length
6. **Over threshold:** exits with code 2 (block) and tells Claude to write a file instead
7. **Under threshold or no match:** exits with code 0, command runs normally

## Installation

### Step 1: Copy the script

Copy `hook.ps1` to your hooks directory:

```
~/.claude/hooks/dangerous-interpreter-guard.ps1
```

### Step 2: Add to settings.json

Open `~/.claude/settings.json` and add the hook configuration. If you already have a `PreToolUse` section, merge the `Bash` matcher entry into it.

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "powershell -NoProfile -ExecutionPolicy Bypass -File C:/Users/YOUR_USERNAME/.claude/hooks/dangerous-interpreter-guard.ps1",
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
  "command": "bash ~/.claude/hooks/dangerous-interpreter-guard.sh",
  "timeout": 5
}
```

### Step 3: Restart Claude Code

Close and reopen Claude Code (or start a new session) for the hook to take effect.

## Verify It Works

Ask Claude:

> "Use python -c to read package.json, extract all dependency names, sort them, and print each one with its version on a separate line."

Claude will likely generate something like:

```bash
python3 -c "import json;d=json.load(open('package.json'));deps={**d.get('dependencies',{}),**d.get('devDependencies',{})};[print(f'{k}: {v}') for k,v in sorted(deps.items())]"
```

You should see a block message:

```
BLOCKED: Long inline script detected (142 chars).
Command starts with: python3 -c "import json;d=json.load(open('package.json'));deps={**d.get('dependencies',{}),**d.get(...
Write this to a file first so it can be reviewed.
```

Claude will then write the code to a `.py` file and run it with `python3 script.py`, giving you a chance to review the code through the Write tool call.

## Configuration

**Threshold:** Change the `$CHAR_THRESHOLD` variable at the top of `hook.ps1`. Default is 80 characters.

```powershell
$CHAR_THRESHOLD = 80
```

Lower values are stricter (block shorter one-liners). Higher values are more permissive. A value of 40 would catch most non-trivial inline scripts. A value of 200 would only catch truly excessive ones.

**Adding interpreters:** Add new patterns to the `$interpreterPatterns` array:

```powershell
$interpreterPatterns = @(
    'python3?\s+-c\s+',
    'node\s+-e\s+',
    'ruby\s+-e\s+',
    'perl\s+-e\s+',
    'powershell\s+-Command\s+',
    'php\s+-r\s+'          # Add PHP
)
```

## Limitations

- **Piped interpreters are not caught.** `echo "import os; os.remove('file')" | python3` does not match because there is no `-c` flag. The code is delivered via stdin, not as an argument.
- **Multi-command chains may pass.** `python3 -c "short" && python3 -c "short"` -- each individual inline portion could be under the threshold even though the total command is long.
- **Quoted strings with escaped quotes.** The regex strips everything before the interpreter flag. Complex quoting (nested quotes, escaped quotes) may cause the length measurement to be slightly off. In practice, this rarely matters -- the threshold is a rough line, not a precise parser.
- **Only Bash tool calls are checked.** If code reaches an interpreter through another mechanism, this hook does not fire.
