# Auto-Format on Save

> Runs Prettier (JS/TS/CSS/HTML/JSON) or Black (Python) automatically after Claude writes or edits a file. Your codebase stays formatted without asking Claude to do it.

**Category:** Productivity
**Event:** PostToolUse
**Matcher:** Write, Edit
**Difficulty:** Intermediate
**Platform:** PowerShell (Windows) | Bash alternative included

## The Problem

Claude generates code that is usually well-formatted, but not always consistent with your project's Prettier or Black configuration. You end up running the formatter manually after every session, or worse, committing code that fails your CI format check.

This hook runs the appropriate formatter immediately after every file write or edit. The formatting happens silently in the background.

## How It Works

1. Claude calls Write or Edit to modify a file
2. The PostToolUse hook fires after the modification
3. The script reads the stdin JSON and extracts `tool_input.file_path`
4. It checks the file extension and runs the matching formatter:
   - `.js`, `.jsx`, `.ts`, `.tsx`, `.css`, `.json`, `.html` -- runs `npx prettier --write`
   - `.py` -- runs `black --quiet`
5. If the formatter is not installed, the step is silently skipped
6. Exits with code 0

## Installation

### Prerequisites

Install the formatters you want to use:

```bash
# For JavaScript/TypeScript/CSS/HTML/JSON
npm install --save-dev prettier

# For Python
pip install black
```

The hook checks whether each formatter is available before running it. If Prettier is not installed, JS files are skipped. If Black is not installed, Python files are skipped. No errors either way.

### Step 1: Copy the script

Copy `hook.ps1` to your hooks directory:

```
~/.claude/hooks/auto-format-on-save.ps1
```

### Step 2: Add to settings.json

Open `~/.claude/settings.json` and add the hook configuration. If you already have a `hooks` section, merge the `PostToolUse` entry into it.

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "powershell -NoProfile -ExecutionPolicy Bypass -File C:/Users/YOUR_USERNAME/.claude/hooks/auto-format-on-save.ps1",
            "timeout": 15,
            "async": true
          }
        ]
      }
    ]
  }
}
```

Replace `YOUR_USERNAME` with your actual Windows username.

The timeout is set to 15 seconds because `npx prettier` can take a few seconds on first run (downloading the package). Subsequent runs are faster.

**Linux/macOS:** Use `hook.sh` instead:

```json
{
  "type": "command",
  "command": "bash ~/.claude/hooks/auto-format-on-save.sh",
  "timeout": 15,
  "async": true
}
```

### Step 3: Restart Claude Code

Close and reopen Claude Code (or start a new session) for the hook to take effect.

## Verify It Works

Ask Claude:

> "Create a file called test-format.js with the content `const x={a:1,b:2,c:3}`"

After the file is created, open it. If Prettier is installed, the content should be formatted according to your Prettier config (or Prettier defaults if no config exists).

## The Formatter Feedback Loop

This is the most important caveat of this hook.

The formatter modifies the file after Claude writes it. The next time Claude reads that file (via Read or Edit), it sees the formatted version, not what it originally wrote. If the formatting changed something Claude considers significant -- like line breaks in a specific position, or quote style -- Claude may try to "fix" it back to its original style. The formatter then reformats it again. This creates an edit loop.

In practice, this is rare. Claude's output is usually close enough to Prettier/Black defaults that formatting changes are cosmetic (trailing commas, semicolons, quote style). But it can happen, especially with:

- Projects that have unusual Prettier configs (e.g., `printWidth: 40`)
- Python code where Black reformats long function signatures
- JSON files where Prettier changes indentation from 4 to 2 spaces

**Workaround:** Only use this hook on projects where you always want formatting applied. If you are working on a project with no formatter config, or where format-on-save would be disruptive, disable the hook for that project by removing it from the project-level settings.

## Configuration

**Adding formatters:** Edit the `switch` block (PowerShell) or `case` block (bash) to add more formatters. For example, to add `rustfmt` for Rust files:

PowerShell:
```powershell
{ $_ -in ".rs" } {
    $rustfmt = Get-Command rustfmt -ErrorAction SilentlyContinue
    if ($rustfmt) { & rustfmt $filePath 2>$null }
}
```

Bash:
```bash
rs) command -v rustfmt &>/dev/null && rustfmt "$FILE_PATH" 2>/dev/null ;;
```

**Removing formatters:** Delete the corresponding `switch`/`case` entry for file extensions you do not want formatted.

## Limitations

- **Formatter must be installed.** The hook does not install formatters for you. If `npx` or `black` is not on PATH, the corresponding files are silently skipped.
- **npx cold start.** The first `npx prettier` call in a session may take 2-5 seconds if the package needs to be resolved. The 15-second timeout accommodates this, and `async: true` prevents it from blocking Claude.
- **No .editorconfig or per-directory config awareness.** The hook runs the formatter from the hook's working directory, not the file's directory. Prettier resolves its config relative to the file path (which works), but tools that depend on the current directory may behave differently.
- **Does not format on Read.** Only Write and Edit trigger the hook. If Claude reads an unformatted file, it sees it as-is.
