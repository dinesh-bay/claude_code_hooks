#!/usr/bin/env bash
# hook.sh — Critical File Guard
# Event: PreToolUse | Matcher: Write, Edit
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

# Normalize backslashes to forward slashes
NORMALIZED=$(echo "$FILE_PATH" | tr '\\' '/')
FILENAME=$(basename "$FILE_PATH")

PROTECTED_PATTERNS=(
    '\.env$'
    '\.env\..+$'
    'docker-compose\.ya?ml$'
    'Dockerfile$'
    '\.github/workflows/.+$'
    'Jenkinsfile$'
    'azure-pipelines\.ya?ml$'
    '\.claude/settings\.json$'
    '\.config\.(js|ts|mjs)$'
)

for pattern in "${PROTECTED_PATTERNS[@]}"; do
    if echo "$NORMALIZED" | grep -qP "$pattern"; then
        echo "BLOCKED: Modification to critical file: $FILENAME" >&2
        echo "This is a configuration/infrastructure file that should not be overwritten wholesale." >&2
        echo "Tell Claude exactly what line or value to change instead." >&2
        exit 2
    fi
done

exit 0
