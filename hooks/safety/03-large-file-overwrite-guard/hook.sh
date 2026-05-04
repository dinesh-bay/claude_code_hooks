#!/usr/bin/env bash
# hook.sh — Large File Overwrite Guard
# Event: PreToolUse | Matcher: Write
# Exit 0 = allow, Exit 2 = block (stderr shown to Claude)

set -euo pipefail

INPUT=$(cat)

FILE_PATH=$(echo "$INPUT" | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(d.get('tool_input', {}).get('file_path', ''))
" 2>/dev/null || echo "")

if [ -z "$FILE_PATH" ]; then
    exit 0
fi

THRESHOLD=300

if [ -f "$FILE_PATH" ]; then
    LINE_COUNT=$(wc -l < "$FILE_PATH" 2>/dev/null || echo "0")
    LINE_COUNT=$(echo "$LINE_COUNT" | tr -d '[:space:]')

    if [ "$LINE_COUNT" -ge "$THRESHOLD" ] 2>/dev/null; then
        FILENAME=$(basename "$FILE_PATH")
        echo "BLOCKED: About to overwrite $FILENAME ($LINE_COUNT lines)." >&2
        echo "Use the Edit tool for targeted changes instead of rewriting the entire file." >&2
        echo "If a full rewrite is truly needed, run it manually." >&2
        exit 2
    fi
fi

exit 0
