# hook.ps1 — Mass Change Detector
# Event: PostToolUse | Matcher: Write, Edit
# Exit 0 always (PostToolUse observes, does not block)

$raw = [Console]::In.ReadToEnd()
$json = $raw | ConvertFrom-Json
$filePath = $json.tool_input.file_path
$sessionId = $json.session_id

if (-not $filePath -or -not $sessionId) { exit 0 }

$THRESHOLD = 8
$shortId = $sessionId.Substring(0, 8)
$trackingFile = Join-Path $env:TEMP ".claude-hook-session-$shortId.txt"

Add-Content -Path $trackingFile -Value $filePath

$uniqueFiles = Get-Content $trackingFile | Sort-Object -Unique
$count = $uniqueFiles.Count

if ($count -ge $THRESHOLD) {
    [Console]::Error.WriteLine("WARNING: Claude has modified $count files this session.")
    [Console]::Error.WriteLine("Modified files:")
    $uniqueFiles | ForEach-Object { [Console]::Error.WriteLine("  $_") }
    [Console]::Error.WriteLine("Review the changes before allowing more modifications.")
}

exit 0
