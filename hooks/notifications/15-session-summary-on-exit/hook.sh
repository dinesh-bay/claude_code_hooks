#!/usr/bin/env bash
# hook.sh — Session Summary on Exit
# Event: Stop | Matcher: none
# Exit 0 = success

INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('session_id','unknown')[:8])" 2>/dev/null || echo "unknown")
CWD=$(echo "$INPUT" | python3 -c "import sys,json; import os; print(os.path.basename(json.load(sys.stdin).get('cwd','unknown')))" 2>/dev/null || echo "unknown")
LOG_DIR="$HOME/.claude/session-logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/sessions.md"
if [ ! -f "$LOG_FILE" ]; then
    printf "# Session Log\n\n| Timestamp | Session | Directory |\n|-----------|---------|------|" > "$LOG_FILE"
fi
TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")
echo "| $TIMESTAMP | $SESSION_ID | $CWD |" >> "$LOG_FILE"
