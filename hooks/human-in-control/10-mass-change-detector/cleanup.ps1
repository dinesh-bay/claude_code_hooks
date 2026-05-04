# cleanup.ps1 — Session Start Cleanup for Mass Change Detector
# Event: SessionStart | Matcher: (none)
# Removes stale tracking files from previous sessions

Get-ChildItem $env:TEMP -Filter ".claude-hook-session-*.txt" -ErrorAction SilentlyContinue | Remove-Item -Force
exit 0
