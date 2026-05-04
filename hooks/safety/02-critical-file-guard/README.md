# Critical File Guard

> Blocks Claude from writing to `.env`, CI configs, Dockerfiles, and other infrastructure files that should not be casually overwritten.

**Category:** Safety
**Event:** PreToolUse
**Matcher:** Write, Edit
**Difficulty:** Starter
**Platform:** PowerShell (Windows) | Bash alternative included

## The Problem

Certain files in a project carry outsized risk. Your `.env` file holds database credentials and API keys. Your `docker-compose.yml` controls how services are deployed. Your GitHub Actions workflow defines your CI/CD pipeline. Claude does not know which files are "critical" -- it treats every file the same and will happily overwrite your `.env` with example values, breaking your local environment.

This hook blocks modifications to a curated list of high-risk file patterns before Claude can write to them.

## What It Blocks

| Pattern | Files Matched | Why It Is Critical |
|---------|---------------|--------------------|
| `.env` | `.env` | Contains secrets, database URLs, API keys |
| `.env.*` | `.env.local`, `.env.production` | Environment-specific secrets |
| `docker-compose.yml` | `docker-compose.yml`, `docker-compose.yaml` | Defines service infrastructure |
| `Dockerfile` | `Dockerfile` | Controls container builds |
| `.github/workflows/*` | Any workflow YAML | CI/CD pipeline definitions |
| `Jenkinsfile` | `Jenkinsfile` | Jenkins pipeline config |
| `azure-pipelines.yml` | `azure-pipelines.yml` | Azure DevOps pipeline |
| `.claude/settings.json` | Claude Code settings | Hook configs, permissions |
| `*.config.js/ts/mjs` | `webpack.config.js`, `vite.config.ts`, etc. | Build tool configurations |

## How It Works

1. Claude calls the Write or Edit tool targeting a file
2. The PreToolUse hook fires before the file is modified
3. The script reads the stdin JSON and extracts `tool_input.file_path`
4. It normalizes the path (backslashes to forward slashes) and checks it against every protected pattern
5. **Match found:** exits with code 2 (block) and names the file in the stderr message
6. **No match:** exits with code 0, Claude writes the file normally

## Installation

### Step 1: Copy the script

Copy `hook.ps1` to your hooks directory:

```
~/.claude/hooks/critical-file-guard.ps1
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
            "command": "powershell -NoProfile -ExecutionPolicy Bypass -File C:/Users/YOUR_USERNAME/.claude/hooks/critical-file-guard.ps1",
            "timeout": 5
          }
        ]
      },
      {
        "matcher": "Edit",
        "hooks": [
          {
            "type": "command",
            "command": "powershell -NoProfile -ExecutionPolicy Bypass -File C:/Users/YOUR_USERNAME/.claude/hooks/critical-file-guard.ps1",
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
  "command": "bash ~/.claude/hooks/critical-file-guard.sh",
  "timeout": 5
}
```

### Step 3: Restart Claude Code

Close and reopen Claude Code (or start a new session) for the hook to take effect.

## Verify It Works

Ask Claude:

> "Add a new variable MY_TEST=123 to my .env file"

You should see a block message:

```
BLOCKED: Modification to critical file: .env
This is a configuration/infrastructure file that should not be overwritten wholesale.
Tell Claude exactly what line or value to change instead.
```

## Configuration

The protected file list is defined in the `$protectedPatterns` array at the top of the script. To protect additional files, add a regex pattern:

```powershell
'terraform\.tfvars$'
```

To remove a protection, delete or comment out the corresponding entry.

## Limitations

- **Both Write and Edit are blocked.** Even a surgical one-line Edit to `.env` is blocked. If you want to allow Edit but block Write for certain files, you would need to split this into two hooks with different pattern lists.
- **Only file path is checked.** The hook does not inspect file content. If Claude writes secrets to a file called `config.txt` instead of `.env`, this hook will not catch it. Use the Secret Scanner hook (hook #5) for content-based protection.
- **Pattern matching, not intent detection.** A file named `my.env.backup` would match the `.env.*` pattern and be blocked even though it is not a real env file.
