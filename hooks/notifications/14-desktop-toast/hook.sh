#!/usr/bin/env bash
# hook.sh — Desktop Toast
# Event: Notification | Matcher: none
# Exit 0 = success

INPUT=$(cat)
MSG=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('message','Claude Code needs your attention'))" 2>/dev/null || echo "Claude Code")
osascript -e "display notification \"$MSG\" with title \"Claude Code\"" 2>/dev/null || notify-send "Claude Code" "$MSG" 2>/dev/null || true
