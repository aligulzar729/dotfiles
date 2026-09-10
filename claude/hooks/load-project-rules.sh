#!/usr/bin/env bash
# Injects .ai/rules/index.md at session start so the agent never needs to be told to read it.
set -euo pipefail
dir="${CLAUDE_PROJECT_DIR:-$PWD}"
index="$dir/.ai/rules/index.md"
[ -f "$index" ] || exit 0
body=$(printf 'PROJECT RULES ARE MANDATORY. This index is already loaded, so do not claim you have to go find it.\nBefore you create or edit any file, read every rule file whose glob covers that path, and follow it.\n\n%s' "$(cat "$index")")
python3 -c '
import json,sys
print(json.dumps({"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":sys.stdin.read()}}))
' <<< "$body"
