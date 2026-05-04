# hook.ps1 — Branch Protection
# Event: PreToolUse | Matcher: Bash
# Exit 0 = allow, Exit 2 = block (stderr shown to Claude)

$raw = [Console]::In.ReadToEnd()
$json = $raw | ConvertFrom-Json
$command = $json.tool_input.command

if (-not $command) { exit 0 }

if ($command -match 'git\s+push\s+.*--force') {
    [Console]::Error.WriteLine("BLOCKED: Force push is not allowed.")
    [Console]::Error.WriteLine("Command: $command")
    [Console]::Error.WriteLine("Force pushing can overwrite remote history and destroy teammates' work.")
    exit 2
}

if ($command -match 'git\s+push\s+\S+\s+(main|master)\b') {
    [Console]::Error.WriteLine("BLOCKED: Direct push to main/master is not allowed.")
    [Console]::Error.WriteLine("Command: $command")
    [Console]::Error.WriteLine("Create a feature branch and open a PR instead.")
    exit 2
}

exit 0
