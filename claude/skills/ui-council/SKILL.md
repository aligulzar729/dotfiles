---
name: ui-council
description: UI/UX council. The main Opus session is the orchestrator and big judge; fresh Opus subagents judge each page in a real browser, Sonnet workers fix, the orchestrator fixes, and rounds repeat until every page scores at least 9.5 for UI and for UX. Trigger when the user says "ui council", "design council", or "council" about pages or screens, or asks to score pages and keep fixing until they reach a target score. "ui council resume" continues a saved run.
---

# UI council

Adapted from the `council` skill in t3dotgg/tstack. Differences: the judges
are Claude Opus, the panel judges pages instead of a diff, and the loop does not
end until every page passes.

## Roles

- **Orchestrator and big judge**: this session. It must run on the latest Opus.
  If it does not, tell the user to run `/model opus` and stop. The orchestrator
  plans rounds, merges findings, rejects scope creep, makes or assigns fixes,
  and confirms each pass.
- **Judges**: subagents with `model: "opus"`, `effort: "medium"` and
  `subagent_type: "general-purpose"`. Start each description with
  `judge (user asked):` so the `agent-gate` hook lets it through. Judge one
  page at a time. Judges are read-only for the project: no edits, no commits.
  They may only write screenshots and scripts to the run's scratch folder.
- **Fixers** (optional): `worker` subagents with `model: "sonnet"`, given a
  written fix spec with exact files. Use them only when a round has 3 or more
  fix sets with no shared files. Otherwise fix in this session. Fixers never
  commit or push.
- **Checks and searches**: subagents with `model: "haiku"` (`Explore` or
  `log-reader`).

Invoking this skill is the user's explicit request for more than 3 subagents,
so add `(user asked)` to every description.

## Inputs

1. Pages: if the request does not name the pages, ask first with
   AskUserQuestion: "Which pages should the council judge?" Give the options
   "All pages and routes" (first) and "Only the pages I name". The user types
   the names through "Other". If the user picks "All pages and routes",
   or answers with no list, judge every page in the app:
   - Get the full route list from the framework (for example
     `php artisan route:list --method=GET --json`, the `app/` or `pages/`
     folder in Next.js, or the router config).
   - Keep every GET route that renders a page. Leave out API and JSON
     endpoints, redirects, webhooks, file downloads and health checks.
   - Each page component that a route does not reach directly (modals, tabs,
     wizard steps) becomes its own entry.
   - A route with parameters is one entry. Fill the parameters with seeded
     records.
   Write the final list in the state file and show it with its count before
   round 1. Do not ask again after the user answered.
2. For each page: URL, the account to use, and the states that matter (empty,
   filled, error, loading, owner and visitor). Use seeded test data. Never
   create or change production data.
3. Base URL and login. Make one Playwright `storageState` file for each
   account before round 1, so judges do not log in on their own.
4. Project rules: `CLAUDE.md`, `AGENTS.md`, design-system docs (for example
   `.impeccable.md`, `.ai/rules`). Judges score against these rules, not
   against personal taste.

## Before round 1

As in `council`: fix the known issues and run the project checks first, so the
council judges the current work. Then write the state file
`~/.claude/council/<repo-name>/<YYYY-MM-DD>-ui.md` with: pages, states, URLs,
auth files, the scoring rules, an empty scores table and a "Settled" list.
This file is the source of truth. A new session continues from it with
"ui council resume".

## Panel

Each page gets 3 judges in each round. Each judge has one lens, and each judge
gives both a UI score and a UX score.

1. **Visual craft**: hierarchy, typography, spacing rhythm, alignment, color
   and token use, imagery, consistency with sibling pages and the design
   system, light and dark themes.
2. **Flow and states**: can the user finish the main task fast and without
   doubt; empty, loading, error and success states; feedback after actions;
   copy; navigation in and out; form behavior and validation.
