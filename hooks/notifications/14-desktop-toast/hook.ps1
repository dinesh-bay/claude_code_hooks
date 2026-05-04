# hook.ps1 — Desktop Toast
# Event: Notification | Matcher: none
# Exit 0 = success

$raw = [Console]::In.ReadToEnd()
$json = $raw | ConvertFrom-Json
$message = $json.message
if (-not $message) { $message = "Claude Code needs your attention" }

Add-Type -AssemblyName System.Windows.Forms
$notify = New-Object System.Windows.Forms.NotifyIcon
$notify.Icon = [System.Drawing.SystemIcons]::Information
$notify.Visible = $true
$notify.ShowBalloonTip(3000, "Claude Code", $message, [System.Windows.Forms.ToolTipIcon]::Info)
Start-Sleep -Milliseconds 500
$notify.Dispose()
exit 0
