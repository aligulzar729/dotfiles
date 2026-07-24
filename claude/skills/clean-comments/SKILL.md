---
name: clean-comments
description: Repo standard for comment hygiene. Delete comments that merely restate what the code does, keep only comments that explain the non-obvious why (rationale, gotchas, workarounds, references, surprises), never use em dashes in comments or code, and never let a frontend comment expose business logic. Apply automatically before finishing ANY code edit in this repo (PHP/Laravel, JS/TS, Node, Vue, React), and run on demand to clean the current changes. Use whenever writing, editing, reviewing, refactoring, or documenting code here, even if the user only says "clean this up", "review my code", or "add docs".
---

# Clean Code Comments (repo standard)

This is reference content for this repository. Apply it automatically whenever you write, edit, or review code here, and run the keep-or-delete pass before you finish any edit. It can also be invoked on demand to clean the current changes.

## When invoked directly (task mode)

Run a cleanup pass over the current changes:

1. Read the working changes with `git diff` (or `git diff --staged` if there is nothing unstaged). If `$ARGUMENTS` names a path, scope the pass to that path.
2. Apply the rules below to every changed file. Edit the files in place.
3. Report what you changed, grouped by reason (noise removed, magic numbers named, em dashes fixed, frontend leaks relocated). Do not narrate every line.

## Core principle

Code explains *what* and *how* by itself, through clear names and structure. Comments are reserved for what the code cannot say: the *why*. Every comment must earn its place. A comment a competent reader could reconstruct from the code is noise, and noise rots: it drifts out of sync and trains readers to ignore comments.

## The keep-or-delete test

For each comment ask: **does this tell the reader something the code itself cannot?**

**Delete (noise):**
- Restating the code: `i++ // increment i`, `return total // return the total`.
- Narrating obvious structure: `// loop over users`, `// the constructor`, `// imports`.
- Section banners that a well-named extracted function would replace.
- Commented-out (dead) code: version control already remembers it.
- Docblocks that only echo the signature: `@param User $user The user`.

**Keep (signal):**
- **Why, not what:** the reason behind a non-obvious choice, a trade-off, a business or regulatory constraint.
- **Surprises:** code that intentionally looks wrong, for example `// API pages are 1-indexed, so start at 1`.
- **Gotchas and workarounds:** third-party quirks, ordering dependencies, for example `// do not reorder: validate() mutates state read below`.
- **References:** a ticket, spec, RFC, or the source of a formula.
- **TODO / FIXME / HACK:** keep these markers.
- **Public API docs** that add real information beyond the signature (units, ranges, error conditions).

## Prefer fixing the code over adding a comment

Before writing an explanatory comment, try to move the clarity into the code: rename a vague variable, extract a confusing block into a named function, replace a magic number with a named constant. Reach for a comment only when clarity cannot live in the code. Deleting a comment is not a license to leave cryptic code behind: fix the names or structure in the same edit.

## No em dashes

Never use the em dash (the long dash) in comments, string literals, UI copy, or any text the code produces. Replace it: use a comma or parentheses for an aside, "to" or a hyphen for a range, a colon or period for an abrupt break. Avoid the en dash too.

## Frontend comments must not leak business logic

Frontend code (Vue, React, any client-side JS or TS) ships to the browser and is readable by anyone. Treat every frontend comment as public. Frontend comments must never expose pricing rules, discount thresholds, fee formulas, security or authorization reasoning, internal limits, fraud heuristics, A/B allocation, or any proprietary rationale. They may explain UI and rendering mechanics only.

A leak is usually a structure problem, not just a comment problem. The fix is to move the computation server-side and have the API send the client a plain, already-decided value (a price, a boolean flag), so the client knows *what* to render but not *why*.

## Examples

### Backend (Laravel / PHP)

Business rationale is safe to write down here, so the focus is noise removal, naming, and keeping the genuine why.

**Delete noise, name the magic numbers, keep the real why.**

