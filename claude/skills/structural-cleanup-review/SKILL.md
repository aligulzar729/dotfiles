---
name: structural-cleanup-review
description: 'Review recently written or changed code for a better data structure or organizing model that removes accidental complexity, illegal states, duplicated rules, scattered branching, or lifecycle and ordering risk. Weighs candidates like a state machine (vs scattered booleans or phases), a typed object (vs loose params and repeated shape assumptions), a map, registry, lookup, or discriminated union (vs branching spread across files), a reducer or command/event model, a module boundary, or a queue, cache, index, graph or tree, or normalized collection, without forcing one. Returns a verdict: implement (clear, low-risk, in scope), recommend (larger or speculative), or skip (already clear). Use whenever the user finishes a coding spike or feature and wants it reviewed for cleanup, refactoring, simplification, or accidental complexity, or asks is there a better data structure here, should these flags be a state machine, can this branching become a lookup, or clean this up before we extend it.'
---

# Structural Cleanup Review

Review the code that was just written or changed and decide whether a better data structure or organizing model would make it simpler, safer, or easier to extend. The output is a decision: implement a small cleanup now, recommend a larger one for later, or skip because the current shape is already fine.

The whole value of this review is judgment, not enthusiasm. A reviewer who always finds an abstraction to add is useless, because most working code is fine and every abstraction charges rent on every future read. Treat "this is already clear, leave it alone" as a first-class, valuable answer.

## Step 0: Get the real code in front of you

Ground the review in the actual changes. Do not review from memory or in the abstract.

- In a repository, look at what actually changed: `git status`, `git diff` for the current branch or spike, and the list of recently modified files. Then read the touched files in full, not only the diff hunks. A data-structure smell usually lives in the surrounding code and the call sites, not on the changed lines.
- If the work is in this conversation (code generated or pasted this session), review that.

Fix the boundary of "what we just did" so the review stays scoped to it and does not wander into unrelated code.

## The stance: earn the abstraction or keep it boring

Prefer boring code when the current shape is already clear, local, and unlikely to grow. Be most skeptical of abstractions that add indirection without removing anything. Indirection is paid on every read; the payment is only justified when it buys back one of the four things below.

### The litmus test (apply before proposing anything)

A structure is worth proposing only if it removes at least one of these:

1. Branches. It collapses conditionals or switch arms that are currently duplicated or spread across files.
2. Duplicated rules. It gathers a rule that is currently restated in several places into a single owner.
3. Illegal states. It makes an invalid combination unrepresentable, so a whole class of bug can no longer be typed.
4. Lifecycle or ordering risk. It replaces fragile "must call A before B" sequencing or mirrored flags with something that enforces the order.

If a candidate only relocates code, adds a layer, or merely "feels cleaner" without removing one of those four, the verdict is skip. Feeling cleaner is not a payout.

## Signals to look for

Scan the changed code for the symptoms of accidental complexity:

- Repeated conditionals: the same `if`/`switch` on a kind, type, phase, or status appearing in more than one place, especially across files.
- Mirrored state: several booleans or flags that must be kept consistent by hand (`isLoading`, `isDone`, `hasError`), where some combinations are meaningless yet representable.
- Unclear ownership: a rule, default, or invariant that no single module owns, so callers each re-implement or re-check it.
- Invalid intermediate states: values that can briefly hold a combination the domain forbids.
- Awkward data flow: the same cluster of parameters threaded through many functions, or return shapes reconstructed at each hop.
- Fragile ordering: correctness depends on calling things in a specific sequence that nothing enforces.
- Duplicated transformations: the same reshaping, normalization, or computed field derived in multiple places.

## Candidate structures and what each earns

Match the symptom to the structure. The question behind every candidate is whether it would encode the real domain more directly than the current code, so the shape of the data mirrors the shape of the problem and an implicit rule becomes an explicit, enforced one. For each, notice the caution as much as the fit: the caution is where over-engineering hides.

- State machine. Replaces scattered booleans, phase strings, and lifecycle checks that can drift into contradictory combinations. Earns: illegal states become unrepresentable, transitions live in one place and are explicit, ordering is enforced. Caution: with two states and one transition, a boolean is clearer. Do not build a machine for on and off.

- Typed object or model. Replaces loose parameters passed together everywhere and repeated shape assumptions (the same four fields threaded through six functions, `opts.x ?? default` restated at each site). Earns: one place to define the shape, its defaults, and its invariants; fewer "did this field exist" checks; the type checker or validator catches drift. Caution: do not wrap a single value or a shape that appears in exactly one place.

- Map, registry, lookup table, or discriminated union. Replaces branching on a kind, type, or name that is duplicated across files and grows every time a case is added. Earns: adding a case becomes a data edit in one place instead of touching every switch; a discriminated union lets the type checker prove every case is handled. Caution: with two stable cases that will not grow, an `if` is clearer than a registry.

- Reducer or command/event model. Replaces ad hoc state mutations scattered across handlers where it is hard to see how state changes or to reproduce a sequence. Earns: transitions become named, centralized, and testable, and can be replayed or audited; ownership of who may change state is explicit. Caution: this is heavier machinery, justified when mutations are many, interleaved, or need history, undo, or audit. It is overkill for a couple of setters.

