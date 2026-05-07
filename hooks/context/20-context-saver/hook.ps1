# hook.ps1 — Context Saver
# Event: PostToolUse | Matcher: none
# Exit 0 = success (observe only)

$raw = [Console]::In.ReadToEnd()
$json = $raw | ConvertFrom-Json

$transcriptPath = $json.transcript_path
$sessionId = $json.session_id
$cwd = $json.cwd

if (-not $transcriptPath -or -not (Test-Path $transcriptPath)) { exit 0 }

# Configuration
$THRESHOLD_PERCENT = 70
$ESTIMATED_FULL_SIZE_MB = 3
$thresholdBytes = ($THRESHOLD_PERCENT / 100) * $ESTIMATED_FULL_SIZE_MB * 1MB

# Check file size
$fileSize = (Get-Item $transcriptPath).Length
if ($fileSize -lt $thresholdBytes) { exit 0 }

# One notification per session
$shortId = $sessionId.Substring(0, 8)
$flagFile = Join-Path $env:TEMP ".claude-context-saved-$shortId.flag"
if (Test-Path $flagFile) { exit 0 }

# Estimate context percentage
$contextPercent = [math]::Round(($fileSize / ($ESTIMATED_FULL_SIZE_MB * 1MB)) * 100)
if ($contextPercent -gt 100) { $contextPercent = 99 }

# Parse transcript for topics and files
$topics = [ordered]@{}
$filesTouched = @()

try {
    $lines = Get-Content $transcriptPath -Encoding UTF8
    foreach ($line in $lines) {
        try {
            $entry = $line | ConvertFrom-Json -ErrorAction SilentlyContinue
            if (-not $entry) { continue }

            $toolName = $entry.tool_name
            if ($toolName) { $topics[$toolName] = $true }

            $filePath = $entry.tool_input.file_path
            if ($filePath) {
                $ext = [System.IO.Path]::GetExtension($filePath)
                if ($ext) { $topics[$ext] = $true }

                $parent = Split-Path (Split-Path $filePath -Parent) -Leaf
                if ($parent -and $parent -ne "." -and $parent -ne $cwd) {
                    $topics[$parent] = $true
                }

                $action = if ($entry.tool_response.type -eq "create") { "Created" } else { "Modified" }
                $relativePath = $filePath
                if ($cwd -and $filePath.StartsWith($cwd)) {
                    $relativePath = $filePath.Substring($cwd.Length).TrimStart('\', '/')
                }
                $filesTouched += [PSCustomObject]@{ Action = $action; File = $relativePath }
            }
        } catch { continue }
    }
} catch { }

# Deduplicate files touched
$filesTouched = $filesTouched | Sort-Object File -Unique

# Build topic keywords (top 8)
$topicKeys = @($topics.Keys | Where-Object { $_ -and $_.Length -gt 1 } | Select-Object -First 8)
$topicParts = @()
foreach ($t in $topicKeys) {
    $topicParts += ('`' + $t + '`')
}
$topicList = $topicParts -join " "

# Build files touched table
$filesTableLines = @()
foreach ($f in ($filesTouched | Select-Object -First 15)) {
    $filesTableLines += "| $($f.Action) | " + '`' + $f.File + '`' + " |"
}
$filesTable = $filesTableLines -join "`n"

# Read full transcript for the collapsible section
$transcriptContent = Get-Content $transcriptPath -Raw -Encoding UTF8

# Build summary
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$dirName = if ($cwd) { Split-Path $cwd -Leaf } else { "unknown" }

$summary = @"
# Session Summary

| Field | Value |
|-------|-------|
| Date | $timestamp |
| CWD | ``$cwd`` |
| Session | ``$shortId`` |
| Context | ~${contextPercent}% used |

## Topics

$topicList

## Files Touched

| Action | File |
|--------|------|
$filesTable

---

<details>
<summary>Full Transcript (click to expand)</summary>

``````
$transcriptContent
``````

</details>
"@

# Save to directory
$saveDir = Join-Path $HOME ".claude" "saved-conversations"
if (-not (Test-Path $saveDir)) {
    New-Item -ItemType Directory -Force -Path $saveDir | Out-Null
}

$datePrefix = Get-Date -Format "yyyy-MM-dd_HH-mm"
$saveFile = Join-Path $saveDir "${datePrefix}_${dirName}.md"
Set-Content -Path $saveFile -Value $summary -Encoding UTF8

# Create flag file
New-Item -Path $flagFile -ItemType File -Force | Out-Null

# Copy full path to clipboard
Set-Clipboard -Value $saveFile

# Windows balloon notification with full path
try {
    Add-Type -AssemblyName System.Windows.Forms
    $notify = New-Object System.Windows.Forms.NotifyIcon
    $notify.Icon = [System.Drawing.SystemIcons]::Information
    $notify.Visible = $true
    $notify.ShowBalloonTip(
        5000,
        "Claude Code - Context Saver",
        "Context at ~${contextPercent}%. Saved to:`n$saveFile`n`nPath copied to clipboard.",
        [System.Windows.Forms.ToolTipIcon]::Info
    )
    Start-Sleep -Milliseconds 500
    $notify.Dispose()
} catch { }

exit 0
