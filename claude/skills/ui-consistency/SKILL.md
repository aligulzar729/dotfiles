---
name: ui-consistency
description: Checks changed UI lines for consistency with the project's own design system and UI copy, then fixes what it finds. Covers shared primitives, design tokens, styling in the owning component, composable components, type, icons, layout and UI copy. Works in any web or app project (React, Vue, Svelte, Blade, Livewire, React Native, SwiftUI, Compose). Use after any change to a component, page, view or stylesheet, before the code review, when the user says "ui consistency", "check the UI" or "check the copy", and in the ali-mode UI playbook.
---

# UI consistency

This check guards styling and copy. It is not a general code review. Check only the lines that the change adds or edits. Do not report old code that the change does not touch. If a violation is not clear from the diff and the files that it names, it is not a finding.

Project rules win over this skill. This skill gives the checks. The project gives the values: its primitives, tokens, fonts, accent and words.

## 1. Learn the project once

Find these before you check the diff. Use `ls`, `git ls-files` and `grep -rln`; do not read whole folders.

1. **Rules:** `CLAUDE.md`, `AGENTS.md`, `.ai/rules/*` (use `.ai/rules/index.md` to pick the files for the changed paths), `.cursor/rules`, `DESIGN.md`, `.impeccable.md`, design-system docs. Note every UI and copy rule.
2. **Primitives:** the shared component folder. Typical places are `components/ui`, `src/components/ui`, `resources/js/components/ui`, `app/components`, `packages/ui`, `resources/views/components`, and SwiftUI or Compose `DesignSystem` modules. List the primitive names.
3. **Tokens:** the theme source, for example a Tailwind v4 `@theme` block in the main CSS, `tailwind.config.*`, CSS custom properties, `tokens.json`, or an asset catalog. Note the semantic colour names, the radius and spacing scale, the fonts, and how dark mode works.
4. **Reference component:** one composable component that the project holds up as the model, or the best slot-based primitive (parts that set `data-slot`, accept `className`, spread props and merge classes).
5. **Voice:** `grep` 10 to 20 existing labels, buttons and toasts in the pages to learn the terms and the case style.

If the project has none of 2 to 4, check only sections 6 and 7, and say so in the report.

## 2. Scope

Get the changed lines of UI files, without tests:

```bash
git diff -U0 HEAD -- . ':!**/*.test.*' ':!**/*.spec.*' ':!**/__tests__/**'
git ls-files --others --exclude-standard
```

Keep only components, pages, views, templates and stylesheets. Other sessions can edit the same working tree, so check only the files of the current task.

## 3. Shared primitives, not custom controls

- Flag a raw `<button>`, `<input>`, `<select>` or `<textarea>` (or the platform's raw control) that is styled to look like a control when a project primitive exists.
- Flag a call site that overrides the height, radius, padding, focus ring or base colours of a primitive with its own classes. When several places need the same look, the fix is a new `variant` or `size` on the primitive.
- Flag a hand-built dialog, menu, popover, tooltip, toast or tabs when the project has one.
- Do not flag a raw element that is a different thing by design: a semantic row, a tab strip with its own behaviour, a resize handle, a swatch, an editor surface, a media tile.

## 4. Tokens, never raw values

- Flag a raw colour (hex, `rgb()`, `hsl()`, `oklch()`) or a palette class (`bg-white`, `bg-black`, `text-gray-*`, `text-neutral-*`, `text-zinc-*`, `text-slate-*`) in app UI when the project has semantic tokens.
- Flag a new accent colour that the design system does not have.
- Flag a fix for one theme that leaves the other broken. When the project has light and dark themes, the change must read well in both.
- Flag an off-scale spacing, radius, font size or shadow when a scale value exists. In Tailwind, flag an arbitrary value (`h-[3px]`, `text-[14px]`) that has an exact native class; the `tailwind-native-classes` skill has the tables.

## 5. Styling lives in the owning component

- Flag a new global CSS rule that classes on the owning component can express. Global CSS is correct only for: generated markdown or editor DOM, third-party or portal markup that a class cannot reach, keyframes, theme variables, and variant definitions.
- Flag a new inline style object with static values that a class or token covers. Values that the code computes at runtime are correct.
- Flag a theme rule in new CSS that uses a raw `.dark` selector when the project has a `dark:` variant or `@variant dark`.

## 6. Composable components

Hold new UI to the shape of the reference component: each part owns its classes, sets `data-slot` (where the project uses it), accepts `className`, spreads the other props and merges with the project's class helper (`cn`, `clsx`, `twMerge`). Variants are props, not class strings at the call site.

- Flag a new component that copies the markup and classes of an existing component instead of composing or extending it. `grep -rn` a distinctive class string from the new code before you write the finding.
- Flag a long class string that repeats a treatment that another call site already has. The fix is a variant or a slot.
- Flag a new form row, settings row, card or list item that ignores the project's existing pattern for it.

## 7. Type, icons and layout

- Use only the project's font families and weights. Flag a weight that the loaded font does not have (it renders as the nearest weight).
- Use the project's heading scale. Do not invent a size for one heading.
- Use one icon set, at the project's sizes and stroke. An icon-only button has an accessible name (`aria-label`, `accessibilityLabel`).
- Hit areas are 44px (iOS) or 48dp (Android) at least on touch screens, or the size that the project rules give.
- Flag the AI design tells, unless the project asks for them: gradient text, coloured side stripes on cards and alerts, glassmorphism on everything, rows of identical icon-topped cards, grey text on a coloured background, uppercase tracked-out eyebrow labels ("kickers") above headings, everything centred.

## 8. UI copy

Check every user-facing string that the change adds or edits: labels, buttons, headings, placeholders, toasts, empty states, errors, confirmations, tooltips and accessible names. For a full rewrite of a screen's copy, use the `better-writing` skill.

- Say what the user can do or what happened. Do not explain how the system works inside, why a feature is off, or who it does not run for. Delete the explanation, and do not move it to a tooltip.
- Delete a helper line that repeats its label, and a step label that repeats what the screen already shows.
- Do not describe the product in its own UI ("the design community app for..."). Use the name that the project rules give, or no name.
- Use the words that sibling screens use for the same thing. `grep -rn` the term in the pages and components and copy the existing word. One word for one meaning: not "Delete" in one place and "Remove" in another for the same action.
- Keep the project's case style. With no rule, use sentence case.
- A button is a verb plus an object ("Save changes", "Follow"). Not "OK", "Submit" or "Yes".
- An error says what went wrong and what to do next, in one sentence. Never "Something went wrong" alone.
- An empty state says what will appear here and gives the one action that fills it.
- A toast confirms a completed action in 2 to 5 words ("Draft saved"). Do not toast an action that the UI already shows.
- A destructive confirmation names the object and the result ("Delete this post? Its comments go too.").
- Follow the project's string setup: inline literals or i18n keys, whichever the project uses. Never mix them.
- No em dashes, no exclamation marks and no emoji in copy, unless the project voice uses them.

## 9. Fix and report

1. Fix every finding in the changed lines yourself. Stay inside the task's files. When the fix needs a new variant on a shared primitive, add the variant and use it.
2. Do not fix old code that the change did not touch. List it under "Not in scope" when it is in the same file and a real violation.
3. Check the result in a real browser or simulator at desktop and phone width, in each theme that the project has.
4. When the same finding comes back in two tasks, propose a lint or a test for it with the `correct` skill.
5. Report one line per finding:

   ```
   <section number and name> | file:line | what changed
   ```

   When there are no findings, the whole report is `All clear`.
