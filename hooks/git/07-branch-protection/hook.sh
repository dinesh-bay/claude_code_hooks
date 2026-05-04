#!/usr/bin/env bash
# hook.sh — Branch Protection
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

if echo "$COMMAND" | grep -qP 'git\s+push\s+.*--force'; then
    echo "BLOCKED: Force push is not allowed." >&2
    echo "Command: $COMMAND" >&2
    echo "Force pushing can overwrite remote history and destroy teammates' work." >&2
    exit 2
fi

if echo "$COMMAND" | grep -qP 'git\s+push\s+\S+\s+(main|master)\b'; then
    echo "BLOCKED: Direct push to main/master is not allowed." >&2
    echo "Command: $COMMAND" >&2
    echo "Create a feature branch and open a PR instead." >&2
    exit 2
fi

exit 0
