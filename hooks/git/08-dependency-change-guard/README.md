# Dependency Change Guard

> Blocks modifications to package.json, requirements.txt, lock files, and other dependency manifests until you review the change.

**Category:** Git
**Event:** PreToolUse
**Matcher:** Write, Edit
**Difficulty:** Starter
**Platform:** PowerShell (Windows) | Bash alternative included

## The Problem

Claude sometimes adds, removes, or upgrades dependencies as part of a task you asked for. A quick "I'll add lodash for this utility function" turns into a new dependency in your bundle. An "I'll fix the type error" edits `package-lock.json` directly. These changes can break builds, introduce supply chain risk, or bloat your project -- and they are easy to miss in a stream of file edits.

This hook pauses Claude before any write or edit to a dependency file so you can review the change first.

## What It Guards

| File | Ecosystem |
|------|-----------|
| `package.json` | Node.js / npm |
| `package-lock.json` | Node.js / npm |
| `requirements.txt` | Python / pip |
| `Pipfile` | Python / pipenv |
| `Pipfile.lock` | Python / pipenv |
| `Gemfile` | Ruby / Bundler |
| `Gemfile.lock` | Ruby / Bundler |
| `go.mod` | Go |
| `go.sum` | Go |
| `pom.xml` | Java / Maven |
| `build.gradle` | Java / Gradle |
| `Cargo.toml` | Rust / Cargo |
| `Cargo.lock` | Rust / Cargo |

## How It Works

1. Claude calls the Write or Edit tool to modify a file
2. The PreToolUse hook fires before the file is written
3. The script reads the stdin JSON and extracts `tool_input.file_path`
4. It extracts the filename and checks it against the dependency file list
5. **Match found:** exits with code 2 (block) and writes a caution message to stderr
6. **No match:** exits with code 0, Claude writes the file normally

## Installation

### Step 1: Copy the script

Copy `hook.ps1` to your hooks directory:

```
~/.claude/hooks/dependency-change-guard.ps1
```

### Step 2: Add to settings.json

Open `~/.claude/settings.json` and add the hook configuration. If you already have a `hooks` section, merge the `PreToolUse` entries into it. You need two matcher entries -- one for Write and one for Edit -- both pointing to the same script.

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Write",
        "hooks": [
          {
            "type": "command",
            "command": "powershell -NoProfile -ExecutionPolicy Bypass -File C:/Users/YOUR_USERNAME/.claude/hooks/dependency-change-guard.ps1",
            "timeout": 5
          }
        ]
      },
      {
        "matcher": "Edit",
        "hooks": [
          {
            "type": "command",
            "command": "powershell -NoProfile -ExecutionPolicy Bypass -File C:/Users/YOUR_USERNAME/.claude/hooks/dependency-change-guard.ps1",
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
  "command": "bash ~/.claude/hooks/dependency-change-guard.sh",
  "timeout": 5
}
```

### Step 3: Restart Claude Code

Close and reopen Claude Code (or start a new session) for the hook to take effect.

## Verify It Works

Ask Claude:

> "Add axios to package.json"

You should see a block message:

```
CAUTION: Modifying dependency file: package.json
Dependency changes can break builds, introduce vulnerabilities, or change behavior.
Review the changes carefully before allowing.
```

Claude will pause and explain what it was trying to change, giving you a chance to approve or reject.

## Configuration

To add more dependency files, edit the `$dependencyFiles` array in the script:

```powershell
$dependencyFiles = @(
    'package.json', 'package-lock.json',
    'yarn.lock',  # add yarn lock file
    'pnpm-lock.yaml',  # add pnpm lock file
    # ... existing entries
)
```

## Limitations

- **Filename-only matching.** The hook checks the filename, not the full path. A file named `package.json` in any directory will trigger the guard, including test fixtures or example directories.
- **Bash commands are not caught.** If Claude runs `npm install lodash` through the Bash tool instead of editing `package.json` directly, this hook will not fire. Consider pairing with Hook #1 (Block Destructive Commands) or adding Bash-level npm/pip guards.
- **Lock files are noisy.** Lock file edits are almost always auto-generated. You may want to remove lock files from the list if the false positive rate is too high.
- **The block is absolute.** There is no "warn and continue" mode -- Claude must stop and explain. If you want advisory-only behavior, change `exit 2` to `exit 0` and the message will appear in Claude's context without blocking.
