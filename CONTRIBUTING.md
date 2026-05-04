# Contributing

Contributions are welcome -- new hooks, bug fixes, documentation improvements, and platform coverage.

---

## Adding a New Hook

### 1. Fork and Clone

Fork this repository and clone it locally.

### 2. Create the Hook Folder

Each hook lives in a category folder with a numbered name:

```
hooks/<category>/<number>-<name>/
```

**Categories:** `safety`, `git`, `human-in-control`, `notifications`, `productivity`

Pick the next available number. Check the existing hooks to see what numbers are taken.

Example: if the last hook is `18-session-context-loader`, your new hook would be `19-your-hook-name`.

### 3. Add These Files

Every hook folder must contain these four files:

| File | Purpose |
|------|---------|
| `hook.ps1` | The PowerShell script (Windows) |
| `hook.sh` | The Bash script (macOS/Linux) |
| `settings-snippet.json` | The JSON to add to `settings.json` |
| `README.md` | Documentation (follow the template below) |

### 4. Follow the README Template

Your `README.md` must include these sections, in this order:

```markdown
# Hook Name

> One-line description of what the hook does.

**Category:** <category>
**Event:** <PreToolUse|PostToolUse|Notification|SessionStart|Stop|PreCompact|...>
**Matcher:** <Bash|Write|Edit|Read|(empty for all)>
**Difficulty:** <Starter|Intermediate|Advanced>
**Platform:** PowerShell (Windows) | Bash alternative included

## The Problem

What real-world problem does this hook solve? Why does someone need it?
Keep it concrete -- describe the scenario, not abstract concepts.

## What It Does

Describe the hook's behavior. If it blocks, say what it blocks and why.
If it logs or notifies, say where the output goes.

## How It Works

Step-by-step explanation of the hook's logic. Number the steps.
This should be detailed enough that someone can understand the script
without reading the code.

## Installation

### Step 1: Copy the script

Where to put the file.

### Step 2: Add to settings.json

The JSON snippet (reference settings-snippet.json).
Show both Windows (PowerShell) and macOS/Linux (Bash) versions.

### Step 3: Restart Claude Code

Note that hooks load at session start.

## Verify It Works

A specific test the user can run to confirm the hook is working.
Include the exact prompt to give Claude and the expected result.

## Configuration

Describe any configurable values in the script (patterns, paths,
thresholds) and how to change them.

## Limitations

Honest list of what the hook does NOT catch or handle.
Every hook has limitations -- document them.
```

### 5. Script Standards

**Both scripts must:**

- Read stdin JSON to get the event payload
- Exit with code 0 (allow) or 2 (block, PreToolUse only)
- Write block reasons to stderr, not stdout
- Be self-contained (no external dependencies beyond the standard OS tools)
- Work without an internet connection

**PowerShell scripts must:**

- Work with PowerShell 5.1+ (the version that ships with Windows 10/11)
- Not require additional modules (unless the hook's purpose specifically involves one)
- Parse stdin with `$input | Out-String | ConvertFrom-Json`

**Bash scripts must:**

- Use `#!/bin/bash` shebang
- Require only standard Unix tools (`jq` is acceptable as it is common)
- Be executable (`chmod +x`)

**settings-snippet.json must:**

- Be valid JSON
- Include the `"timeout"` field
- Use `YOUR_USERNAME` as the placeholder in paths
- Include both PowerShell and Bash command variants as comments or separate entries

### 6. Test Your Hook

Before submitting:

1. Test on Windows with PowerShell (required)
2. Test on macOS or Linux with Bash (recommended)
3. Verify the block/allow behavior works as documented
4. Verify the "Verify It Works" section in your README actually works
5. Verify `settings-snippet.json` is valid JSON

### 7. Submit a PR

Open a pull request with:

- A clear title: `feat: add hook #<number> -- <hook name>`
- Description of what the hook does and why it is useful
- Verification results (what you tested, on which platform)
- Any limitations or edge cases you are aware of

## Improving Existing Hooks

Bug fixes, pattern additions, documentation improvements, and platform coverage are all welcome. Follow the same PR process.

For pattern additions (e.g., adding a new destructive command to the blocklist), explain what the pattern catches and provide a test case.

## Documentation

If you improve the docs in the `docs/` folder, INSTALL.md, or README.md:

- Keep the tone practical and direct
- Use real examples where possible
- Do not add emojis
- Link between documents where relevant

## Commit Message Format

Follow the existing style:

```
feat: add hook #<number> -- <hook name>
fix: correct regex pattern in block-destructive-commands
docs: update troubleshooting guide with new scenario
```

Prefix with `feat:` for new hooks, `fix:` for bug fixes, `docs:` for documentation changes.

---

## Questions?

Open an issue if you are not sure whether a hook idea fits the catalog, or if you need guidance on implementation.
