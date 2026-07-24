# Pending Orders Query Example

## Extracted Query Class

```php
namespace App\Domain\Orders\Queries;

use App\Enums\OrderStatus;
use App\Models\Order;
use Illuminate\Contracts\Pagination\LengthAwarePaginator;
use Illuminate\Database\Eloquent\Builder;

final readonly class PendingOrdersQuery
{
    public function handle(?int $merchantId = null, int $perPage = 50): LengthAwarePaginator
    {
        return Order::query()
            ->with(['customer', 'payment'])
            ->whereIn('status', [
                OrderStatus::Pending,
                OrderStatus::PaymentFailed,
            ])
            ->where('created_at', '<=', now()->subMinutes(15))
            ->when(
                $merchantId !== null,
                fn (Builder $query) => $query->where('merchant_id', $merchantId),
            )
            ->latest()
            ->paginate($perPage);
    }
}
```

## Controller Usage

```php
namespace App\Http\Controllers\Admin;

use App\Domain\Orders\Queries\PendingOrdersQuery;
use Illuminate\Http\Request;
use Illuminate\View\View;

final class PendingOrdersController
{
    public function __invoke(Request $request, PendingOrdersQuery $query): View
    {
        $orders = $query->handle(
            merchantId: $request->integer('merchant_id') ?: null,
        );

        return view('admin.orders.pending', [
            'orders' => $orders,
        ]);
    }
}
```

## Returning a Builder

Return a builder when multiple callers need the same query rules with different terminal operations.

```php
namespace App\Domain\Articles\Queries;

use App\Models\Article;
use Illuminate\Database\Eloquent\Builder;

final readonly class PublishedArticlesQuery
{
    public function handle(): Builder
    {
        return Article::query()
            ->where('published_at', '<=', now())
            ->whereNull('archived_at')
            ->latest('published_at');
    }
}
```

Different callers can then choose their own terminal operation.

```php
$articles = $query->handle()->paginate(12);

$urls = $query->handle()->get();
```

## Write Query

Use a query class for writes only when the database operation itself is the named behavior.

```php
namespace App\Domain\Orders\Queries;

use App\Enums\OrderStatus;
use App\Models\Order;
use Carbon\CarbonImmutable;

final readonly class ExpireAbandonedOrdersQuery
{
    public function handle(CarbonImmutable $expiredBefore): int
    {
        return Order::query()
            ->where('status', OrderStatus::Pending)
            ->where('created_at', '<=', $expiredBefore)
            ->update([
                'status' => OrderStatus::Expired,
                'expired_at' => now(),
            ]);
    }
}
```

## Pest Test

```php
use App\Domain\Orders\Queries\PendingOrdersQuery;
use App\Enums\OrderStatus;
use App\Models\Merchant;
use App\Models\Order;
use Illuminate\Foundation\Testing\RefreshDatabase;

uses(RefreshDatabase::class);

it('returns only pending orders for the selected merchant', function (): void {
    $merchant = Merchant::factory()->create();
    $otherMerchant = Merchant::factory()->create();

    $pendingOrder = Order::factory()->create([
        'merchant_id' => $merchant->id,
        'status' => OrderStatus::Pending,
        'created_at' => now()->subDays(2),
    ]);

    $failedOrder = Order::factory()->create([
        'merchant_id' => $merchant->id,
        'status' => OrderStatus::PaymentFailed,
        'created_at' => now()->subDay(),
    ]);

    Order::factory()->create([
        'merchant_id' => $merchant->id,
        'status' => OrderStatus::Paid,
    ]);

    Order::factory()->create([
        'merchant_id' => $otherMerchant->id,
        'status' => OrderStatus::Pending,
    ]);

    $orders = new PendingOrdersQuery()->handle(
        merchantId: $merchant->id,
    );

    expect($orders)
        ->toHaveCount(2)
        ->sequence(
            fn ($order) => $order->is($pendingOrder)->toBeTrue(),
            fn ($order) => $order->is($failedOrder)->toBeTrue(),
        );
});
```
