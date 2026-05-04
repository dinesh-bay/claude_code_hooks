# hook.ps1 — Uncommitted Work Guard
# Event: PreToolUse | Matcher: Bash
# Exit 0 = allow, Exit 2 = block (stderr shown to Claude)

$raw = [Console]::In.ReadToEnd()
$json = $raw | ConvertFrom-Json
$command = $json.tool_input.command
$cwd = $json.cwd

if (-not $command) { exit 0 }

$dangerousGitPatterns = @(
    'git\s+reset\s+--hard',
    'git\s+checkout\s+[a-zA-Z]',
    'git\s+stash\s+drop',
    'git\s+stash\s+clear',
    'git\s+restore\s+\.'
)

$isDestructiveGit = $false
foreach ($pattern in $dangerousGitPatterns) {
    if ($command -match $pattern) {
        $isDestructiveGit = $true
        break
    }
}

if (-not $isDestructiveGit) { exit 0 }

$gitStatus = ""
try {
    $gitStatus = & git -C $cwd status --porcelain 2>$null
} catch {
    exit 0
}

if ($gitStatus) {
    $lines = $gitStatus -split "`n" | Where-Object { $_ }
    $fileCount = $lines.Count
    [Console]::Error.WriteLine("BLOCKED: $command")
    [Console]::Error.WriteLine("You have $fileCount uncommitted file(s):")
    $lines | Select-Object -First 10 | ForEach-Object {
        [Console]::Error.WriteLine("  $_")
    }
    if ($fileCount -gt 10) {
        [Console]::Error.WriteLine("  ... and $($fileCount - 10) more")
    }
    [Console]::Error.WriteLine("Commit or stash your changes first.")
    exit 2
}

exit 0
