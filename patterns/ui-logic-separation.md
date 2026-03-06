# Separation of UI and Logic

## The Problem

Fat widgets that mix UI code with business logic:

```dart
// ❌ Everything in one widget
class CheckoutScreen extends StatefulWidget {
  @override
  _CheckoutScreenState createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  bool isLoading = false;
  String? error;
  Order? order;

  Future<void> _checkout() async {
    setState(() { isLoading = true; error = null; });

    try {
      // Business logic in widget
      if (cart.items.isEmpty) throw Exception('Cart is empty');
      if (cart.total < 10) throw Exception('Minimum \$10');

      // API call in widget
      final response = await http.post(Uri.parse('$baseUrl/orders'), body: cart.toJson());
      final order = Order.fromJson(jsonDecode(response.body));

      setState(() { this.order = order; isLoading = false; });
    } catch (e) {
      setState(() { error = e.toString(); isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    // 200 lines of UI mixed with state management
  }
}
```

This is untestable, unreusable, and unmaintainable.

## The Fix: Thin Widgets + Fat Cubits

### The Cubit (owns all logic)

```dart
class CheckoutCubit extends Cubit<CheckoutState> {
  final OrderService _orderService;

  CheckoutCubit(this._orderService) : super(const CheckoutState.initial());

  Future<void> checkout(Cart cart) async {
    emit(const CheckoutState.loading());

    final result = await _orderService.placeOrder(cart);
    result.when(
      success: (order) => emit(CheckoutState.success(order)),
      failure: (msg, _) => emit(CheckoutState.error(msg)),
    );
  }
}
```

### The Widget (only UI)

```dart
class CheckoutScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CheckoutCubit, CheckoutState>(
      listener: (context, state) {
        if (state is CheckoutSuccess) {
          Navigator.pushNamed(context, '/order-confirmation');
        }
        if (state is CheckoutError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message)),
          );
        }
      },
      builder: (context, state) {
        if (state is CheckoutLoading) return const LoadingIndicator();
        return CheckoutForm(
          onSubmit: () => context.read<CheckoutCubit>().checkout(cart),
        );
      },
    );
  }
}
```

## The Rule

**Widget responsibilities:** Render UI, delegate actions to Cubit, show state.
**Cubit responsibilities:** Hold state, execute logic, call services, emit new state.

**Test the Cubit** (unit tests, fast, no Flutter dependency).
**Test the Widget** (widget tests, verify it renders correctly for each state).
