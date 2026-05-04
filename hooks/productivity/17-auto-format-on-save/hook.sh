#!/usr/bin/env bash
INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('tool_input',{}).get('file_path',''))" 2>/dev/null || echo "")
if [ -z "$FILE_PATH" ]; then exit 0; fi
EXT="${FILE_PATH##*.}"
case "$EXT" in
    js|jsx|ts|tsx|css|json|html) command -v npx &>/dev/null && npx prettier --write "$FILE_PATH" 2>/dev/null ;;
    py) command -v black &>/dev/null && black --quiet "$FILE_PATH" 2>/dev/null ;;
esac
exit 0
