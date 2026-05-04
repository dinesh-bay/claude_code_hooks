#!/usr/bin/env bash
# hook.sh — Dangerous Interpreter Guard
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

CHAR_THRESHOLD=80

# Each entry: regex pattern for an interpreter with inline code flag
PATTERNS=(
    'python3?\s+-c\s+'
    'node\s+-e\s+'
    'ruby\s+-e\s+'
    'perl\s+-e\s+'
    'powershell\s+-Command\s+'
)

for PATTERN in "${PATTERNS[@]}"; do
    if echo "$COMMAND" | grep -qP "$PATTERN"; then
        # Extract the inline code portion after the interpreter flag
        INLINE_CODE=$(echo "$COMMAND" | perl -pe "s/^.*?$PATTERN//")
        CODE_LENGTH=${#INLINE_CODE}

        if [ "$CODE_LENGTH" -ge "$CHAR_THRESHOLD" ]; then
            PREVIEW="${COMMAND:0:100}"
            echo "BLOCKED: Long inline script detected (${CODE_LENGTH} chars)." >&2
            echo "Command starts with: ${PREVIEW}..." >&2
            echo "Write this to a file first so it can be reviewed." >&2
            exit 2
        fi
    fi
done

exit 0
