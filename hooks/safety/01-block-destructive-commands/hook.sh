#!/usr/bin/env bash
# hook.sh — Block Destructive Commands
# Event: PreToolUse | Matcher: Bash
# Exit 0 = allow, Exit 2 = block (stderr shown to Claude)

set -euo pipefail

INPUT=$(cat)

COMMAND=$(echo "$INPUT" | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(d.get('tool_input', {}).get('command', ''))
" 2>/dev/null || echo "")

if [ -z "$COMMAND" ]; then
    exit 0
fi

# Each entry: pattern|consequence
PATTERNS=(
    'rm\s+-rf\b|recursively delete files and directories'
    'rm\s+-r\b|recursively delete files and directories'
    'rm\s+.*\*|delete files matching a wildcard pattern'
    'del\s+/s\s+/q\b|silently delete files recursively'
    'rd\s+/s\s+/q\b|silently remove directories recursively'
    'rmdir\s+/s\s+/q\b|silently remove directories recursively'
    'git\s+reset\s+--hard|discard all uncommitted changes permanently'
    'git\s+checkout\s+\.|discard all unstaged changes in the working directory'
    'git\s+clean\s+-[fd]|delete untracked files and directories'
    'format\s+[a-zA-Z]:|format a disk drive'
)

for entry in "${PATTERNS[@]}"; do
    PATTERN="${entry%%|*}"
    CONSEQUENCE="${entry#*|}"

    if echo "$COMMAND" | grep -qP "$PATTERN"; then
        echo "BLOCKED: $COMMAND" >&2
        echo "This would $CONSEQUENCE." >&2
        echo "If intentional, run it manually in your terminal." >&2
        exit 2
    fi
done

exit 0
