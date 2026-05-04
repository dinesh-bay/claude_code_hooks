#!/usr/bin/env bash
BRANCH=$(git branch --show-current 2>/dev/null)
COMMITS=$(git log --oneline -5 2>/dev/null)
TODOS=$(grep -r --include="*.py" --include="*.ts" --include="*.js" -c "TODO\|FIXME\|HACK" . 2>/dev/null | awk -F: '{s+=$2} END {print s+0}')

[ -n "$BRANCH" ] && echo "Current branch: $BRANCH"
[ -n "$COMMITS" ] && printf "Recent commits:\n%s\n" "$COMMITS"
[ "$TODOS" -gt 0 ] 2>/dev/null && echo "TODO/FIXME/HACK count: $TODOS"
exit 0
