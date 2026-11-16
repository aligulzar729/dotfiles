---
name: handoff
description: Write a handoff so the next session continues this work. Use when the session-limit hook says a limit is passed, when the user says "handoff", "wrap up" or "new session", or when the user changes to a different task.
---

# Handoff

1. Write the handoff to this path (the `handoff-load` SessionStart hook reads it in the next session in the same project):

   ```bash
   mkdir -p ~/.claude/handoffs && echo ~/.claude/handoffs/$(printf %s "${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}" | tr '/.' '--').md
   ```

2. Use this shape, and keep it under 40 lines:

   ```markdown
   # <task in one line>
   Date: <YYYY-MM-DD>  Branch: <branch>

   ## Done
   - <fact, with file paths>

   ## Open
   - <what is not finished or not verified, with the exact failing command or test>

   ## Next step
   <one action that the next session does first>

   ## Decisions the user made
   - <decision and the reason, only those not in code or memory>
   ```

3. Write facts only. Do not paste logs or diffs. Name files as `path:line`.
4. Tell the user: "Handoff saved. Start a new session in this project; it loads automatically."
