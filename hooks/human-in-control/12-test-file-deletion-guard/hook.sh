#!/usr/bin/env bash
# hook.sh — Test File Deletion Guard
# Event: PreToolUse | Matcher: Bash, Write
# Exit 0 = allow, Exit 2 = block (stderr shown to Claude)

set -euo pipefail

INPUT=$(cat)

TOOL_NAME=$(echo "$INPUT" | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(d.get('tool_name', ''))
" 2>/dev/null || echo "")

# Test file patterns
TEST_PATTERNS=(
    'test_.*\.py$'
    '.*\.spec\.(ts|js)$'
    '.*\.test\.(ts|js|tsx|jsx)$'
    '.*_test\.go$'
    'conftest\.py$'
    '.*\.test\.py$'
)

if [ "$TOOL_NAME" = "Bash" ]; then
    COMMAND=$(echo "$INPUT" | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(d.get('tool_input', {}).get('command', ''))
" 2>/dev/null || echo "")

    if [ -z "$COMMAND" ]; then
        exit 0
    fi

    # Check if the command contains a delete operation
    if echo "$COMMAND" | grep -qP '\b(rm|del|Remove-Item)\b'; then
        for PATTERN in "${TEST_PATTERNS[@]}"; do
            if echo "$COMMAND" | grep -qP "$PATTERN"; then
                echo "BLOCKED: Attempted to delete a test file." >&2
                echo "Command: $COMMAND" >&2
                echo "Tests are your safety net. Fix the tests, don't delete them." >&2
                exit 2
            fi
        done
    fi
fi

if [ "$TOOL_NAME" = "Write" ]; then
    FILE_PATH=$(echo "$INPUT" | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(d.get('tool_input', {}).get('file_path', ''))
" 2>/dev/null || echo "")

    if [ -z "$FILE_PATH" ]; then
        exit 0
    fi

    FILENAME=$(basename "$FILE_PATH")

    IS_TEST_FILE=false
    for PATTERN in "${TEST_PATTERNS[@]}"; do
        if echo "$FILENAME" | grep -qP "$PATTERN"; then
            IS_TEST_FILE=true
            break
        fi
    done

    if [ "$IS_TEST_FILE" = true ] && [ -f "$FILE_PATH" ]; then
        EXISTING_LINES=$(wc -l < "$FILE_PATH" | tr -d ' ')
        NEW_LINES=$(echo "$INPUT" | python3 -c "
import sys, json
d = json.load(sys.stdin)
content = d.get('tool_input', {}).get('content', '')
print(len(content.split('\n')))
" 2>/dev/null || echo "0")

        HALF=$(( EXISTING_LINES / 2 ))

        if [ "$EXISTING_LINES" -gt 10 ] && [ "$NEW_LINES" -lt "$HALF" ]; then
            echo "BLOCKED: About to overwrite test file $FILENAME ($EXISTING_LINES lines -> $NEW_LINES lines)." >&2
            echo "This would remove more than half the test content." >&2
            echo "Use Edit for targeted changes instead." >&2
            exit 2
        fi
    fi
fi

exit 0
