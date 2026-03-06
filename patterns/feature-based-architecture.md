# Feature-Based Architecture

## The Problem

Most Flutter tutorials organize code by type:

```
lib/
├── models/
│   ├── user.dart
│   ├── product.dart
│   └── order.dart
├── screens/
│   ├── login_screen.dart
│   ├── product_screen.dart
│   └── order_screen.dart
├── services/
│   ├── auth_service.dart
│   ├── product_service.dart
│   └── order_service.dart
└── widgets/
    ├── user_avatar.dart
    ├── product_card.dart
    └── order_summary.dart
```

This falls apart when your app grows. To understand the "orders" feature, you're jumping between 4+ folders. Adding a feature means touching every directory. Deleting a feature is terrifying.

## The Solution: Organize by Feature

```
lib/
├── core/           # Shared infrastructure
├── shared/         # Reusable UI & utilities
└── features/
    ├── auth/
    │   ├── data/
    │   │   ├── auth_repository.dart
    │   │   └── models/
    │   │       └── user_model.dart
    │   ├── domain/
    │   │   └── auth_service.dart
    │   └── presentation/
    │       ├── login_screen.dart
    │       ├── login_cubit.dart
    │       └── widgets/
    │           └── login_form.dart
    │
    ├── products/
    │   ├── data/
    │   ├── domain/
    │   └── presentation/
    │
    └── orders/
        ├── data/
        ├── domain/
        └── presentation/
```

## The Three Layers

Each feature has three layers with clear responsibilities:

### `data/` — Where data comes from

Repositories, API models, local storage. This layer knows about HTTP, SQL, SharedPreferences. The rest of the app doesn't.

```dart
// features/auth/data/auth_repository.dart
abstract class AuthRepository {
  Future<User> login(String email, String password);
  Future<void> logout();
  Future<User?> getCurrentUser();
}

// features/auth/data/auth_repository_impl.dart
class AuthRepositoryImpl implements AuthRepository {
  final ApiClient _api;
  final SecureStorage _storage;
  
  AuthRepositoryImpl(this._api, this._storage);
  
  @override
  Future<User> login(String email, String password) async {
    final response = await _api.post('/auth/login', {
      'email': email,
      'password': password,
    });
    final token = response.data['token'];
    await _storage.write('auth_token', token);
    return User.fromJson(response.data['user']);
  }
}
```

### `domain/` — Business logic

Services, use cases, business rules. This layer orchestrates operations. No UI, no HTTP — just logic.

```dart
// features/auth/domain/auth_service.dart
class AuthService {
  final AuthRepository _authRepo;
  final AnalyticsService _analytics;
  
  AuthService(this._authRepo, this._analytics);
  
  Future<Result<User>> login(String email, String password) async {
    try {
      final user = await _authRepo.login(email, password);
      _analytics.trackLogin(user.id);
      return Result.success(user);
    } on UnauthorizedException {
      return Result.failure('Invalid email or password');
    } on NetworkException {
      return Result.failure('No internet connection');
    }
  }
}
```

### `presentation/` — UI

Screens, widgets, state management (Cubit/Bloc/Provider). This layer displays data and sends user actions to the domain layer.

```dart
// features/auth/presentation/login_cubit.dart
class LoginCubit extends Cubit<LoginState> {
  final AuthService _authService;
  
  LoginCubit(this._authService) : super(const LoginState.initial());
  
  Future<void> login(String email, String password) async {
    emit(const LoginState.loading());
    final result = await _authService.login(email, password);
    result.when(
      success: (user) => emit(LoginState.success(user)),
      failure: (message) => emit(LoginState.error(message)),
    );
  }
}
```

## Rules of Thumb

1. **Features don't import from other features' `data/` or `domain/`** — if two features need the same data, extract it to `core/` or create a shared service.

2. **`presentation/` depends on `domain/`, `domain/` depends on `data/`** — never the reverse. A repository should never import a widget.

3. **Each feature should be deletable** — if you can remove the `orders/` folder and the app still compiles (minus navigation), your architecture is clean.

4. **When a widget is used by only one feature**, it lives in that feature's `presentation/widgets/`. When it's used by multiple features, move it to `shared/widgets/`.
