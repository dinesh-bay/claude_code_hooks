#!/usr/bin/env bash
INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('tool_input',{}).get('file_path',''))" 2>/dev/null || echo "")
if [ -n "$FILE_PATH" ]; then
    echo -n "$FILE_PATH" | pbcopy 2>/dev/null || echo -n "$FILE_PATH" | xclip -selection clipboard 2>/dev/null || true
fi
