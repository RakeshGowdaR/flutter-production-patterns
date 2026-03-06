# Repository Pattern

## The Problem

When API calls are scattered across widgets and state management classes, you get:

```dart
// ❌ API calls in the widget
class ProfileScreen extends StatefulWidget {
  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  User? user;
  
  @override
  void initState() {
    super.initState();
    _loadUser();
  }
  
  Future<void> _loadUser() async {
    // HTTP details leaked into UI code
    final response = await http.get(
      Uri.parse('https://api.example.com/users/me'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) {
      setState(() {
        user = User.fromJson(jsonDecode(response.body));
      });
    }
    // What about errors? Caching? Offline? Token refresh?
  }
}
```

Problems: untestable, duplicate API calls everywhere, no caching, impossible to swap data sources.

## The Solution: Repository Pattern

A repository is an **abstraction over data sources**. The rest of your app asks for data — the repository decides where it comes from (API, cache, local DB).

### Step 1: Define the Contract (Abstract Class)

```dart
// features/profile/data/user_repository.dart
abstract class UserRepository {
  Future<User> getUser(String id);
  Future<User> updateUser(String id, UpdateUserRequest request);
  Future<List<User>> searchUsers(String query);
  Future<void> deleteAccount();
}
```

### Step 2: Implement It

```dart
// features/profile/data/user_repository_impl.dart
class UserRepositoryImpl implements UserRepository {
  final ApiClient _api;
  final LocalStorage _cache;
  
  UserRepositoryImpl(this._api, this._cache);
  
  @override
  Future<User> getUser(String id) async {
    // Try cache first
    final cached = await _cache.get<User>('user_$id');
    if (cached != null) return cached;
    
    // Fetch from API
    try {
      final response = await _api.get('/users/$id');
      final user = User.fromJson(response.data);
      
      // Update cache
      await _cache.set('user_$id', user, ttl: Duration(minutes: 5));
      return user;
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionError) {
        // Offline — return stale cache if available
        final stale = await _cache.get<User>('user_$id', ignoreExpiry: true);
        if (stale != null) return stale;
      }
      rethrow;
    }
  }
  
  @override
  Future<User> updateUser(String id, UpdateUserRequest request) async {
    final response = await _api.put('/users/$id', data: request.toJson());
    final user = User.fromJson(response.data);
    await _cache.set('user_$id', user, ttl: Duration(minutes: 5));
    return user;
  }
  
  @override
  Future<List<User>> searchUsers(String query) async {
    final response = await _api.get('/users/search', queryParameters: {'q': query});
    return (response.data as List).map((json) => User.fromJson(json)).toList();
  }
  
  @override
  Future<void> deleteAccount() async {
    await _api.delete('/users/me');
    await _cache.clear();
  }
}
```

### Step 3: Create a Mock for Testing

```dart
// features/profile/data/mock_user_repository.dart
class MockUserRepository implements UserRepository {
  final User _fakeUser = User(
    id: 'test-1',
    name: 'Test User',
    email: 'test@example.com',
  );
  
  @override
  Future<User> getUser(String id) async => _fakeUser;
  
  @override
  Future<User> updateUser(String id, UpdateUserRequest request) async {
    return _fakeUser.copyWith(name: request.name);
  }
  
  @override
  Future<List<User>> searchUsers(String query) async => [_fakeUser];
  
  @override
  Future<void> deleteAccount() async {}
}
```

### Step 4: Use It

```dart
// features/profile/presentation/profile_cubit.dart
class ProfileCubit extends Cubit<ProfileState> {
  final UserRepository _userRepo;  // Depends on abstraction, not implementation
  
  ProfileCubit(this._userRepo) : super(const ProfileState.loading());
  
  Future<void> loadProfile(String userId) async {
    try {
      final user = await _userRepo.getUser(userId);
      emit(ProfileState.loaded(user));
    } catch (e) {
      emit(ProfileState.error('Failed to load profile'));
    }
  }
}
```

## Why This Matters

| Without Repository | With Repository |
|-------------------|----------------|
| API details leaked everywhere | API details in one place |
| Can't test without real API | Mock the repository easily |
| Can't add caching without changing UI | Add caching inside repository |
| Switching APIs = rewrite | Swap implementation, same interface |
| Offline mode = impossible | Repository decides cache vs API |

## Common Mistake: Repositories That Do Too Much

A repository should only handle **data access**. Business logic belongs in services:

```dart
// ❌ Business logic in repository
class OrderRepository {
  Future<Order> createOrder(Cart cart) async {
    // Validating business rules — doesn't belong here
    if (cart.items.isEmpty) throw Exception('Cart is empty');
    if (cart.total < 10) throw Exception('Minimum order is $10');
    
    // Applying discounts — business logic, not data access
    final discount = _calculateLoyaltyDiscount(cart);
    
    final response = await _api.post('/orders', data: cart.toJson());
    return Order.fromJson(response.data);
  }
}

// ✅ Repository only handles data, service handles logic
class OrderRepository {
  Future<Order> createOrder(CreateOrderRequest request) async {
    final response = await _api.post('/orders', data: request.toJson());
    return Order.fromJson(response.data);
  }
}

class OrderService {
  final OrderRepository _orderRepo;
  final DiscountService _discountService;
  
  Future<Result<Order>> placeOrder(Cart cart) async {
    if (cart.items.isEmpty) return Result.failure('Cart is empty');
    if (cart.total < 10) return Result.failure('Minimum order is \$10');
    
    final discount = await _discountService.calculateDiscount(cart);
    final request = CreateOrderRequest.fromCart(cart, discount: discount);
    
    try {
      final order = await _orderRepo.createOrder(request);
      return Result.success(order);
    } catch (e) {
      return Result.failure('Failed to place order');
    }
  }
}
```
