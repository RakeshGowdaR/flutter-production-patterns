# Testing Strategy

## The Testing Pyramid

```
        /  E2E Tests  \          Few, slow, expensive
       / Integration   \         Some, medium speed
      /   Unit Tests    \        Many, fast, cheap
     ──────────────────────
```

## What to Test at Each Level

### Unit Tests (70% of tests)
Test business logic in isolation. No Flutter, no UI, no network.

```dart
// Test the service logic
void main() {
  late OrderService orderService;
  late MockOrderRepository mockOrderRepo;

  setUp(() {
    mockOrderRepo = MockOrderRepository();
    orderService = OrderService(mockOrderRepo);
  });

  test('placeOrder fails when cart is empty', () async {
    final cart = Cart(items: []);
    final result = await orderService.placeOrder(cart);
    expect(result.isFailure, true);
  });

  test('placeOrder succeeds with valid cart', () async {
    final cart = Cart(items: [CartItem(product: testProduct, qty: 1)]);
    when(() => mockOrderRepo.create(any())).thenAnswer((_) async => testOrder);

    final result = await orderService.placeOrder(cart);
    expect(result.isSuccess, true);
  });
}
```

**Test:** Services, repositories (with mocked data sources), utilities, models, cubits.

### Widget Tests (20% of tests)
Test that widgets render correctly for each state.

```dart
void main() {
  testWidgets('shows loading indicator when state is loading', (tester) async {
    final cubit = MockCheckoutCubit();
    when(() => cubit.state).thenReturn(const CheckoutState.loading());

    await tester.pumpWidget(
      BlocProvider<CheckoutCubit>.value(
        value: cubit,
        child: const MaterialApp(home: CheckoutScreen()),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('shows error message when state is error', (tester) async {
    final cubit = MockCheckoutCubit();
    when(() => cubit.state).thenReturn(const CheckoutState.error('Payment failed'));

    await tester.pumpWidget(/* ... */);
    expect(find.text('Payment failed'), findsOneWidget);
  });
}
```

### Integration / E2E Tests (10% of tests)
Test full user flows. Use `integration_test` package.

```dart
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('user can log in and see home screen', (tester) async {
    app.main();
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(Key('email')), 'test@example.com');
    await tester.enterText(find.byKey(Key('password')), 'password123');
    await tester.tap(find.byKey(Key('login_button')));
    await tester.pumpAndSettle();

    expect(find.text('Welcome'), findsOneWidget);
  });
}
```

## What NOT to Test

- **Flutter framework behavior** — Don't test that `Text` widget renders text.
- **Third-party packages** — Don't test that Dio makes HTTP calls.
- **Trivial getters/setters** — Don't test `user.name` returns the name.
- **UI pixel positions** — Fragile, breaks on every design change.

## What to ALWAYS Test

- **Business rules** — Validation, calculations, state transitions
- **Edge cases** — Empty lists, null values, network errors, boundary values
- **Cubits/Blocs** — Every state transition for every action
- **Error paths** — What happens when things fail
