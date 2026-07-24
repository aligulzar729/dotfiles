# Eloquent Query Class Rules

## Core Rule

An Eloquent Query Class represents one named database query or one important database operation. It does not replace Eloquent. It gives important Eloquent logic a dedicated home.

## Extraction Checklist

Extract a query class when at least one of these is true:

- the same query appears in multiple controllers, jobs, commands, actions, exports, dashboards, or API endpoints
- the query has business meaning that deserves a clear name
- the query combines several optional filters
- the query controls eager loading for a specific use case
- the query returns aggregates or computed columns
- the query owns pagination, ordering, search, or report rules
- the query must be tested independently because wrong results are expensive
- the write operation has important database conditions that must stay consistent
- the model is accumulating too many large scopes or static query methods

Do not extract when:

- the query is simple and used once
- a local scope clearly expresses the reusable constraint
- the class name only restates an Eloquent method
- extraction makes the caller harder to understand
- the team has no repeated query pain yet

## Shape

- Use lowercase namespaces and paths that match the application's existing Laravel conventions.
- Prefer `app/Queries` for small applications.
- Prefer domain-specific query folders for domain-organized applications, such as `app/Domain/Orders/Queries`.
- Name classes after business questions or database use cases.
- End class names with `Query`.
- Prefer `final readonly class` when practical.
- Use one public method: `handle()`.
- Keep helper methods private.
- Type all parameters and return values.
- Accept optional filters through nullable typed parameters.

## Return Values

Execute inside `handle()` when the result type is part of the use case:

- `Collection`
- `LengthAwarePaginator`
- `Model|null`
- `int` for counts or affected rows
- `bool` for existence checks

Return an Eloquent `Builder` when multiple callers need the same query rules but different terminal operations.

Examples of valid caller-specific terminal operations:

- `paginate()` in a controller
- `get()` in an export or sitemap generator
- `count()` in a dashboard widget
- `exists()` in a guard or policy-like check

## Scope vs Query Class

Use a local scope for a reusable model constraint:

```php
Order::query()->needingAttention();
```

Use a query class for a complete database use case:

```php
new PendingOrdersQuery()->handle(merchantId: $merchantId);
```

Use both when useful. The scope can define the domain constraint while the query class coordinates eager loading, filters, ordering, and consumption rules.

## Write Queries

Query classes may write when the important part is the database operation itself.

Good fit:

```text
ExpireAbandonedOrdersQuery
DeleteStaleInvitationsQuery
MarkInvoicesAsOverdueQuery
```

Poor fit:

```text
ProcessOrderCheckoutQuery
RegisterCustomerQuery
SendInvoiceReminderQuery
```

If the operation coordinates business decisions, side effects, events, jobs, notifications, or multiple collaborators, prefer an action class.

## Repository Guardrail

Do not turn a query class into a repository.

Avoid generic methods like:

```php
find(int $id)
create(array $data)
update(Model $model, array $data)
delete(Model $model)
```

Avoid many public methods on one class. If more public methods seem necessary, split the behavior into multiple query classes.

## Testing Rules

- Test query behavior with factories and database tests.
- Assert included records, excluded records, ordering, and important filters.
- For writes, assert only intended records changed.
- Do not test Laravel's Eloquent internals.
- Avoid exhaustive filter matrix tests unless combinations are business-critical.
- Reconsider the abstraction when the query is too trivial to justify a focused test.
