# Networking Layer

## The Problem

Most Flutter apps use `http` or `Dio` directly in their code, copy-pasting the same headers, error handling, and serialization logic everywhere. When the API changes auth headers or you need to add retry logic, you touch 50 files.

## The Solution: A Configured API Client

### Base API Client

```dart
// core/network/api_client.dart
import 'package:dio/dio.dart';

class ApiClient {
  late final Dio _dio;
  
  ApiClient({required String baseUrl, required TokenStorage tokenStorage}) {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));
    
    // Order matters: interceptors run in order added
    _dio.interceptors.addAll([
      AuthInterceptor(tokenStorage),
      RetryInterceptor(_dio),
      LoggingInterceptor(),
    ]);
  }
  
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      return await _dio.get<T>(path, queryParameters: queryParameters);
    } on DioException catch (e) {
      throw _mapException(e);
    }
  }
  
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
  }) async {
    try {
      return await _dio.post<T>(path, data: data);
    } on DioException catch (e) {
      throw _mapException(e);
    }
  }
  
  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
  }) async {
    try {
      return await _dio.put<T>(path, data: data);
    } on DioException catch (e) {
      throw _mapException(e);
    }
  }
  
  Future<Response<T>> delete<T>(String path) async {
    try {
      return await _dio.delete<T>(path);
    } on DioException catch (e) {
      throw _mapException(e);
    }
  }
  
  AppException _mapException(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const TimeoutException();
      case DioExceptionType.connectionError:
        return const NetworkException();
      case DioExceptionType.badResponse:
        return _mapResponseError(e.response);
      default:
        return NetworkException('Unexpected error: ${e.message}');
    }
  }
  
  ApiException _mapResponseError(Response? response) {
    final statusCode = response?.statusCode ?? 500;
    final body = response?.data;
    
    if (body is Map<String, dynamic>) {
      return ApiException(
        statusCode,
        body['message'] as String? ?? 'Unknown error',
        code: body['code'] as String?,
      );
    }
    
    return ApiException(statusCode, 'Server error');
  }
}
```

### Auth Interceptor with Token Refresh

```dart
// core/network/interceptors/auth_interceptor.dart

class AuthInterceptor extends Interceptor {
  final TokenStorage _tokenStorage;
  
  AuthInterceptor(this._tokenStorage);
  
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final token = await _tokenStorage.getAccessToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }
  
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode != 401) {
      return handler.next(err);
    }
    
    // Try refreshing the token
    try {
      final refreshToken = await _tokenStorage.getRefreshToken();
      if (refreshToken == null) {
        return handler.next(err);  // No refresh token, propagate 401
      }
      
      // Use a separate Dio instance to avoid interceptor loop
      final refreshDio = Dio(BaseOptions(baseUrl: err.requestOptions.baseUrl));
      final response = await refreshDio.post('/auth/refresh', data: {
        'refresh_token': refreshToken,
      });
      
      final newAccessToken = response.data['access_token'];
      final newRefreshToken = response.data['refresh_token'];
      
      await _tokenStorage.saveTokens(
        accessToken: newAccessToken,
        refreshToken: newRefreshToken,
      );
      
      // Retry the original request with new token
      err.requestOptions.headers['Authorization'] = 'Bearer $newAccessToken';
      final retryResponse = await refreshDio.fetch(err.requestOptions);
      return handler.resolve(retryResponse);
      
    } catch (_) {
      // Refresh failed — clear tokens and propagate original error
      await _tokenStorage.clearTokens();
      return handler.next(err);
    }
  }
}
```

### Retry Interceptor

```dart
// core/network/interceptors/retry_interceptor.dart

class RetryInterceptor extends Interceptor {
  final Dio _dio;
  final int maxRetries;
  
  RetryInterceptor(this._dio, {this.maxRetries = 2});
  
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (!_shouldRetry(err)) {
      return handler.next(err);
    }
    
    final retryCount = err.requestOptions.extra['retryCount'] ?? 0;
    if (retryCount >= maxRetries) {
      return handler.next(err);
    }
    
    // Exponential backoff: 1s, 2s, 4s...
    await Future.delayed(Duration(seconds: 1 << retryCount));
    
    err.requestOptions.extra['retryCount'] = retryCount + 1;
    
    try {
      final response = await _dio.fetch(err.requestOptions);
      handler.resolve(response);
    } on DioException catch (e) {
      handler.next(e);
    }
  }
  
  bool _shouldRetry(DioException err) {
    // Only retry on network issues and server errors
    return err.type == DioExceptionType.connectionTimeout ||
           err.type == DioExceptionType.connectionError ||
           (err.response?.statusCode ?? 0) >= 500;
  }
}
```

### Centralized Endpoints

```dart
// core/network/api_endpoints.dart

class ApiEndpoints {
  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String refreshToken = '/auth/refresh';
  
  static String user(String id) => '/users/$id';
  static const String currentUser = '/users/me';
  
  static const String products = '/products';
  static String product(String id) => '/products/$id';
  
  static const String orders = '/orders';
  static String order(String id) => '/orders/$id';
}
```

## Usage in a Repository

```dart
class ProductRepositoryImpl implements ProductRepository {
  final ApiClient _api;
  
  ProductRepositoryImpl(this._api);
  
  @override
  Future<List<Product>> getProducts({int page = 1}) async {
    final response = await _api.get(
      ApiEndpoints.products,
      queryParameters: {'page': page, 'limit': 20},
    );
    
    return (response.data['items'] as List)
        .map((json) => Product.fromJson(json))
        .toList();
  }
  
  @override
  Future<Product> getProduct(String id) async {
    final response = await _api.get(ApiEndpoints.product(id));
    return Product.fromJson(response.data);
  }
}
```

Notice how clean the repository is — no error handling boilerplate, no auth headers, no retry logic. The API client handles all of that.
