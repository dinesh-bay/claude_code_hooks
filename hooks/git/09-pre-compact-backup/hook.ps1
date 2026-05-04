# hook.ps1 — Pre-Compact Backup
# Event: PreCompact | No matcher
# Exit 0 = allow (always allow compaction to proceed)

$raw = [Console]::In.ReadToEnd()
$json = $raw | ConvertFrom-Json
$transcriptPath = $json.transcript_path

if (-not $transcriptPath) { exit 0 }
if (-not (Test-Path $transcriptPath)) { exit 0 }

$backupDir = Join-Path $HOME ".claude" "backups"
if (-not (Test-Path $backupDir)) {
    New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
}

$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$backupFile = Join-Path $backupDir "transcript-$timestamp.jsonl"
Copy-Item $transcriptPath $backupFile

[Console]::Error.WriteLine("Transcript backed up to: $backupFile")
exit 0
