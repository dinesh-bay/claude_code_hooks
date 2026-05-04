#!/usr/bin/env bash
# hook.sh — Secret Scanner
# Event: PreToolUse | Matcher: Write
# Exit 0 = allow, Exit 2 = block (stderr shown to Claude)

set -euo pipefail

INPUT=$(cat)

CONTENT=$(echo "$INPUT" | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(d.get('tool_input', {}).get('content', ''))
" 2>/dev/null || echo "")

if [ -z "$CONTENT" ]; then
    exit 0
fi

# Check each pattern. Using python3 for reliable regex matching across platforms.
MATCH=$(echo "$INPUT" | python3 -c "
import sys, json, re

d = json.load(sys.stdin)
content = d.get('tool_input', {}).get('content', '')

if not content:
    sys.exit(0)

patterns = [
    ('AWS Access Key',    r'AKIA[0-9A-Z]{16}'),
    ('AWS Secret Key',    r'(?i)aws_secret_access_key\s*[:=]\s*\S+'),
    ('Private Key',       r'-----BEGIN\s+(RSA|DSA|EC|OPENSSH)?\s*PRIVATE KEY-----'),
    ('GitHub Token',      r'ghp_[A-Za-z0-9_]{36}'),
    ('Slack Token',       r'xox[bprs]-[A-Za-z0-9\-]+'),
    ('OpenAI API Key',    r'sk-[A-Za-z0-9]{20,}'),
    ('Generic API Key',   r'(?i)(api[_-]?key|apikey)\s*[:=]\s*[\"\\x27]?[A-Za-z0-9_\-]{20,}'),
    ('Generic Password',  r'(?i)(password|passwd|pwd)\s*[:=]\s*[\"\\x27]?[^\s\"]{8,}'),
    ('Generic Secret',    r'(?i)(secret|token)\s*[:=]\s*[\"\\x27]?[A-Za-z0-9_\-]{20,}'),
]

for name, pattern in patterns:
    if re.search(pattern, content):
        print(name)
        sys.exit(0)

print('')
" 2>/dev/null || echo "")

if [ -n "$MATCH" ]; then
    echo "BLOCKED: Potential $MATCH detected in file content." >&2
    echo "Review the content before allowing this write." >&2
    echo "If this is a false positive (e.g., test fixture), run it manually." >&2
    exit 2
fi

exit 0
