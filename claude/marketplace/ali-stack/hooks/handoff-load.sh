#!/usr/bin/env bash
set -euo pipefail
dir="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
file="$HOME/.claude/handoffs/$(printf '%s' "$dir" | tr '/.' '--').md"
[ -f "$file" ] || exit 0

# Only a handoff from the last 3 days is current; an older one is kept on disk but not loaded.
if [ -n "$(find "$file" -mmin -4320)" ]; then
  body=$(printf 'HANDOFF FROM THE PREVIOUS SESSION. Continue from it when the user asks to continue; otherwise follow the new prompt.\n\n%s' "$(cat "$file")")
  python3 -c 'import json,sys; print(json.dumps({"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":sys.stdin.read()}}))' <<< "$body"
fi
mv "$file" "$file.loaded"
