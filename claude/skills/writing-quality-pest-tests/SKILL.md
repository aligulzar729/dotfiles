---
name: writing-quality-pest-tests
description: "Write or refactor PestPHP tests for Laravel apps. Use whenever the user wants to test, add tests for, or improve tests for a controller, model, action, job, endpoint, Livewire component, or Filament resource/page — or says things like 'write Pest tests', 'cover this with tests', 'test the happy and failure path', 'these tests are messy', 'use datasets', or 'test this Livewire/Filament component'. Produces behaviour-driven tests that cover happy AND failure paths (including every validation rule), drive real Livewire/Filament components through the livewire() helper, chain related expectations fluently with and(), and collapse repetitive cases into datasets instead of one-assertion-per-method padding."
---

# Writing quality Pest tests

Tests should describe **what the software does for its caller**, not mirror the source line by line. A good test reads like a sentence about a behaviour, survives a behaviour-preserving refactor, and fails loudly when behaviour actually breaks. The rules below are the default; deviate only when the user asks or the case genuinely doesn't fit. The worked examples for the judgement-heavy parts live in the two appendices at the bottom of this file.

- **Any Livewire component (every Filament page/resource is one)** → drive it through `livewire()` (Pest plugin) or `Livewire::test()` — same API. Never `new Component`.
- Read **Appendix B** for the Filament v5 / Livewire v4 helpers before writing those tests; don't write them from memory.

Skim an existing test to match house style (`it` vs `test`, refresh-DB style, factory names).

## 1. Map behaviours, not methods

List the observable behaviours from the caller's point of view (a valid request creates the record; an invalid one is rejected; an unauthorised one is blocked). Each behaviour is one test (or one dataset-driven test) — not one test per line of the method. See **Appendix A → Flows, not lines**.

## 2. Cover happy AND failure paths — and every validation rule

Every behaviour with a success case has at least one meaningful failure case, and failures are where bugs hide.

- **Happy path**: valid input produces the right user-visible outcome (response, DB state, event/notification, redirect).
- **Failure paths**: invalid input, missing permission, not-found, conflicting state, boundaries. Assert the right error *and* that no unwanted side effect happened (nothing written, no mail sent).
- **Validation**: wherever code validates (FormRequest, `$request->validate`, Livewire/Filament form rules), the failing path is mandatory — and each rule gets its own assertion (`required`, `email`, `max`, `unique`, etc.), collapsed into a dataset. Asserting only that the request is rejected is not enough; assert *which* rule fired.

Keep happy and failure paths in separate tests — merging hides which half broke.

## 3. Drive Livewire & Filament through the real component

Test the live component (mount → fill → call → assert), not a hand-built unit. For **Filament resources and pages, test the full surface** — leaving any of these untested is a gap:

- every **action** (row, header, page) and its form/validation and side effect
- every **bulk action** (select records, run, assert effect)
- every **table filter** (apply it, assert the records shown change)
- any **custom query / table query modifier** (e.g. scoping, `modifyQueryUsing`, tenancy) — assert the right records appear and the wrong ones don't

Version-correct helpers (`assertCanSeeTableRecords`, `callAction`, `assertHasFormErrors`, filters, browser tests) are in **Appendix B**.

## 4. Merge what's the same; split what's different

Same behaviour, different inputs → one test + a **dataset** with named keys. Different outcomes (success vs rejection vs forbidden) → separate tests. If you're about to copy-paste an `it()` and change one value, make it a dataset.

```php
it('rejects invalid registration input', function (array $payload, string $field, string $rule) {
    $this->postJson('/register', $payload)->assertJsonValidationErrorFor($field);
    expect(User::count())->toBe(0);
})->with([
    'missing email' => [['name' => 'Ali'], 'email', 'required'],
    'invalid email' => [['email' => 'nope'], 'email', 'email'],
    'short password' => [['password' => '123'], 'password', 'min'],
]);
```

Reusable datasets go in `tests/Datasets/` via `dataset('name', [...])`. More: **Appendix A**.

## 5. Chain related expectations

Chain by subject — one subject, one chain; new subject, `and()`. Don't stack separate `expect()` statements about one object.

```php
expect($order->refresh())
    ->status->toBe('paid')
    ->total->toBe(5000)
    ->and($shipment->tracking_number)->not->toBeNull();
```

## 6. Self-review before handing back

Run the tests (`./vendor/bin/pest path/to/Test.php`), then check:

- Each test name describes a behaviour, and survives an internal refactor.
- Every happy path that warrants it has a failure-path test, and every validation rule is asserted by name.
- For Filament: all actions, bulk actions, filters, and custom queries are covered.
- Livewire/Filament subjects go through `livewire()`, never `new`.
- Repeated same-behaviour cases are one dataset with named keys; related expectations are chained.
- Failure paths assert the absence of side effects. Cut anything that just re-tests the framework.
- The feature and every affected file are fully covered by *meaningful* assertions; dead/unreachable code is removed and no live guard was deleted just to chase coverage.

