# hook.ps1 — Session Summary on Exit
# Event: Stop | Matcher: none
# Exit 0 = success

$raw = [Console]::In.ReadToEnd()
$json = $raw | ConvertFrom-Json
$sessionId = $json.session_id
$cwd = $json.cwd

$logDir = Join-Path $HOME ".claude" "session-logs"
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Force -Path $logDir | Out-Null
}

$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$dirName = if ($cwd) { Split-Path $cwd -Leaf } else { "unknown" }
$shortId = if ($sessionId) { $sessionId.Substring(0, 8) } else { "unknown" }

$entry = "| $timestamp | $shortId | $dirName |"
$logFile = Join-Path $logDir "sessions.md"

if (-not (Test-Path $logFile)) {
    Set-Content $logFile "# Session Log`n`n| Timestamp | Session | Directory |`n|-----------|---------|-----------|"
}

Add-Content $logFile $entry
exit 0
