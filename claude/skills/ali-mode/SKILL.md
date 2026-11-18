---
name: ali-mode
description: Routes a task to the right playbook (feature, bug, UI, PR status, cleanup). The ali-stack SessionStart hook sends tasks here when they touch more than one file, change a shared signature, need a design choice, or are a bug with an unknown cause. Also use when the user says "ali mode".
---

# Ali mode

CLAUDE.md (global and project) and the user's request take precedence over this skill. This skill only picks the order of skills that already exist.

## First reply on a task

1. Say the goal in one sentence, and the smallest change that you expect to meet it.
2. Name the playbook that you use. If the evidence shows that the requested change is wrong, show the evidence and stop.

## Pick the playbook

| Task | Playbook |
|---|---|
| New behaviour, or a change across files | Feature |
| A bug, a failing test, or unexpected behaviour | Bug |
| A page, a component, or a style change | UI |
| "Check the PR", "get it green", review comments | PR |
| "Clean this up", or after a fix that can repeat in other files | Cleanup |

## Feature

1. If the request leaves product choices open, use `brainstorming`. Ask the open decisions in one `AskUserQuestion` batch, and explain the trade-off for each.
2. For 3 or more steps, use `writing-plans`. Put the plan in the final message before any tool call.
3. Do the steps yourself, or give each independent step to a `worker` subagent (model sonnet) with the exact files and the check to run. Use 3 subagents at most.
4. Name the data shape before you write code. Reuse code in the repo before you write new code.
5. Write a test for each behaviour change, then run the project's done checks (from its CLAUDE.md or AGENTS.md; with none, run the affected tests, the linters and the build).

## Bug

1. Use `systematic-debugging`. Reproduce the bug on the real surface first.
2. Write a regression test that fails on the old code.
3. `grep` every caller, and fix the bug once at the place that they all use.
4. After 3 failed fixes, stop. Write down the assumption that the fixes share, and test that assumption directly.
5. Run the project's done checks (from its CLAUDE.md or AGENTS.md; with none, run the affected tests, the linters and the build).

## UI

1. Use `match-existing-ui`, and read the project's design-system rules.
2. Make the change with the semantic tokens and the existing components.
3. Run the `ui-consistency` skill on the changed lines. It checks the components, tokens, CSS placement and UI copy, and fixes what it finds.
4. Check it in a real browser or simulator: desktop and phone width, in each theme that the project has. Use Playwright for scripted web checks.
5. For a score-until-it-passes request, use `ui-council`.

## PR

1. Read the CI status and the review comments with `gh`.
2. For each comment, decide: fix, dismiss with a concrete reason, or ask the user.
3. Do not push. Tell the user what is ready to push.

## Cleanup

1. Use `apply-everywhere` to find the other places with the same pattern.
2. Use `simplify` or `structural-cleanup-review` for the changed code.
3. If agents repeat the same mistake, use `/correct` to turn it into a lint, a type or a test.

## End of the task

- Say what now works and how to see it.
- If the session-limit hook fired, use `handoff`.
