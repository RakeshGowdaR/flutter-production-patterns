# Service Layer

## The Problem

Repositories handle data access. But where do business rules go? Validation, orchestration across multiple repositories, error mapping, analytics — these don't belong in the UI or the repository.

## The Solution

A service sits between the presentation layer and the data layer. It orchestrates operations and applies business logic.

```
Presentation (Cubit) → Service → Repository → API / DB
```

```dart
class OrderService {
  final OrderRepository _orderRepo;
  final CartRepository _cartRepo;
  final PaymentRepository _paymentRepo;
  final AnalyticsService _analytics;

  OrderService(this._orderRepo, this._cartRepo, this._paymentRepo, this._analytics);

  Future<Result<Order>> placeOrder(Cart cart, PaymentMethod method) async {
    // Business rule: minimum order amount
    if (cart.total < 10.0) {
      return Result.failure('Minimum order is \$10');
    }

    // Business rule: max items per order
    if (cart.items.length > 50) {
      return Result.failure('Maximum 50 items per order');
    }

    try {
      // Orchestrate across multiple repositories
      final payment = await _paymentRepo.charge(method, cart.total);
      final order = await _orderRepo.create(cart, payment.id);
      await _cartRepo.clear();

      // Side effect: analytics
      _analytics.logEvent('order_placed', {'total': cart.total, 'items': cart.items.length});

      return Result.success(order);
    } on PaymentDeclinedException {
      return Result.failure('Payment was declined. Please try another method.');
    } on NetworkException {
      return Result.failure('Connection error. Please try again.');
    } catch (e) {
      ErrorHandler.report(e);
      return Result.failure('Something went wrong. Please try again.');
    }
  }
}
```

## Service vs Repository

| Responsibility | Repository | Service |
|---------------|-----------|---------|
| API calls | ✅ | ❌ |
| Database queries | ✅ | ❌ |
| Caching | ✅ | ❌ |
| Business validation | ❌ | ✅ |
| Orchestrating multiple repos | ❌ | ✅ |
| Error mapping to user messages | ❌ | ✅ |
| Analytics / side effects | ❌ | ✅ |
| Data transformation | Basic (JSON → model) | Business logic |

## When You Don't Need a Service

If your feature is simple CRUD with no business rules, the Cubit can call the repository directly. Don't add a service layer just for the sake of architecture. Add it when the logic justifies it.
