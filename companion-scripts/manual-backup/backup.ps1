param(
    [string]$TranscriptDir = (Join-Path $HOME ".claude" "projects")
)

$backupDir = Join-Path $HOME ".claude" "backups"
if (-not (Test-Path $backupDir)) {
    New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
}

$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"

$transcripts = Get-ChildItem -Path $TranscriptDir -Filter "*.jsonl" -Recurse -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1

if ($transcripts) {
    $backupFile = Join-Path $backupDir "manual-backup-$timestamp.jsonl"
    Copy-Item $transcripts.FullName $backupFile
    Write-Host "Backed up to: $backupFile"
} else {
    Write-Host "No transcript files found."
}