## 7. Drive coverage up, then tidy the code

While testing the feature, aim for full coverage of the feature **and every file your change touches** — but coverage means *meaningful assertions*, not lines merely executed. A line that runs during a test without an assertion that would fail when it breaks is not covered. Use `./vendor/bin/pest --coverage --min=100` (pcov/Xdebug) to find the gaps; treat each uncovered line as a question: real path, or dead code?

- **Strengthen weak assertions and add missing tests** until every behaviour and branch of the feature and its affected files is pinned by an assertion. Replace vague checks (`assertOk` only) with ones that prove the actual outcome (payload, DB state, side effects). Note: Livewire v4 view-based (single/multi-file) components live in `resources/views`; add that directory to the coverage `<include>` in `phpunit.xml` or Pest won't count them.
- **Remove genuinely dead or unreachable code** in the files you touch: unreachable branches, returns after returns, unused methods/params.
- **Defensive code — be careful here.** If a guard cannot be triggered given the call sites and types, it's dead; remove it. If it *can* be triggered, do not delete it — write the test that hits it. Never delete a guard just to turn a coverage line green; confirm it is truly unreachable first, and when unsure, keep it and ask.
- **Prune the suite:** delete tests that assert nothing or only re-test the framework, and merge near-duplicates into datasets.

---

# Appendix A — Patterns: worked examples for the ambiguous calls

These are the judgement-heavy parts. Each section shows the weak version, the strong version, and the rule that distinguishes them.

## A1. Flows, not lines

The anti-pattern is writing one test per statement in the method under test — brittle tests that break on any refactor and still miss real bugs. Consider:

```php
public function store(StoreOrderRequest $request)
{
    $order = Order::create($request->validated());   // line A
    OrderPlaced::dispatch($order);                    // line B
    return new OrderResource($order);                 // line C
}
```

**Weak — one test per line, testing implementation:**

```php
it('calls Order::create', function () { /* mocks the model, asserts create() called */ });
it('dispatches an event', function () { /* asserts dispatch, ignores everything else */ });
it('returns an OrderResource', function () { /* asserts the class name */ });
```

None proves the endpoint works, and all break when you rename a method or swap the resource.

**Strong — one test per behaviour, through the real stack:**

```php
it('places an order for a valid request', function () {
    Event::fake();
    $user = User::factory()->create();

    $this->actingAs($user)
        ->postJson('/orders', ['product_id' => $product->id, 'qty' => 2])
        ->assertCreated()
        ->assertJsonPath('data.qty', 2);

    expect(Order::query()->where('user_id', $user->id)->first())->not->toBeNull()->qty->toBe(2);
    Event::assertDispatched(OrderPlaced::class);
});
```

**Rule:** test what the caller observes (status, payload, DB state, events) via a real request. Mock only true external boundaries (third-party HTTP, payment gateways) — never the code under test.

## A2. The merge-vs-split decision tree

One question: **does this case exercise the same behaviour with different data, or a different outcome?**

```
Different OUTCOME (success vs rejection vs forbidden)?  → SPLIT into separate tests
        │ same outcome
        ▼
Same assertions, only the inputs differ?               → MERGE into one dataset-driven test
        │ no
        ▼
Setup differs but the assertion is conceptually one?   → MERGE, vary setup inside the dataset
```

**Merge** — three rejection cases are one behaviour:

```php
it('rejects invalid coupon codes', function (string $code, string $reason) {
    $this->postJson('/coupons/apply', ['code' => $code])
        ->assertUnprocessable()
        ->assertJsonPath('errors.code.0', $reason);
})->with([
    'expired'  => ['SUMMER20', 'This coupon has expired.'],
    'used up'  => ['ONEUSE',   'This coupon has reached its limit.'],
    'unknown'  => ['NOPE',     'This coupon does not exist.'],
]);
```

**Split** — different outcomes stay apart even on the same endpoint:

```php
it('applies a valid coupon and reduces the total', function () { /* discounted total */ });
it('rejects an expired coupon', function () { /* 422 + unchanged total */ });
it('forbids applying a coupon to someone else\'s cart', function () { /* 403 */ });
```

**Do NOT merge** the happy path into the failure dataset — they assert different things, and merging hides which broke.

## A3. Datasets: inline, named, bound, reusable

