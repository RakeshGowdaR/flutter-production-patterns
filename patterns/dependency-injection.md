# Dependency Injection

## The Problem

Without DI, classes create their own dependencies:

```dart
// ❌ Hard-coded dependencies — impossible to test
class OrderCubit extends Cubit<OrderState> {
  final _orderService = OrderService(
    OrderRepositoryImpl(ApiClient(Dio())),  // deeply nested
    CartRepositoryImpl(ApiClient(Dio())),   // another Dio instance?
  );
}
```

You can't mock anything. You can't swap implementations. Every class creates a web of dependencies.

## The Solution: get_it (Service Locator)

```dart
// core/di/injection.dart
import 'package:get_it/get_it.dart';

final getIt = GetIt.instance;

void setupDependencies() {
  // Core
  getIt.registerLazySingleton<Dio>(() => Dio(BaseOptions(baseUrl: Environment.apiUrl)));
  getIt.registerLazySingleton<ApiClient>(() => ApiClient(getIt<Dio>()));
  getIt.registerLazySingleton<SecureStorage>(() => SecureStorage(FlutterSecureStorage()));

  // Repositories
  getIt.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(getIt<ApiClient>(), getIt<SecureStorage>()),
  );
  getIt.registerLazySingleton<OrderRepository>(
    () => OrderRepositoryImpl(getIt<ApiClient>()),
  );

  // Services
  getIt.registerLazySingleton<AuthService>(
    () => AuthService(getIt<AuthRepository>()),
  );

  // Cubits — registered as factory (new instance each time)
  getIt.registerFactory<LoginCubit>(
    () => LoginCubit(getIt<AuthService>()),
  );
}
```

```dart
// main.dart
void main() {
  setupDependencies();
  runApp(const MyApp());
}

// Usage in widgets
BlocProvider(
  create: (context) => getIt<LoginCubit>(),
  child: const LoginScreen(),
)
```

## Registration Types

| Type | When | Example |
|------|------|---------|
| `registerSingleton` | Created immediately, one instance forever | Database, Analytics |
| `registerLazySingleton` | Created on first use, one instance forever | ApiClient, Repositories |
| `registerFactory` | New instance every time | Cubits, ViewModels |

## For Testing

```dart
// In test setup — replace real implementations with mocks
void setupTestDependencies() {
  getIt.registerLazySingleton<AuthRepository>(() => MockAuthRepository());
  getIt.registerLazySingleton<OrderRepository>(() => MockOrderRepository());
}
```

## Rule of Thumb

- **Singletons** for infrastructure (HTTP client, database, storage)
- **Lazy singletons** for repositories and services (created once when first needed)
- **Factories** for cubits/blocs (fresh state per screen)
