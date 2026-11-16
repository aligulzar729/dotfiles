---
name: correct
description: Turns a mistake that agents repeat in a repo into a check that blocks it. Tries architecture first, then types, then a lint whose error names the fix, then a test, and prose last. Proves each check fails on a real bad example. Use for "/correct", after the user corrects the same mistake twice, or when reflect finds a repeated class.
---

# Correct

Assume every agent sees only the files it opened, copies the nearest example and takes the shortest path that compiles. Change the repo so the wrong path fails.

1. Collect the mistakes: the user's correction, rule files (CLAUDE.md, AGENTS.md, `.ai/rules`, `.cursor/rules`), recent reverts and review comments. A mistake class counts when it happened twice.
2. For each class, pick the strongest fix that works:
   1. Architecture: remove the wrong path (one entry point, delete the old API).
   2. Types: make the wrong state impossible to write.
   3. Lint: a rule in the repo's existing linter or static analyser (for example PHPStan, ESLint, oxlint, SwiftLint, detekt) or an architecture test (Pest `arch()`, ArchUnit, dependency-cruiser). Its error message names the fix in one sentence.
   4. Test: a test that fails when the mistake comes back.
   5. Prose: a rule line, only when no check can catch it.
3. Use the tools that the repo already has. Do not add a dependency without asking.
4. Prove each check: make it fail on a small bad example, then pass on the current code. Delete the bad example.
5. If the current code already breaks the new check, report it. Do not fix the app code in the same change unless the user asks.
6. Next to the rule line, add one sentence that names the check that enforces it.
7. Run the project's done checks (from its CLAUDE.md or AGENTS.md; with none, run the affected tests, the linters and the build).
