---
name: writing-style
description: Write or rewrite prose so it reads like a thoughtful human, not an AI or a marketing department. Use when writing or editing docs, READMEs, help articles, handbook pages, PR descriptions, issues, release notes, emails, landing or marketing copy, headings, or any markdown file, and when the user says "unslop", "rewrite this", "make this less AI", "tighten this", or pastes text to clean up. Also use when reviewing someone else's prose. For UI microcopy (buttons, errors, empty states) use better-writing instead.
---

# Writing style

Write clear, direct, specific prose. Every sentence carries information the reader did not already have. If a sentence only sets a mood, restates, or praises, delete it.

## Input

- A file path or glob: rewrite the prose in place. Only touch `.md` and other prose files, never source code.
- Pasted or inline text: return the rewritten text, write no file.
- Nothing given: apply these rules to what you are about to write.

Leave code blocks, inline code, link URLs, front matter, tables of data and the author's own terms unchanged. Do not change heading structure in someone else's document unless the heading itself breaks a rule below. Keep every fact. A rewrite changes voice, not content.

## Headings

- No eyebrow headings: no category label or kicker above a heading.
- Number sections only when order matters (steps, a sequence).
- No rhythmic or contrasting titles ("Hard to describe. Easy to recognize.").
- No metaphorical headings. Prefer the literal description over personification or imagery.
- No slogans or cliches ("Built for teams that ship", "Unlock your potential").
- No vague headings ("A closer look", "Why it matters", "The bottom line"). Say what the section contains.
- Sentence case, not Title Case.
- Write headings like email subject lines, not movie trailers.

## Sentences

Cut these on sight:

- **Summative closers.** A short line that tells the reader what to think about what they just read: "That's the real risk.", "And that changes everything.", "That's the point.", "Simple as that.", "This is the key insight." The paragraph already made the point. End on the last fact.
- **Sycophancy and inflated agreement.** "Great question", "You're absolutely right", "Your second point is even more right than you know", "This is a sharp observation". If you agree, act on it. If you add to the point, state the addition.
- **Manufactured contrast.** "Not just X, but Y", "It's not about X. It's about Y.", "X isn't the problem. Y is." Say Y.
- **Manufactured rhythm.** Lists of three where the content has two or four items. Strings of one-line paragraphs for drama. Fragments used as punchlines.
- **Throat-clearing and hedging.** "It's worth noting that", "It's important to mention", "Let's dive in", "Here's the thing", "At the end of the day".
- **Chatbot artifacts.** "I hope this helps", "Feel free to", "Don't hesitate to", "Happy to help", closing offers nobody asked for.
- **Generic conclusions** that restate the intro.
- **Restatement.** A sentence that repeats the one before it in other words.

## Words

- AI vocabulary: delve, tapestry, testament, interplay, nuanced, underscore, embark, navigate, landscape, realm, robust, seamless, crucial, pivotal, game-changer, paradigm shift, elevate, empower, supercharge.
- Metaphor nouns as filler: flywheel, north star, substrate, vector, unlock, leverage (as a verb), ecosystem (when you mean "set of tools").
- Inflated copulas: "serves as", "acts as", "stands as" when "is" works.
- Weak verbs: utilize (use), facilitate (help), implement (build, add), in order to (to), due to the fact that (because).
- Vague attribution: "experts say", "studies show". Name the source or drop the claim.
- Promotional adjectives: vibrant, thriving, nestled, cutting-edge, world-class.
- Synonym cycling: once you name a thing, keep calling it that.

## Punctuation and formatting

- No em dashes as a tic. Use a comma, a colon, parentheses or a new sentence.
- Bold is for defined terms and scannable labels, not emphasis scattered through prose.
- No decorative emoji.
- A heading must not restate the list beneath it.

## Principles

- Prefer information over cleverness.
- Be concrete enough that the copy could not describe any other product. Names, numbers, mechanisms.
- Say what a thing does, not what it resembles.
- Let interesting facts speak for themselves. Do not tell the reader a fact is interesting, surprising or important.
- Active voice where natural. Split dense compound sentences.
- Sound like a thoughtful human explaining something to a colleague.

## Check before returning

1. Read the last sentence of every paragraph. If it summarizes or editorializes the paragraph, delete it.
2. Search the text for every phrase in the lists above.
3. In file mode, confirm code blocks, links and heading count match the original.

Do not report which patterns you removed unless asked. Return the text.
