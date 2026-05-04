#!/usr/bin/env bash
BACKUP_DIR="$HOME/.claude/backups"
mkdir -p "$BACKUP_DIR"
TRANSCRIPT=$(find "$HOME/.claude/projects" -name "*.jsonl" -type f -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2-)
if [ -n "$TRANSCRIPT" ]; then
    TIMESTAMP=$(date "+%Y-%m-%d_%H-%M-%S")
    cp "$TRANSCRIPT" "$BACKUP_DIR/manual-backup-$TIMESTAMP.jsonl"
    echo "Backed up to: $BACKUP_DIR/manual-backup-$TIMESTAMP.jsonl"
else
    echo "No transcript files found."
fi