3. **Access and adaptation**: contrast, focus order and focus rings, keyboard
   use, semantics and labels, hit areas, reduced motion, mobile 390px and
   desktop 1440px, no horizontal scroll, perceived speed.

## Score scale

Scores are 0 to 10 with one decimal.

- 10: nothing to change.
- 9.5: only small points; a senior product designer would ship it today.
- 9: one real issue.
- 8: several real issues.
- 7 or lower: a broken part, or a confusing main task.

Each deduction must name its evidence (a screenshot path, or `file:line`) and
a concrete fix. A score below 9.5 must include at least one "must-fix" whose
fix would raise the score to 9.5. A deduction without evidence or without a
fix does not count.

## Judge prompt

Each round uses fresh judges, so that earlier scores do not anchor them. Do
not give them earlier scores. Fill in this template:

```
You are a <lens> judge on a UI council for <page> at <url>.
Read-only: do not edit project files, do not commit.
Project design rules: <paths>. Score against these rules only.
Settled decisions (do not deduct for these): <list from state file, or "none">.

1. Write a Playwright script in <scratch>/<round>/<page>/<lens>/ that launches
   its own Chromium. Do not use the shared Playwright MCP browser, because
   other judges use it at the same time. Use storageState <auth file>.
2. Capture: desktop 1440x900 and mobile 390x844, each in light and dark
   (colorScheme). Also capture these states: <states>. Do the main task
   once: <task>. Look at every screenshot with the Read tool.
3. Read the page component and its child components to find file:line
   evidence.
4. Reply in 300 words or fewer, in this format only:
   UI: <score>  UX: <score>
   MUST-FIX: <issue> | <evidence> | <fix>   (one line each)
   NICE: <issue> | <evidence> | <fix>       (3 lines at most)
```

Run at most 9 judges at the same time (3 pages). Start the next batch when
one finishes.

## Each round

1. **Judge**: run the panel for every page that is not passing yet.
2. **Big judge**: for each page, merge and remove duplicate findings. Reject a
   finding that adds scope, conflicts with project rules, or is false. Write
   the reason in "Settled", so the next judges do not deduct for it again.
   Add one row per page to the scores table: the lowest UI and the lowest UX
   score from the 3 judges.
3. **Fix**: fix every accepted must-fix. Stay inside the page's UI and UX: no
   new features, no new dependencies, no redesign outside the design system.
   Follow the project rules for tests, build, browser checks and code review.
   If a project rule sets a limit on its own loop (for example "stop after 3
   review rounds"), that rule wins for that loop: stop and report to the user.
4. **Re-judge**: the next round judges the failing pages, and also each passing
   page whose files changed in this round (regression check).

## Passing

A page passes when all 3 judges give UI 9.5 or more and UX 9.5 or more, and the
big judge agrees after it looks at the desktop light and mobile dark
screenshots. The big judge can block a pass, but it cannot raise a score.

When every page passes, do one final round for all pages with fresh judges. A
page that drops below 9.5 goes back into the loop.

## Do not stop

Continue rounds until every page passes. Stop only when:

- The user interrupts.
- A blocker is a product decision only the user can make. Ask one question,
  and continue the other pages while you wait.
- The usage limit is close. Update the state file with done, open and next
  step, and tell the user to start a new session with "ui council resume".
  Do not stop for the `session-limit` hook's context or prompt limits during
  a council; keep the state file current instead.

If the lowest score of a page does not go up for 2 rounds in a row, do not add
more patches. Read all its findings again, find the cause they share, and
change the approach (layout, flow or component choice). Write the new approach
in the state file.

## Fight scope creep

Judges always find more. Accept a finding only when it fixes a real problem on
the page under review. Polish suggestions that add features, a new pattern or
a style outside the design system go to "Settled" as out of scope.

## Report

At the end, show the scores table (pages by rounds, lowest UI and UX score)
and one line for each approach change. If an open PR exists, put the table in
its description under `## UI council` (edit the description, do not add a
comment). Write `no score` when a judge gave no score. Never invent one.
