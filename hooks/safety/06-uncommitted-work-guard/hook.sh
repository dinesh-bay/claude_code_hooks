#!/usr/bin/env bash
# hook.sh — Uncommitted Work Guard
# Event: PreToolUse | Matcher: Bash
# Exit 0 = allow, Exit 2 = block (stderr shown to Claude)

set -euo pipefail

INPUT=$(cat)

COMMAND=$(echo "$INPUT" | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(d.get('tool_input', {}).get('command', ''))
" 2>/dev/null || echo "")

CWD=$(echo "$INPUT" | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(d.get('cwd', ''))
" 2>/dev/null || echo "")

if [ -z "$COMMAND" ]; then
    exit 0
fi

# Check if the command matches any destructive git pattern
IS_DESTRUCTIVE=false

DANGEROUS_PATTERNS=(
    'git\s+reset\s+--hard'
    'git\s+checkout\s+[a-zA-Z]'
    'git\s+stash\s+drop'
    'git\s+stash\s+clear'
    'git\s+restore\s+\.'
)

for pattern in "${DANGEROUS_PATTERNS[@]}"; do
    if echo "$COMMAND" | grep -qP "$pattern"; then
        IS_DESTRUCTIVE=true
        break
    fi
done

if [ "$IS_DESTRUCTIVE" = false ]; then
    exit 0
fi

# Check for uncommitted changes
GIT_STATUS=""
if [ -n "$CWD" ]; then
    GIT_STATUS=$(git -C "$CWD" status --porcelain 2>/dev/null || echo "")
else
    GIT_STATUS=$(git status --porcelain 2>/dev/null || echo "")
fi

if [ -n "$GIT_STATUS" ]; then
    FILE_COUNT=$(echo "$GIT_STATUS" | grep -c '.' || echo "0")
    echo "BLOCKED: $COMMAND" >&2
    echo "You have $FILE_COUNT uncommitted file(s):" >&2
    echo "$GIT_STATUS" | head -10 | while IFS= read -r line; do
        echo "  $line" >&2
    done
    if [ "$FILE_COUNT" -gt 10 ]; then
        REMAINING=$((FILE_COUNT - 10))
        echo "  ... and $REMAINING more" >&2
    fi
    echo "Commit or stash your changes first." >&2
    exit 2
fi

exit 0
