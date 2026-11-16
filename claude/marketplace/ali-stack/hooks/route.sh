#!/usr/bin/env bash
set -euo pipefail

context='Use the `ali-mode` skill and follow its playbook when a task touches more than one file, changes a signature that other files call, involves a design choice, or is a bug or performance issue with an unknown cause. For a question, a one-line edit or a contained one-file change with an obvious check, work directly. CLAUDE.md and the user'"'"'s request take precedence over the skill.'

stamp="$HOME/.claude/state/last-reflect"
if [ ! -f "$stamp" ] || [ -n "$(find "$stamp" -mtime +6)" ]; then
  context="$context"$'\n\n''The weekly `/reflect` is due. Mention it once, in one line, at the end of your first reply. Do not run it unless the user asks.'
fi

python3 -c 'import json,sys; print(json.dumps({"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":sys.stdin.read()}}))' <<< "$context"
