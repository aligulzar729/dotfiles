---
name: tailwind-native-classes
description: >-
  Convert Tailwind CSS v4 arbitrary "bracket" values (like h-[3px], w-[100px],
  p-[10px], mt-[5.25rem], text-[14px], rounded-[8px], opacity-[0.5]) into native
  scale utilities (h-0.75, w-25, p-2.5, mt-21, text-sm, rounded-lg, opacity-50).
  Use this skill WHENEVER writing, generating, editing, reviewing, or refactoring
  any Tailwind CSS markup or components (HTML, JSX/TSX, Vue, Blade, Svelte),
  converting CSS or design specs into Tailwind, or whenever a square-bracket
  arbitrary value appears in a class/className attribute — even if the user never
  says the words "arbitrary value" or "refactor". The v4 spacing scale (4px base)
  generates fractional steps like 0.75 and 1.25 on demand, so almost every px/rem
  bracket value has an EXACT native equivalent. Default to the native class; keep
  the bracket only when no exact native token exists.
---

# Tailwind v4: Native classes over arbitrary values

In Tailwind CSS v4, most utilities are generated dynamically from a small set of
theme tokens. The spacing scale in particular is driven by one variable —
`--spacing` (default `0.25rem` = `4px`) — and the engine generates
`calc(var(--spacing) * N)` for **any** number `N` you write, including fractions
like `0.75`, `1.25`, or `2.5`. That means a value you would have written as an
arbitrary bracket value in v3 (`h-[3px]`) almost always has an exact native form
in v4 (`h-0.75`).

Prefer the native form. It keeps the code on the design system, lets Tailwind's
LSP autocomplete and lint it, compresses better, and is the path the official
`@tailwindcss/upgrade` tool and Tailwind IntelliSense both push you toward.

