# Tailwind v4 token lookup tables

Read this when converting a **fixed-token** utility (Rule 2) or when you need to
confirm whether a utility is spacing-driven. All values are Tailwind v4 defaults
(base `--spacing` = `0.25rem` = `4px`). If the project customizes its theme, the
project config wins.

## Contents
1. Spacing-scale utilities (use ÷4 / ×4, not this lookup)
2. Font size (`text-*`)
3. Border radius (`rounded-*`) + v4 rename
4. Border width (`border-*`)
5. Box shadow (`shadow-*`) + v4 rename
6. Blur (`blur-*`) + v4 rename
7. Opacity, z-index, fractions
8. Quick conversion sanity table (px → spacing N)

---

## 1. Spacing-scale utilities — apply Rule 1, not a lookup

These are dynamic. Any `<util>-<number>` (including decimals) works:
`m mx my mt mr mb ml ms me · p px py pt pr pb pl ps pe · w h size min-w min-h
max-w max-h · gap gap-x gap-y · inset inset-x inset-y top right bottom left start
end · space-x space-y · translate-x translate-y translate-z · scroll-m* scroll-p*
· indent · leading-<number>`.

Convert by math: **px ÷ 4** or **rem ÷ 0.25**. Negative → minus before the
utility (`-mt-2`).

## 2. Font size — `text-*`

Match the exact px; line-height shown is the paired default but isn't needed for
the size conversion.

| px   | rem      | class       |
| ---- | -------- | ----------- |
| 12   | 0.75rem  | `text-xs`   |
| 14   | 0.875rem | `text-sm`   |
| 16   | 1rem     | `text-base` |
| 18   | 1.125rem | `text-lg`   |
| 20   | 1.25rem  | `text-xl`   |
| 24   | 1.5rem   | `text-2xl`  |
| 30   | 1.875rem | `text-3xl`  |
| 36   | 2.25rem  | `text-4xl`  |
| 48   | 3rem     | `text-5xl`  |
| 60   | 3.75rem  | `text-6xl`  |
| 72   | 4.5rem   | `text-7xl`  |
| 96   | 6rem     | `text-8xl`  |
| 128  | 8rem     | `text-9xl`  |

No exact match (e.g. `text-[15px]`) → keep the bracket.

## 3. Border radius — `rounded-*`

**v4 values** (note the rename from v3):

| px   | rem      | v4 class      | (was in v3)    |
| ---- | -------- | ------------- | -------------- |
| 0    | 0        | `rounded-none`| `rounded-none` |
| 2    | 0.125rem | `rounded-xs`  | `rounded-sm`   |
| 4    | 0.25rem  | `rounded-sm`  | `rounded` (bare)|
| 6    | 0.375rem | `rounded-md`  | `rounded-md`   |
| 8    | 0.5rem   | `rounded-lg`  | `rounded-lg`   |
| 12   | 0.75rem  | `rounded-xl`  | `rounded-xl`   |
| 16   | 1rem     | `rounded-2xl` | `rounded-2xl`  |
| 24   | 1.5rem   | `rounded-3xl` | `rounded-3xl`  |
| 32   | 2rem     | `rounded-4xl` | (new in v4)    |
| ∞    | —        | `rounded-full`| `rounded-full` |

Side/corner variants follow the same scale: `rounded-t-* rounded-r-* rounded-b-*
rounded-l-*`, logical `rounded-s-* rounded-e-*`, corners `rounded-tl-* …
rounded-bl-*`, logical corners `rounded-ss-* … rounded-ee-*`.

The bare `rounded` still works for backward compatibility (= `rounded-sm` = 4px),
but prefer the explicit named token.

## 4. Border width — `border-*`

Fixed integer steps — **no ÷4 here**:

| px | class        |
| -- | ------------ |
| 1  | `border`     |
| 2  | `border-2`   |
| 4  | `border-4`   |
| 8  | `border-8`   |

Per-side: `border-x-* border-y-* border-t-* border-r-* border-b-* border-l-*`
(and logical `border-s-* border-e-*`).

`border-[3px]`, `border-[5px]`, `border-[6px]` etc. have **no** native step →
keep the bracket. Do not round.

## 5. Box shadow — `shadow-*`

**v4 renamed** the scale so every step has a name. Map v3→v4:

| v4 class      | (was in v3)     |
| ------------- | --------------- |
| `shadow-2xs`  | (new)           |
| `shadow-xs`   | `shadow-sm`     |
| `shadow-sm`   | `shadow` (bare) |
| `shadow-md`   | `shadow-md`     |
| `shadow-lg`   | `shadow-lg`     |
| `shadow-xl`   | `shadow-xl`     |
| `shadow-2xl`  | `shadow-2xl`    |

Arbitrary box-shadows are multi-part and rarely match a token exactly — usually
keep `shadow-[...]` unless it's clearly one of the named presets.

## 6. Blur — `blur-*`

Same v4 rename pattern:

| v4 class   | (was in v3)   |
| ---------- | ------------- |
| `blur-xs`  | `blur-sm`     |
| `blur-sm`  | `blur` (bare) |
| `blur-md`  | `blur-md`     |
| `blur-lg`  | `blur-lg`     |
| `blur-xl`  | `blur-xl`     |
| `blur-2xl` | `blur-2xl`    |
| `blur-3xl` | `blur-3xl`    |

## 7. Opacity, z-index, fractions

- **opacity:** number is 0–100. `opacity-[0.5]` → `opacity-50`,
  `opacity-[0.05]` → `opacity-5`. Color modifier: `bg-black/[0.05]` →
  `bg-black/5`, `text-white/[0.6]` → `text-white/60`.
- **z-index:** named steps `z-0 z-10 z-20 z-30 z-40 z-50` (+ `z-auto`).
  `z-[100]`, `z-[999]` have no named step → keep the bracket.
- **fractions** (width, inset, translate, basis, etc.): convert only on an exact
  match. `1/2 1/3 2/3 1/4 3/4 1/5 … 11/12` and `full`. `w-[50%]` → `w-1/2`,
  `w-[33.333333%]` → `w-1/3`, `inset-[25%]` → `inset-1/4`. A percentage with no
  matching fraction (`w-[37%]`) stays arbitrary.

## 8. px → spacing N sanity table (Rule 1)

| px | N     | px | N     | px | N    | px  | N    |
| -- | ----- | -- | ----- | -- | ---- | --- | ---- |
| 1  | 0.25  | 9  | 2.25  | 20 | 5    | 64  | 16   |
| 2  | 0.5   | 10 | 2.5   | 24 | 6    | 80  | 20   |
| 3  | 0.75  | 11 | 2.75  | 28 | 7    | 96  | 24   |
| 4  | 1     | 12 | 3     | 32 | 8    | 100 | 25   |
| 5  | 1.25  | 14 | 3.5   | 36 | 9    | 128 | 32   |
| 6  | 1.5   | 16 | 4     | 40 | 10   | 160 | 40   |
| 7  | 1.75  | 17 | 4.25  | 44 | 11   | 200 | 50   |
| 8  | 2     | 18 | 4.5   | 48 | 12   | 256 | 64   |

For any px not listed: `N = px ÷ 4`. For rem: `N = rem ÷ 0.25`.
