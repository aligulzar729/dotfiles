---
name: reflect
description: Weekly review of how Claude Code was used. Runs a scan of the session logs (context size, prompts, subagent models, Bash habits, corrections), finds what to change, and proposes concrete edits to CLAUDE.md, skills, hooks and memory. Use when the user says "reflect", "/reflect", or the ali-stack hook says the weekly reflect is due.
---

# Reflect

1. Run the scan. Use the number of days since the last reflect, 7 by default:

   ```bash
   python3 ~/.claude/skills/reflect/scan.py 7
   ```

2. Compare the numbers with the limits in `~/.claude/CLAUDE.md` (Usage section): 400k context, 40 prompts, one day per session, subagent model split, file-read rules.
3. Find the user's corrections from the last 7 days: `grep` the session logs in `~/.claude/projects/*/` for prompts that start with "no", "wrong", "still", "again" or "I said". Read the lines around them. Group the corrections into classes. A class counts when it happened twice.
4. For each class, propose one edit, strongest first:
   - a check in the repo (lint, type, test): use `/correct`;
   - a hook in `~/Projects/dotfiles/claude/marketplace/ali-stack/hooks`;
   - a line in a skill or in CLAUDE.md;
   - a memory, only for a preference that no rule can hold.
5. Check memory: each `MEMORY.md` under `~/.claude/projects/*/memory/` must stay under 6,000 bytes. Propose deletes for memories that a rule or the code already holds.
6. Show the numbers and the proposals as one numbered list. Ask the user which to apply. Apply only the approved ones.
7. Write the stamp so the hook stops the reminder:

   ```bash
   mkdir -p ~/.claude/state && touch ~/.claude/state/last-reflect
   ```
