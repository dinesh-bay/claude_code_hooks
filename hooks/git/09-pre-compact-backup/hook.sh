#!/usr/bin/env bash
# hook.sh — Pre-Compact Backup
# Event: PreCompact | No matcher
# Exit 0 = allow (always allow compaction to proceed)

set -euo pipefail

INPUT=$(cat)

TRANSCRIPT_PATH=$(echo "$INPUT" | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(d.get('transcript_path', ''))
" 2>/dev/null || echo "")

if [ -z "$TRANSCRIPT_PATH" ]; then
    exit 0
fi

if [ ! -f "$TRANSCRIPT_PATH" ]; then
    exit 0
fi

BACKUP_DIR="$HOME/.claude/backups"
mkdir -p "$BACKUP_DIR"

TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
BACKUP_FILE="$BACKUP_DIR/transcript-$TIMESTAMP.jsonl"

cp "$TRANSCRIPT_PATH" "$BACKUP_FILE"

echo "Transcript backed up to: $BACKUP_FILE" >&2
exit 0
