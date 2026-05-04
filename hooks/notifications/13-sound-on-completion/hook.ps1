# hook.ps1 — Sound on Completion
# Event: Notification | Matcher: none
# Exit 0 = success

[System.Media.SystemSounds]::Exclamation.Play()
exit 0