```php
// Inline
it('is a weekend', fn (string $d) => expect(Carbon::parse($d)->isWeekend())->toBeTrue())
    ->with(['2026-06-06', '2026-06-07']);

// Named keys — prefer for >2 cases so failures read clearly
it('rejects invalid emails', function (string $email) {
    expect(fn () => User::factory()->create(['email' => $email]))->toThrow(ValidationException::class);
})->with([
    'no @ sign'     => 'plainaddress',
    'no TLD'        => 'user@localhost',
    'no local part' => '@example.com',
]);

// Bound (closures) — fresh model per case, resolved after migrations
it('shows the dashboard for active subscribers', function (User $user) {
    $this->actingAs($user)->get('/dashboard')->assertOk();
})->with([
    'monthly plan' => fn () => User::factory()->subscribed('monthly')->create(),
    'annual plan'  => fn () => User::factory()->subscribed('annual')->create(),
]);
```

**Reusable** — declare in `tests/Datasets/Emails.php` then `->with('invalid emails')` anywhere:

```php
dataset('invalid emails', [
    'no @ sign'     => 'plainaddress',
    'no TLD'        => 'user@localhost',
    'no local part' => '@example.com',
]);
```

Pass several datasets for the cartesian product: `->with('roles', 'invalid emails')`. **Rule:** about to copy-paste an `it()` and change one value? Make it a dataset.

## A4. Chaining expectations cleanly

```php
// Higher-order property chains — many assertions about ONE subject
expect($invoice->refresh())
    ->status->toBe('paid')
    ->amount_cents->toBe(5000)
    ->paid_at->not->toBeNull()
    ->customer->email->toBe('ali@example.com'); // nested access works

// and() — switch to a DIFFERENT subject in the same flow
expect($order->status)->toBe('shipped')
    ->and($order->items)->toHaveCount(3)
    ->and($shipment->tracking_number)->not->toBeNull();
```

Response assertions keep their own chain: `$response->assertOk()->assertJsonCount(3, 'data')->assertJsonPath('meta.total', 3);`. **Rule:** chain by subject. One subject, one chain. New subject, `and()`. New behaviour, new test — don't chain across behaviours just to avoid statements.

## A5. Failure paths that prove "nothing happened"

A failure test that only checks the error code is half a test — the bug is usually a *partial* side effect.

```php
it('does not charge the card when the order is invalid', function () {
    Mail::fake();
    $this->postJson('/checkout', ['qty' => 0])->assertUnprocessable();

    expect(Order::count())->toBe(0)->and(Payment::count())->toBe(0);
    Mail::assertNothingSent();
});
```

**Rule:** every failure-path test asserts both the rejection *and* the absence of the side effects the happy path would have produced.

---

# Appendix B — Livewire v4 & Filament v5 testing helpers

Target stack: **Filament v5 / Livewire v4 / Pest v4**. Filament v5 has no API changes from v4 — it exists to support Livewire v4 — so these helpers are stable. Every Filament page, resource page, relation manager, and widget *is* a Livewire component, so all of it goes through `livewire()` / `Livewire::test()`. Never `new ListPosts()`.

## B1. Entry point + auth

- `pestphp/pest-plugin-livewire` installed → `use function Pest\Livewire\livewire;` then `livewire(Component::class)`.
- Otherwise → `use Livewire\Livewire;` then `Livewire::test(Component::class)`. Same API after.

```php
beforeEach(fn () => $this->actingAs(User::factory()->admin()->create()));
```

## B2. Smoke + render

```php
it('renders the create page', fn () => $this->get(PostResource::getUrl('create'))->assertSuccessful());
it('mounts the list page', fn () => livewire(ListPosts::class)->assertSee('Posts'));
```

## B3. List, create, edit, validate

```php
use function Pest\Livewire\livewire;
use App\Filament\Resources\PostResource\Pages\{ListPosts, CreatePost, EditPost};

it('lists posts', function () {
    $posts = Post::factory()->count(3)->create();
    livewire(ListPosts::class)->assertCanSeeTableRecords($posts)->assertCountTableRecords(3);
});

it('creates a post', function () {
    $data = Post::factory()->make();
    livewire(CreatePost::class)
        ->fillForm(['title' => $data->title, 'content' => $data->content])
        ->call('create')->assertHasNoFormErrors();
    expect(Post::query()->where('title', $data->title)->first())->not->toBeNull()->content->toBe($data->content);
});

it('validates the form', function (array $input, string $field, string $rule) {
    livewire(CreatePost::class)->fillForm($input)->call('create')->assertHasFormErrors([$field => $rule]);
    expect(Post::count())->toBe(0); // failure path proves nothing saved
})->with([
    'missing title' => [['title' => null], 'title', 'required'],
    'long title'    => [['title' => str_repeat('a', 300)], 'title', 'max'],
]);

it('updates a post', function () {
    $post = Post::factory()->create();
    livewire(EditPost::class, ['record' => $post->getKey()])
        ->fillForm(['title' => 'Updated'])->call('save')->assertHasNoFormErrors();
    expect($post->refresh())->title->toBe('Updated');
});
```

