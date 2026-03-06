# State Management Comparison

## When to Use What

### setState + StatefulWidget
```dart
// Good for: ephemeral UI state (form input, animation, tab selection)
// Bad for: shared state, complex logic, testability
```
Use when state lives on a single screen and doesn't need testing or sharing.

### Provider + ChangeNotifier
```dart
class CartNotifier extends ChangeNotifier {
  final List<CartItem> _items = [];
  List<CartItem> get items => List.unmodifiable(_items);

  void addItem(CartItem item) {
    _items.add(item);
    notifyListeners();  // Rebuilds all listeners
  }
}
```
**Good for:** Simple apps, quick prototypes, shared state without much logic.
**Limitation:** `notifyListeners()` rebuilds all listeners — no granular updates.

### Cubit (flutter_bloc)
```dart
class CartCubit extends Cubit<CartState> {
  final CartRepository _repo;
  CartCubit(this._repo) : super(const CartState.initial());

  Future<void> addItem(Product product) async {
    emit(state.copyWith(isLoading: true));
    final result = await _repo.addItem(product);
    result.when(
      success: (cart) => emit(CartState.loaded(cart)),
      failure: (msg, _) => emit(CartState.error(msg)),
    );
  }
}
```
**Good for:** Most features. Clean, testable, good DevTools support.
**When to prefer Bloc over Cubit:** When you need event transformations (debounce, throttle, distinct events).

### Bloc (flutter_bloc)
```dart
class SearchBloc extends Bloc<SearchEvent, SearchState> {
  SearchBloc(this._repo) : super(const SearchState.initial()) {
    on<SearchQueryChanged>(_onQueryChanged,
      transformer: debounce(const Duration(milliseconds: 300)),
    );
  }

  Future<void> _onQueryChanged(SearchQueryChanged event, Emitter<SearchState> emit) async {
    final results = await _repo.search(event.query);
    emit(SearchState.loaded(results));
  }
}
```
**Good for:** Complex event processing, debounce/throttle, event replay for debugging.

### Riverpod
```dart
final cartProvider = StateNotifierProvider<CartNotifier, CartState>((ref) {
  final repo = ref.watch(cartRepositoryProvider);
  return CartNotifier(repo);
});

// Auto-disposes when no longer listened to
final productDetailProvider = FutureProvider.autoDispose.family<Product, String>((ref, id) {
  return ref.watch(productRepositoryProvider).getProduct(id);
});
```
**Good for:** Compile-time safety, auto-disposal, complex dependency graphs, when DI and state management should be unified.

## Decision Matrix

| Your Situation | Recommendation |
|---------------|---------------|
| Solo project, <10 screens | Provider or Cubit |
| Team project, 10-50 screens | Cubit (Bloc for complex features) |
| Large app, multiple teams | Riverpod or Bloc |
| Existing Provider codebase | Keep Provider, add Cubit for new features |
| Need debounce/throttle on events | Bloc |
| Need compile-time dependency safety | Riverpod |
