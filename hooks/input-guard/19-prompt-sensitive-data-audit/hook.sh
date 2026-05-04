#!/usr/bin/env bash
# hook.sh — Prompt Sensitive Data Audit
# Event: UserPromptSubmit | Matcher: none
# Exit 0 = allow, Exit 2 = block (stderr shown to user)

set -euo pipefail

INPUT=$(cat)

# Extract the prompt text — try multiple possible fields
PROMPT=$(echo "$INPUT" | python3 -c "
import sys, json
d = json.load(sys.stdin)
# Try common field locations for UserPromptSubmit
p = ''
ti = d.get('tool_input', {})
if isinstance(ti, dict):
    p = ti.get('prompt', '')
if not p:
    p = d.get('message', '')
if not p:
    p = d.get('content', '')
print(p)
" 2>/dev/null || echo "")

if [ -z "$PROMPT" ]; then
    exit 0
fi

# Check each pattern using python3 for reliable cross-platform regex
MATCH=$(echo "$INPUT" | python3 -c "
import sys, json, re

d = json.load(sys.stdin)
ti = d.get('tool_input', {})
p = ''
if isinstance(ti, dict):
    p = ti.get('prompt', '')
if not p:
    p = d.get('message', '')
if not p:
    p = d.get('content', '')

if not p:
    sys.exit(0)

patterns = [
    ('AWS Access Key',    r'AKIA[0-9A-Z]{16}'),
    ('Private Key',       r'-----BEGIN\s+(RSA|DSA|EC|OPENSSH)?\s*PRIVATE KEY-----'),
    ('GitHub Token',      r'ghp_[A-Za-z0-9_]{36}'),
    ('Slack Token',       r'xox[bprs]-[A-Za-z0-9\-]+'),
    ('OpenAI API Key',    r'sk-[A-Za-z0-9]{20,}'),
    ('Connection String', r'(?i)(server|data source)=[^;]+;.*(password|pwd)=[^;]+'),
    ('Bearer Token',      r'(?i)bearer\s+[A-Za-z0-9_\-\.]{20,}'),
]

for name, pattern in patterns:
    if re.search(pattern, p):
        print(name)
        sys.exit(0)

print('')
" 2>/dev/null || echo "")

if [ -n "$MATCH" ]; then
    echo "WARNING: Your message may contain a $MATCH." >&2
    echo "Sensitive data sent to Claude becomes part of the conversation." >&2
    echo "Consider removing it and using environment variables or CONFIG references instead." >&2
    exit 2
fi

exit 0
