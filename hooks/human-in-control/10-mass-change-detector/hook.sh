#!/usr/bin/env bash
# hook.sh — Mass Change Detector
# Event: PostToolUse | Matcher: Write, Edit
# Exit 0 always (PostToolUse observes, does not block)

set -euo pipefail

INPUT=$(cat)

FILE_PATH=$(echo "$INPUT" | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(d.get('tool_input', {}).get('file_path', ''))
" 2>/dev/null || echo "")

SESSION_ID=$(echo "$INPUT" | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(d.get('session_id', ''))
" 2>/dev/null || echo "")

if [ -z "$FILE_PATH" ] || [ -z "$SESSION_ID" ]; then
    exit 0
fi

THRESHOLD=8
SHORT_ID="${SESSION_ID:0:8}"
TRACKING_FILE="${TMPDIR:-/tmp}/.claude-hook-session-${SHORT_ID}.txt"

echo "$FILE_PATH" >> "$TRACKING_FILE"

UNIQUE_COUNT=$(sort -u "$TRACKING_FILE" | wc -l | tr -d ' ')

if [ "$UNIQUE_COUNT" -ge "$THRESHOLD" ]; then
    echo "WARNING: Claude has modified $UNIQUE_COUNT files this session." >&2
    echo "Modified files:" >&2
    sort -u "$TRACKING_FILE" | while IFS= read -r f; do
        echo "  $f" >&2
    done
    echo "Review the changes before allowing more modifications." >&2
fi

exit 0
