---
name: apply-everywhere
description: Use when the user says "also consider this pattern everywhere", "apply this everywhere", "fix all of these", "same thing elsewhere", or any request to generalise a fix that was just made at one site. Also use proactively, without being asked, immediately after you fix a bug or apply a convention at one call site that plausibly repeats elsewhere in the repository.
---

# Apply Everywhere

A fix applied at one site is not finished. The same mistake almost always exists
at other sites, and the user should never have to ask twice.

## Rule

After you change one call site for a reason that is not unique to that file,
you sweep the repository for the same pattern in the same turn.

Do not ask "shall I look for others?". Look, then report.

## Procedure

1. **Name the pattern in one sentence.** State the wrong shape and the right
   shape. If you cannot state it, you do not understand the fix yet.

2. **Write a search that finds the wrong shape, not the right one.** Use `rg`
   with the narrowest expression that still catches variants. Search the whole
   repository, including tests, config, migrations and frontend code. Run two
   or three different expressions; one regex misses renamed variables and
   reordered arguments.

3. **List every hit before you edit anything.** Print the file and line for
   each. Count them.

4. **Classify each hit** as: same bug, deliberate exception, or false positive.
   Say why for every exception. An exception with no reason is a bug.

5. **Fix all the "same bug" hits in one pass.**

6. **Run the check that proves it.** The narrowest test, lint or static
   analysis command that covers the touched files. Paste the real output.

7. **Report the full list**: sites found, sites fixed, sites deliberately
   skipped and the reason, and the verification command with its output.

## Escalate the fix into a rule

If the sweep found three or more sites, the pattern will come back. Record it
so nobody repeats it:

- Repository with `.ai/rules/`: add a short entry under the matching glob, or
  use `record-rule` when Laravel Boost is available.
- Otherwise: add it to `CLAUDE.md` or `AGENTS.md`.

State in your reply that you recorded the rule, and where.

## Stop conditions

- The sweep returns more than 40 hits. Report the count and a grouped summary,
  and ask which groups to take, before you edit.
- A hit sits in vendor, build output or generated code. Never edit those; fix
  the generator instead.
- Two hits disagree about which shape is correct. Stop and ask. Do not pick.
