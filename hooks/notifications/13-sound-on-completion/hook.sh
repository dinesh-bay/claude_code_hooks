#!/usr/bin/env bash
# hook.sh — Sound on Completion
# Event: Notification | Matcher: none
# Exit 0 = success

afplay /System/Library/Sounds/Glass.aiff 2>/dev/null || paplay /usr/share/sounds/freedesktop/stereo/complete.oga 2>/dev/null || echo -e '\a'