- Module boundary. Gathers behavior, ownership, and invariants currently smeared across files (the same validation, the same computed field, the same "keep these two things in sync"). Earns: one owner for a rule or invariant, a narrow public surface, and callers that stop duplicating logic. Caution: a boundary must hide something. Do not create one that is a passthrough.

- Queue, cache, index, graph or tree, or normalized collection. Matches the data structure to the access pattern the code already has: repeated linear scans to find by id (index or map), recomputing the same expensive result (cache), order-sensitive processing (queue), parent and child or dependency traversal faked with nested loops (tree or graph), the same entity duplicated across several arrays that must stay consistent (a normalized collection keyed by id). Earns: direct or constant-time access, one source of truth for consistency, and traversal or ordering expressed directly. Caution: for a handful of items, a linear scan is simpler and fast enough. Do not index ten rows.

## Decide the verdict

- implement when the cleanup is clear, fits the current task's scope, touches a small and well understood set of files, preserves behavior, and has checks (tests, types, build) that can confirm it. Make the change, then run the checks.
- recommend when the opportunity is real but the change is larger, crosses many files, is speculative about how the code will grow, or would pull focus from the current goal. Do not implement it. Describe the proposed shape, why it is worth doing, and what it would cost.
- skip when the current shape is already clear, local, and unlikely to grow, or when the only candidate fails the litmus test. Say so plainly.

### Assess the risk in every verdict

State, briefly: files touched; behavior affected (for a genuine cleanup this should be none); test impact (do tests exist around the touched code, and would they need changing); and whether it should wait (mid-feature, no coverage, or a teammate is mid-change in the same code). If landing the cleanup forces you to edit a test's expectations, stop: that is a sign you are changing behavior, not refactoring.

### Keep the scope minimal

Propose the smallest credible change that captures the win, and prefer a mechanical, behavior-preserving transformation. If the real fix is large, it is still fine to recommend a small first step that removes the most acute pain rather than the whole redesign.

## Validation

- For implement: run the relevant checks and report what you ran and the result. That means the tests around the touched files (or the suite), the type checker, and the linter or build. Because this is a refactor, existing tests should pass unchanged. If you had to change what a test expects, reconsider whether behavior actually moved.
- For recommend or skip: name the checks that would be needed to land the change safely, for example which test files, and whether new tests are needed first to pin the current behavior before any migration.

## Output format

Return exactly these five sections, in this order, and keep them concise. This is a decision aid, not an essay. The reader wants the call and the reason, not a tour.

**Verdict:** implement, recommend, or skip

**Opportunity:** the concrete data structure or organizing model, named specifically (for example, "a discriminated union for the three notification kinds", not "a cleaner abstraction"), or `none`

**Why:** the accidental complexity it removes and the invariants it makes clearer, pointing at concrete evidence (files, functions, the specific duplicated branches or mirrored flags)

**Scope:** the smallest credible change (files touched and the shape of the edit)

**Validation:** for implement, the checks you ran and their results; for recommend or skip, the checks that would be needed

## Examples

These calibrate the discipline. Notice that the skip case is as important as the others.

### Example 1: implement

Situation: A file upload component tracks `isUploading`, `isDone`, `hasError`, and `progress`. Several render branches test combinations like `!isUploading && !isDone && !hasError` for the idle state, and a retry path let `isDone` and `hasError` both be true at once.

**Verdict:** implement
**Opportunity:** a single `status` state machine, `idle | uploading | success | error`, replacing the three booleans.
**Why:** three booleans encode eight combinations but only four are legal. The idle check restates the same triple negation in three render branches, and `done + error` (an illegal state) is exactly the observed bug. One `status` value makes the illegal combinations unrepresentable and the transitions explicit and local.
**Scope:** one component file, about 40 lines. Replace the booleans with `status`, map each render branch to a status value, and set `status` at the three transition points. Behavior unchanged.
**Validation:** ran the component's tests (green, unchanged) and the type checker. The retry test can no longer express the old illegal state.

### Example 2: recommend

Situation: Handling for six event kinds is spread across four files, each with its own `switch (event.kind)`. A new kind was just added and required edits in all four switches; one was missed and fell through silently.

**Verdict:** recommend
**Opportunity:** a discriminated union for the event kinds plus a single handler registry (a map from kind to handler), so each scattered switch becomes one exhaustive lookup.
**Why:** the branching is duplicated across four files and grows with every kind; the missed switch is the accidental-complexity tax made concrete. A union lets the type checker prove exhaustiveness, and a registry makes "add a kind" a one-place data edit.
**Scope (smallest credible):** define the union and registry in one module and migrate the four switches to it. This touches five files and overlaps code a teammate is mid-change on, so it is larger than the current task and better done as its own change.
**Validation:** would need the existing event tests to pass unchanged, plus a new exhaustiveness check (a `never` guard or a test) to pin the guarantee before migrating.

### Example 3: skip

Situation: A settings loader reads two flags and picks one of two code paths with a single `if`/`else`. It lives in one file, about 15 lines, with no sign that more paths are coming.

**Verdict:** skip
**Opportunity:** none
**Why:** a registry or strategy map here would add indirection without removing any branch (there is one), any duplication (it appears once), any illegal state, or any ordering risk. The `if`/`else` is already the clearest expression of two stable cases. Abstracting it would cost every future reader and buy nothing.
**Scope:** none
**Validation:** none needed; leave the code as is.
