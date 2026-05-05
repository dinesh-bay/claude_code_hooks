#!/usr/bin/env bash
# hook.sh — Context Saver
# Event: PostToolUse | Matcher: none
# Exit 0 = success (observe only)

set -euo pipefail

INPUT=$(cat)
TRANSCRIPT_PATH=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('transcript_path',''))" 2>/dev/null || echo "")
SESSION_ID=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('session_id','unknown')[:8])" 2>/dev/null || echo "unknown")
CWD=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('cwd',''))" 2>/dev/null || echo "")

if [ -z "$TRANSCRIPT_PATH" ] || [ ! -f "$TRANSCRIPT_PATH" ]; then exit 0; fi

# Configuration
THRESHOLD_PERCENT=70
ESTIMATED_FULL_SIZE_MB=3
THRESHOLD_BYTES=$(( THRESHOLD_PERCENT * ESTIMATED_FULL_SIZE_MB * 1024 * 1024 / 100 ))

# Check file size
FILE_SIZE=$(stat -f%z "$TRANSCRIPT_PATH" 2>/dev/null || stat -c%s "$TRANSCRIPT_PATH" 2>/dev/null || echo "0")
if [ "$FILE_SIZE" -lt "$THRESHOLD_BYTES" ]; then exit 0; fi

# One notification per session
FLAG_FILE="/tmp/.claude-context-saved-${SESSION_ID}.flag"
if [ -f "$FLAG_FILE" ]; then exit 0; fi

# Estimate context percentage
CONTEXT_PERCENT=$(( FILE_SIZE * 100 / (ESTIMATED_FULL_SIZE_MB * 1024 * 1024) ))
if [ "$CONTEXT_PERCENT" -gt 100 ]; then CONTEXT_PERCENT=99; fi

DIR_NAME=$(basename "$CWD" 2>/dev/null || echo "unknown")
TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")
DATE_PREFIX=$(date "+%Y-%m-%d_%H-%M")

SAVE_DIR="$HOME/.claude/saved-conversations"
mkdir -p "$SAVE_DIR"
SAVE_FILE="$SAVE_DIR/${DATE_PREFIX}_${DIR_NAME}.md"

# Extract topics and files, build summary using python3
python3 -c "
import json, os, sys
from collections import OrderedDict

transcript_path = sys.argv[1]
cwd = sys.argv[2]
context_pct = int(sys.argv[3])
timestamp = sys.argv[4]
short_id = sys.argv[5]
save_file = sys.argv[6]

topics = OrderedDict()
files_touched = []

with open(transcript_path, 'r', encoding='utf-8') as f:
    for line in f:
        try:
            entry = json.loads(line.strip())
            tool = entry.get('tool_name', '')
            if tool:
                topics[tool] = True
            fp = (entry.get('tool_input') or {}).get('file_path', '')
            if fp:
                ext = os.path.splitext(fp)[1]
                if ext:
                    topics[ext] = True
                parent = os.path.basename(os.path.dirname(fp))
                if parent and parent != '.':
                    topics[parent] = True
                resp_type = (entry.get('tool_response') or {}).get('type', 'modified')
                action = 'Created' if resp_type == 'create' else 'Modified'
                rel = fp.replace(cwd, '').lstrip('/\\\\') if cwd else fp
                files_touched.append((action, rel))
        except Exception:
            pass

seen = set()
unique_files = []
for a, f in files_touched:
    if f not in seen:
        seen.add(f)
        unique_files.append((a, f))

topic_str = ' '.join(f'\`{t}\`' for t in list(topics.keys())[:8])
files_table = ''.join(f'| {a} | \`{f}\` |\n' for a, f in unique_files[:15])

with open(transcript_path, 'r', encoding='utf-8') as f:
    transcript = f.read()

summary = f'''# Session Summary

| Field | Value |
|-------|-------|
| Date | {timestamp} |
| CWD | \`{cwd}\` |
| Session | \`{short_id}\` |
| Context | ~{context_pct}% used |

## Topics

{topic_str}

## Files Touched

| Action | File |
|--------|------|
{files_table}
---

<details>
<summary>Full Transcript (click to expand)</summary>

\`\`\`
{transcript}
\`\`\`

</details>
'''

with open(save_file, 'w', encoding='utf-8') as f:
    f.write(summary)
" "$TRANSCRIPT_PATH" "$CWD" "$CONTEXT_PERCENT" "$TIMESTAMP" "$SESSION_ID" "$SAVE_FILE" 2>/dev/null

# Create flag file
touch "$FLAG_FILE"

# Notification (macOS → Linux fallback)
osascript -e "display notification \"Context at ~${CONTEXT_PERCENT}%. Conversation saved.\" with title \"Claude Code - Context Saver\"" 2>/dev/null || \
notify-send "Claude Code - Context Saver" "Context at ~${CONTEXT_PERCENT}%. Conversation saved." 2>/dev/null || true

exit 0