Form assertions: `assertHasFormErrors([...])`, `assertHasNoFormErrors()`, `assertFormSet([...])`, `assertFormExists()`.

## B4. Actions & bulk actions (all mandatory to cover)

Unified behind `Filament\Actions\Testing\TestAction`: `->table($record)` row action, `->table()` header action, `->bulk()` after selecting records.

```php
use Filament\Actions\Testing\TestAction;

// row action + assert effect
livewire(ListPosts::class)->callAction(TestAction::make('delete')->table($post));
expect(Post::find($post->id))->toBeNull();

// header action
livewire(ListPosts::class)->callAction(TestAction::make('create')->table());

// bulk action
livewire(ListPosts::class)
    ->selectTableRecords($posts->pluck('id')->all())
    ->callAction(TestAction::make('delete')->table()->bulk());

// presence / visibility
livewire(ListPosts::class)
    ->assertActionExists(TestAction::make('edit')->table($post))
    ->assertActionVisible(TestAction::make('edit')->table($post));

// action with a form + side effect
it('sends an invoice', function () {
    $invoice = Invoice::factory()->create();
    livewire(EditInvoice::class, ['record' => $invoice->getKey()])
        ->callAction(TestAction::make('send'), data: ['email' => $email = fake()->email()])
        ->assertHasNoFormErrors()->assertNotified();
    expect($invoice->refresh())->is_sent->toBeTrue()->recipient_email->toBe($email);
});
```

## B5. Table filters (mandatory to cover)

Apply the filter, assert both sides — matching rows appear, non-matching don't.

```php
it('filters posts by status', function () {
    $published = Post::factory()->published()->create();
    $draft     = Post::factory()->draft()->create();
    livewire(ListPosts::class)
        ->filterTable('status', 'published')
        ->assertCanSeeTableRecords([$published])
        ->assertCanNotSeeTableRecords([$draft]);
});
```

Form-based filters take state: `->filterTable('created_at', ['from' => '2026-01-01'])`.

## B6. Custom queries / scoping (mandatory to cover)

If the resource narrows its base query (`getEloquentQuery()`, `modifyQueryUsing`, tenancy, ownership, soft-delete scoping), prove the scope: in-scope rows appear, out-of-scope rows are absent.

```php
it('only lists the current user\'s posts', function () {
    $this->actingAs($user = User::factory()->create());
    $mine  = Post::factory()->for($user)->create();
    $other = Post::factory()->create();
    livewire(ListPosts::class)
        ->assertCanSeeTableRecords([$mine])
        ->assertCanNotSeeTableRecords([$other]);
});
```

## B7. Plain (non-Filament) Livewire v4 components

```php
it('increments', function () {
    livewire(Counter::class)->assertSet('count', 0)->call('increment')->assertSet('count', 1)->assertSee('1');
});

it('blocks past the max', function () {        // failure path
    livewire(Counter::class, ['count' => 10, 'max' => 10])
        ->call('increment')->assertSet('count', 10)->assertHasErrors('count');
});
```

Core assertions: `assertSet`, `assertSee`/`assertDontSee`, `assertSeeHtml`, `assertDispatched`, `assertHasErrors`, `assertRedirect`, `assertForbidden`, `assertStatus`, `assertSeeLivewire('name')`.

## B8. Critical user flows → browser tests (only if configured)

Browser tests need real-browser tooling installed (Pest v4's browser plugin + Playwright). **Check first** before writing any: look for `pestphp/pest-plugin-browser` in `composer.json`, existing `visit()` / `Livewire::visit()` usage, or a Playwright install. If it isn't set up, don't introduce it unprompted — cover the flow with `Livewire::test()` (fast, no browser) and note that a browser test is an option if they want to configure it.

When browser testing *is* configured, choose by context:

- **Pest browser test** — `visit('/checkout')` — for a full-page or multi-page journey across real routes: navigation, redirects, several components on one page, JS-driven UI.
- **Livewire browser test** — `Livewire::visit(Checkout::class)` — when the flow lives inside a single Livewire component you want to mount directly.

```php
// Pest browser test — whole-page journey
it('lets a user check out', function () {
    visit('/checkout')
        ->fill('email', 'ali@example.com')
        ->click('@pay')
        ->assertSee('Thank you');
});

// Livewire browser test — single component
it('shows an inline error for an empty cart', function () {
    Livewire::visit(Checkout::class)
        ->click('@pay')
        ->assertSee('Your cart is empty');
});
```

Keep browser tests for a few high-value flows; everything else uses `Livewire::test()` (far faster).
