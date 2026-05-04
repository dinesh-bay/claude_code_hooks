#!/usr/bin/env bash
# hook.sh — Dependency Change Guard
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

FILE_NAME=$(basename "$FILE_PATH")

DEPENDENCY_FILES=(
    "package.json" "package-lock.json"
    "requirements.txt" "Pipfile" "Pipfile.lock"
    "Gemfile" "Gemfile.lock"
    "go.mod" "go.sum"
    "pom.xml" "build.gradle"
    "Cargo.toml" "Cargo.lock"
)

for dep in "${DEPENDENCY_FILES[@]}"; do
    if [ "$FILE_NAME" = "$dep" ]; then
        echo "CAUTION: Modifying dependency file: $FILE_NAME" >&2
        echo "Dependency changes can break builds, introduce vulnerabilities, or change behavior." >&2
        echo "Review the changes carefully before allowing." >&2
        exit 2
    fi
done

exit 0
