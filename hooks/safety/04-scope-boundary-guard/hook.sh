#!/usr/bin/env bash
# hook.sh — Scope Boundary Guard
# Event: PreToolUse | Matcher: Write, Edit
# Exit 0 = allow, Exit 2 = block (stderr shown to Claude)

set -euo pipefail

INPUT=$(cat)

RESULT=$(echo "$INPUT" | python3 -c "
import sys, json, os

d = json.load(sys.stdin)
cwd = d.get('cwd', '')
tool_name = d.get('tool_name', '')
target = ''

if tool_name in ('Write', 'Edit'):
    target = d.get('tool_input', {}).get('file_path', '')

if not cwd or not target:
    print('ALLOW')
    sys.exit(0)

resolved_target = os.path.realpath(target)
resolved_cwd = os.path.realpath(cwd)

# Ensure cwd ends with separator for prefix check
if not resolved_cwd.endswith(os.sep):
    resolved_cwd += os.sep

if resolved_target.startswith(resolved_cwd) or resolved_target == resolved_cwd.rstrip(os.sep):
    print('ALLOW')
else:
    print('BLOCK')
    print(resolved_target)
    print(resolved_cwd.rstrip(os.sep))
" 2>/dev/null || echo "ALLOW")

STATUS=$(echo "$RESULT" | head -1)

if [ "$STATUS" = "BLOCK" ]; then
    TARGET_PATH=$(echo "$RESULT" | sed -n '2p')
    PROJECT_PATH=$(echo "$RESULT" | sed -n '3p')
    echo "BLOCKED: Operation targets a file outside your project." >&2
    echo "  Target: $TARGET_PATH" >&2
    echo "  Project: $PROJECT_PATH" >&2
    echo "If intentional, run it manually or use additionalDirectories in settings." >&2
    exit 2
fi

exit 0
