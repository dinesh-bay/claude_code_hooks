# Scope Boundary Guard

> Blocks Claude from writing or editing files outside the current project directory, preventing accidental modifications to unrelated projects or system files.

**Category:** Safety
**Event:** PreToolUse
**Matcher:** Write, Edit
**Difficulty:** Intermediate
**Platform:** PowerShell (Windows) | Bash alternative included

## The Problem

Claude Code sets a working directory (`cwd`) when a session starts. But nothing stops Claude from writing to files anywhere on your filesystem. If Claude resolves a path incorrectly, follows a stale reference, or gets confused about project structure, it can write to files in your home directory, another project, or even system locations. You asked it to fix a bug in project A and it edited a file in project B.

This hook enforces a simple rule: file operations must target paths inside the current working directory. Anything outside is blocked.

## How It Works

1. Claude calls the Write or Edit tool targeting a file path
2. The PreToolUse hook fires before the file is modified
3. The script reads the stdin JSON and extracts `cwd` (project root) and `tool_input.file_path` (target)
4. Both paths are resolved to absolute form (handling `..`, symlinks, etc.)
5. It checks whether the resolved target starts with the resolved cwd
6. **Target is outside cwd:** exits with code 2 (block) and shows both paths
7. **Target is inside cwd:** exits with code 0, Claude writes normally

## Installation

### Step 1: Copy the script

Copy `hook.ps1` to your hooks directory:

```
~/.claude/hooks/scope-boundary-guard.ps1
```

### Step 2: Add to settings.json

Open `~/.claude/settings.json` and add the hook configuration. You need two matcher entries -- one for Write, one for Edit.

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Write",
        "hooks": [
          {
            "type": "command",
            "command": "powershell -NoProfile -ExecutionPolicy Bypass -File C:/Users/YOUR_USERNAME/.claude/hooks/scope-boundary-guard.ps1",
            "timeout": 5
          }
        ]
      },
      {
        "matcher": "Edit",
        "hooks": [
          {
            "type": "command",
            "command": "powershell -NoProfile -ExecutionPolicy Bypass -File C:/Users/YOUR_USERNAME/.claude/hooks/scope-boundary-guard.ps1",
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
  "command": "bash ~/.claude/hooks/scope-boundary-guard.sh",
  "timeout": 5
}
```

### Step 3: Restart Claude Code

Close and reopen Claude Code (or start a new session) for the hook to take effect.

## Verify It Works

From any project directory, ask Claude:

> "Create a file at C:/Users/test/outside-project.txt with the content hello"

You should see a block message:

```
BLOCKED: Operation targets a file outside your project.
  Target: C:\Users\test\outside-project.txt
  Project: C:\Users\gudinesh\your-project
If intentional, run it manually or use additionalDirectories in settings.
```

## Configuration

This hook has no configurable patterns -- it uses the `cwd` from Claude Code's own JSON payload as the boundary. The project root is whatever directory you opened Claude Code in.

If you legitimately need Claude to write to files outside the project (e.g., a shared config directory), you have two options:

1. **Claude Code's built-in mechanism:** Add the path to `additionalDirectories` in your Claude Code settings
2. **Modify the hook:** Add an allowlist of additional directories at the top of the script

```powershell
$allowedDirs = @(
    "C:\Users\gudinesh\shared-configs",
    "C:\Users\gudinesh\.config"
)

foreach ($dir in $allowedDirs) {
    $resolvedDir = [System.IO.Path]::GetFullPath($dir)
    if ($resolvedTarget.StartsWith($resolvedDir, [System.StringComparison]::OrdinalIgnoreCase)) {
        exit 0
    }
}
```

## Limitations

- **Only Write and Edit are checked.** Bash tool commands like `echo > /path/outside` are not caught by this hook. Use the Block Destructive Commands hook (hook #1) as a complement.
- **Symlinks may bypass the check.** If the project contains symlinks pointing outside the cwd, the resolved path may still start with the cwd prefix. The hook resolves both paths, but symlink chains can be complex.
- **cwd depends on how you started Claude Code.** If you opened Claude Code in your home directory, the boundary is your entire home directory -- not very protective. Open Claude Code from the specific project folder for the tightest boundary.
- **Case sensitivity.** On Windows, path comparison is case-insensitive (correct). On Linux/macOS, the bash version uses `os.path.realpath` which respects the filesystem's case sensitivity.
