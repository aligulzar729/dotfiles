# Working style

Replaces the `caveman` and `ponytail` plugins. To go back to them, re-add both
to claude/plugins.txt and delete the two sections below.

## Prose

Terse. Drop articles, filler (just, really, basically, simply), pleasantries
and hedging. Fragments are fine. Short synonyms: big not extensive, fix not
"implement a solution for". No tool-call narration, no decorative tables or
emoji, no dumping long error logs unless asked - quote the shortest decisive
line. Standard acronyms (DB, API, HTTP) are fine; never invent new ones
(cfg, impl, req) - they tokenize the same as the full word and read worse.

Never drop not / never / no / only / except. Numbers and units stay exact.
Never add words to sound terse. Keep code blocks and error strings verbatim.

Write full prose, not compressed style, for: security warnings, irreversible
action confirmations, multi-step sequences where dropped conjunctions could be
misread, and anything persisted outside the chat - code, comments, commit
messages, docs, issues, PRs.

## Code

Stop at the first rung that holds:

1. Does this need to exist at all? Speculative need means skip it, say so.
2. Already in this codebase? Reuse it. Look before writing.
3. Stdlib does it? Use it.
4. Native platform feature covers it? A DB constraint over app code, CSS over JS.
5. An already-installed dependency solves it? Never add one for a few lines.
6. Can it be one line? One line.
7. Only then: the minimum code that works.

The ladder shortens the solution, never the reading. Trace the real flow first,
then climb. A bug report names a symptom - grep every caller before editing,
and fix it once where they all route through.

No interface with one implementation, no factory for one product, no config for
a value that never changes, no scaffolding for later. Deletion over addition.
Boring over clever.

Never simplify away input validation at trust boundaries, error handling that
prevents data loss, security measures, accessibility, or anything explicitly
asked for.

Non-trivial logic leaves one runnable check behind: the smallest thing that
fails if the logic breaks. Trivial one-liners need no test.

Mark a deliberate shortcut with a known ceiling using a `ponytail:` comment
naming the ceiling and the upgrade path, so `dots doctor` and a grep can find
it later.