Before:
```php
public function generate(Order $order): Invoice
{
    // Get the line items
    $items = $order->items;

    // Calculate the subtotal
    $subtotal = $items->sum(fn ($i) => $i->price * $i->quantity);

    // Add 10% tax
    $tax = $subtotal * 0.10;

    // We round each line and then sum, because the accounting system rounds
    // per line. Summing first and rounding once drifts by a few yen and fails
    // month-end reconciliation.
    $total = $items->sum(fn ($i) => round($i->price * $i->quantity * 1.10));

    // Create and return the invoice
    return Invoice::create([...]);
}
```
After:
```php
private const TAX_RATE = 0.10;

public function generate(Order $order): Invoice
{
    $items = $order->items;
    $subtotal = $items->sum(fn ($i) => $i->price * $i->quantity);
    $tax = $subtotal * self::TAX_RATE;

    // Round each line before summing to match the accounting system.
    // Summing first then rounding drifts by a few yen and breaks reconciliation.
    $total = $items->sum(
        fn ($i) => round($i->price * $i->quantity * (1 + self::TAX_RATE))
    );

    return Invoice::create([...]);
}
```

**Keep an idempotency why, delete the rest.**

Before:
```php
public function handle(Request $request)
{
    // Handle the incoming webhook
    $type = $request->input('type');

    // Check if we already processed this so we do not charge twice.
    // Stripe retries webhooks, so the same event id can arrive several times.
    if (ProcessedEvent::where('event_id', $request->input('id'))->exists()) {
        // Return early
        return response()->noContent();
    }

    // Process the event
    $this->process($type, $request);
    return response()->noContent();
}
```
After:
```php
public function handle(Request $request)
{
    $type = $request->input('type');

    // Stripe retries webhooks, so the same event id can arrive several times.
    // Skip duplicates to avoid charging twice.
    if (ProcessedEvent::where('event_id', $request->input('id'))->exists()) {
        return response()->noContent();
    }

    $this->process($type, $request);
    return response()->noContent();
}
```

### Frontend (React)

Every comment here is public. Remove leaks and noise, keep comments that are purely about UI mechanics.

**A leak is a structure problem: delete the comment and move the logic server-side.**

Before (shipped component):
```jsx
export function PriceTag({ user, product }) {
  // VIP users (more than 10 orders in 90 days) get an extra 15% off on top of
  // the sale price. Marketing does not want this shown as a coupon.
  const isVip = user.orderCount90d > 10;
  const price = isVip ? product.salePrice * 0.85 : product.salePrice;

  // Hide the price for accounts under fraud review so they cannot confirm
  // their card still works before we lock them out.
  if (user.fraudReview) return null;

  // show the price
  return <span className="price">{formatYen(price)}</span>;
}
```
After:
```jsx
export function PriceTag({ user, product }) {
  const price = user.effectivePrice ?? product.salePrice;

  if (user.priceHidden) return null;

  return <span className="price">{formatYen(price)}</span>;
}
```
Both comments leaked business and anti-fraud logic. The threshold, the 15% rule, and the fraud reasoning move server-side. The API now sends `effectivePrice` (already discounted) and a plain `priceHidden` flag, so the client renders what to show and knows nothing about why.

**Keep a UI-mechanics comment. Not every frontend comment is a leak.**

Before:
```jsx
// make the tooltip
{open && (
  <span className="tooltip" style={{ zIndex: 9999 }} role="tooltip">{label}</span>
)}
```
After:
```jsx
{open && (
  // z-index 9999 so the tooltip clears the sticky header, which the UI
  // library renders at 1100.
  <span className="tooltip" style={{ zIndex: 9999 }} role="tooltip">{label}</span>
)}
```
Deleted the "make the tooltip" noise. The z-index comment explains the otherwise mysterious `9999`, leaks nothing about the business, and stays.

### Em dash

Before: `// Retry up to three times — then give up and alert.`
After: `// Retry up to three times, then give up and alert.`

## Checklist before finishing any edit

- No comment merely restates the code.
- Every remaining comment explains a why, gotcha, reference, or surprise.
- Magic numbers are named, unclear names are fixed.
- No commented-out code.
- No em dashes or en dashes in comments or strings.
- No frontend comment leaks business logic, and sensitive computation lives server-side.