**Core mandate:** when you emit or edit a class with a square-bracket length and
an exact native token exists, write the native token instead. Only fall back to
the bracket when there is genuinely no exact equivalent (see "When to KEEP the
bracket" below) — never silently round to a *near* value, because that changes
the design.

---

## Rule 1 — The spacing-scale rule (covers the large majority of cases)

For any utility driven by `--spacing`, convert the bracket value to a multiplier:

- **From px:** `N = px ÷ 4`
- **From rem:** `N = rem ÷ 0.25` (i.e. `rem × 4`)
- Write `<utility>-<N>`. Drop a trailing `.0` (`4.0` → `4`).
- **Negative values:** move the minus in front of the utility, not the number.
  `mt-[-8px]` → `-mt-2`, `top-[-3px]` → `-top-0.75`.

Because px values are whole numbers, `px ÷ 4` always lands cleanly on a
`.0 / .25 / .5 / .75` step, all of which v4 generates.

**Examples:**

| Arbitrary (v3 style) | Native (v4)  | Why                |
| -------------------- | ------------ | ------------------ |
| `h-[3px]`            | `h-0.75`     | 3 ÷ 4 = 0.75       |
| `w-[100px]`          | `w-25`       | 100 ÷ 4 = 25       |
| `p-[10px]`           | `p-2.5`      | 10 ÷ 4 = 2.5       |
| `gap-[6px]`          | `gap-1.5`    | 6 ÷ 4 = 1.5        |
| `m-[2px]`            | `m-0.5`      | 2 ÷ 4 = 0.5        |
| `size-[7px]`         | `size-1.75`  | 7 ÷ 4 = 1.75       |
| `mt-[5.25rem]`       | `mt-21`      | 5.25 ÷ 0.25 = 21   |
| `px-[1rem]`          | `px-4`       | 1 ÷ 0.25 = 4       |
| `-top-[8px]`         | `-top-2`     | sign moves to front|
| `leading-[24px]`     | `leading-6`  | line-height is on the spacing scale |

**Utilities that use the spacing scale** (apply Rule 1 to all of these):

- margin: `m mx my mt mr mb ml ms me`
- padding: `p px py pt pr pb pl ps pe`
- sizing: `w h size min-w min-h max-w max-h`
- gap: `gap gap-x gap-y`
- position/inset: `inset inset-x inset-y top right bottom left start end`
- space-between: `space-x space-y`
- transforms: `translate-x translate-y translate-z`
- scroll: `scroll-m* scroll-p*`
- text: `indent`, and `leading-<number>` (line-height)

If you are unsure whether a utility is spacing-driven, check the table in
`references/token-tables.md` before converting.

## Rule 2 — Fixed-token utilities (look up, do NOT divide by 4)

Some utilities map a length to a **named** token rather than a spacing multiple.
Match the bracket value to the token with the **exact** same computed value. Do
not approximate. The full lookup tables (font-size, border-radius, border-width,
shadow/blur with v4 rename caveats, etc.) live in
**`references/token-tables.md`** — read it whenever you hit one of these.

Quick high-frequency ones:

| Arbitrary        | Native      |
| ---------------- | ----------- |
| `text-[14px]`    | `text-sm`   |
| `text-[16px]`    | `text-base` |
| `rounded-[8px]`  | `rounded-lg`|
| `rounded-[12px]` | `rounded-xl`|
| `border-[2px]`   | `border-2`  |

## Rule 3 — Ratio / percentage utilities

- **opacity:** the number is `0–100`. `opacity-[0.5]` → `opacity-50`,
  `opacity-[0.05]` → `opacity-5`. Color opacity modifiers too:
  `bg-black/[0.05]` → `bg-black/5`.
- **fractions** (width/translate/inset, etc.): `w-[50%]` → `w-1/2`,
  `w-[33.333333%]` → `w-1/3`, `left-[25%]` → `left-1/4`. Only when the percentage
  matches a built-in fraction exactly.

---

## When to KEEP the bracket (do not convert)

Leave the arbitrary value in place — converting would be wrong or impossible —
when:

- **No exact native token exists.** `border-[3px]` has no native step
  (border-width is `1 / 2 / 4 / 8`), so keep it. Never round 3px to `border-2`
  or `border-4`.
- **Brand/exact colors not in the palette:** `bg-[#1b2a4a]`, `text-[#0af]`.
- **CSS variables:** `bg-[var(--brand)]`, `w-[var(--sidebar)]` — though prefer
  the shorthand `bg-(--brand)` / `w-(--sidebar)` v4 offers for this.
- **Functions and dynamic units:** `w-[calc(100%-2rem)]`, `min-h-[100dvh]`
  (note: `min-h-dvh` exists — use it if it matches), `text-[clamp(1rem,2vw,2rem)]`.
- **Genuinely off-scale one-offs** the design requires that aren't a clean
  spacing multiple in disguise.

The test is simple: **does an exact native equivalent exist?** If yes, use it.
If no, the bracket is correct — keep it.

---

## Workflow when editing existing markup

1. Scan the class/className strings for `[...]` bracket values.
2. For each, classify: spacing-scale (Rule 1), fixed-token (Rule 2,
   `references/token-tables.md`), ratio (Rule 3), or keep-as-is.
3. Replace in place, preserving variant prefixes and order:
   `md:hover:p-[10px]` → `md:hover:p-2.5`, `dark:text-[14px]` → `dark:text-sm`.
4. Do not touch brackets that should stay (the keep list above).
5. If you converted several, you can note which were left as arbitrary and why
   (e.g. "kept `border-[3px]` — no native border-width step").

## Important v4 caveats

- **This is v4-specific.** The dynamic spacing scale and fractional steps do not
  exist in v3. If the project is on v3, only the values present in its configured
  scale are valid — say so rather than emitting `h-0.75` into a v3 codebase.
- **Custom `--spacing`.** If the theme overrides `--spacing` or disables the
  default scale, the ÷4 math no longer holds. When you can see the theme config,
  use it; otherwise assume the 4px default and flag the assumption.
- **The v4 radius/shadow/blur rename.** v3's `rounded-sm` (2px) is v4's
  `rounded-xs`; v3's bare `rounded` (4px) is v4's `rounded-sm`. Same shift for
  `shadow`/`blur`. Don't confuse the v3 and v4 meanings of `-sm` when converting.
  Details in `references/token-tables.md`.
- **Let tooling help at scale.** For a whole-project migration, the official
  `npx @tailwindcss/upgrade` tool auto-simplifies arbitrary values. This skill is
  for the inline, hand-written/generated case where no migration run is happening.
