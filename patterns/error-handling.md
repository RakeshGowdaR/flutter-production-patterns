# Error Handling

## The Problem

Most Flutter apps handle errors like this:

```dart
// ❌ Catch-all that tells the user nothing useful
try {
  await api.createOrder(order);
} catch (e) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Something went wrong')),
  );
}
```

No distinction between network errors, validation errors, or server bugs. No logging. No recovery strategy.

## The Solution: Typed Exceptions + Result Type + Global Handler

### 1. Define Your Exception Hierarchy

```dart
// core/error/app_exception.dart

sealed class AppException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;
  
  const AppException(this.message, {this.code, this.originalError});
}

/// No internet or server unreachable
class NetworkException extends AppException {
  const NetworkException([String message = 'No internet connection'])
      : super(message);
}

/// Server returned an error (4xx, 5xx)
class ApiException extends AppException {
  final int statusCode;
  
  const ApiException(this.statusCode, String message, {String? code})
      : super(message, code: code);
  
  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;
  bool get isNotFound => statusCode == 404;
  bool get isServerError => statusCode >= 500;
}

/// Input validation failed
class ValidationException extends AppException {
  final Map<String, String> fieldErrors;
  
  const ValidationException(this.fieldErrors)
      : super('Validation failed');
}

/// Local storage / cache failure
class StorageException extends AppException {
  const StorageException([String message = 'Storage operation failed'])
      : super(message);
}

/// Operation timed out
class TimeoutException extends AppException {
  const TimeoutException([String message = 'Request timed out'])
      : super(message);
}
```

### 2. Use the Result Type for Error Propagation

Instead of throwing exceptions through your business logic, use a Result type:

```dart
// core/error/result.dart

sealed class Result<T> {
  const Result();
  
  factory Result.success(T data) = Success<T>;
  factory Result.failure(String message, {AppException? exception}) = Failure<T>;
  
  R when<R>({
    required R Function(T data) success,
    required R Function(String message, AppException? exception) failure,
  });
  
  bool get isSuccess => this is Success<T>;
  bool get isFailure => this is Failure<T>;
  
  T? get dataOrNull => switch (this) {
    Success(:final data) => data,
    Failure() => null,
  };
}

class Success<T> extends Result<T> {
  final T data;
  const Success(this.data);
  
  @override
  R when<R>({
    required R Function(T data) success,
    required R Function(String message, AppException? exception) failure,
  }) => success(data);
}

class Failure<T> extends Result<T> {
  final String message;
  final AppException? exception;
  const Failure(this.message, {this.exception});
  
  @override
  R when<R>({
    required R Function(T data) success,
    required R Function(String message, AppException? exception) failure,
  }) => failure(message, exception);
}
```

### 3. Convert Exceptions in the Repository Layer

```dart
// core/network/api_client.dart

class ApiClient {
  final Dio _dio;
  
  Future<Response> get(String path, {Map<String, dynamic>? queryParameters}) async {
    try {
      return await _dio.get(path, queryParameters: queryParameters);
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }
  
  AppException _mapDioException(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const TimeoutException();
      
      case DioExceptionType.connectionError:
        return const NetworkException();
      
      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode ?? 500;
        final body = e.response?.data;
        final message = body is Map ? body['message'] ?? 'Server error' : 'Server error';
        final code = body is Map ? body['code'] : null;
        return ApiException(statusCode, message, code: code);
      
      default:
        return NetworkException('Unexpected error: ${e.message}');
    }
  }
}
```

### 4. Service Layer Returns Results

```dart
class OrderService {
  final OrderRepository _orderRepo;
  
  Future<Result<Order>> placeOrder(Cart cart) async {
    if (cart.items.isEmpty) {
      return const Result.failure('Your cart is empty');
    }
    
    try {
      final order = await _orderRepo.createOrder(
        CreateOrderRequest.fromCart(cart),
      );
      return Result.success(order);
    } on ApiException catch (e) {
      if (e.code == 'INSUFFICIENT_STOCK') {
        return Result.failure('Some items are no longer in stock');
      }
      return Result.failure('Could not place order. Please try again.');
    } on NetworkException {
      return Result.failure('No internet connection. Please check and try again.');
    } on TimeoutException {
      return Result.failure('Request timed out. Please try again.');
    } catch (e) {
      // Unexpected error — log it
      ErrorHandler.report(e);
      return Result.failure('An unexpected error occurred');
    }
  }
}
```

### 5. UI Handles Results Cleanly

```dart
class CheckoutCubit extends Cubit<CheckoutState> {
  final OrderService _orderService;
  
  Future<void> checkout(Cart cart) async {
    emit(const CheckoutState.loading());
    
    final result = await _orderService.placeOrder(cart);
    
    result.when(
      success: (order) => emit(CheckoutState.success(order)),
      failure: (message, _) => emit(CheckoutState.error(message)),
    );
  }
}

// In the widget — clean and simple
BlocListener<CheckoutCubit, CheckoutState>(
  listener: (context, state) {
    if (state is CheckoutError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(state.message)),  // User-friendly message
      );
    }
    if (state is CheckoutSuccess) {
      Navigator.pushNamed(context, '/order-confirmation');
    }
  },
)
```

### 6. Global Error Handler for Uncaught Errors

```dart
// core/error/error_handler.dart
class ErrorHandler {
  static void init() {
    // Catch Flutter framework errors
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      report(details.exception, details.stack);
    };
    
    // Catch async errors not handled by Flutter
    PlatformDispatcher.instance.onError = (error, stack) {
      report(error, stack);
      return true;
    };
  }
  
  static void report(dynamic error, [StackTrace? stack]) {
    // In debug mode, print to console
    if (kDebugMode) {
      debugPrint('ERROR: $error');
      if (stack != null) debugPrint('$stack');
      return;
    }
    
    // In production, send to crash reporting service
    // FirebaseCrashlytics.instance.recordError(error, stack);
    // Sentry.captureException(error, stackTrace: stack);
  }
}
```

## The Flow

```
User Action
    ↓
Presentation (Cubit/Bloc) calls Service
    ↓
Service calls Repository → catches AppException → returns Result<T>
    ↓
Repository calls ApiClient → catches DioException → throws AppException
    ↓
Presentation reads Result → emits UI state with user-friendly message
```

Every layer has a clear job. Errors are converted to user-friendly messages exactly once, in the service layer. The UI never sees raw exceptions.
