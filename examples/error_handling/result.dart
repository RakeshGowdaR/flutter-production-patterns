/// Result type for explicit error handling without exceptions.
sealed class Result<T> {
  const Result();
  factory Result.success(T data) = Success<T>;
  factory Result.failure(String message, {Exception? exception}) = Failure<T>;

  R when<R>({
    required R Function(T data) success,
    required R Function(String message, Exception? exception) failure,
  });

  bool get isSuccess => this is Success<T>;
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
    required R Function(String message, Exception? exception) failure,
  }) => success(data);
}

class Failure<T> extends Result<T> {
  final String message;
  final Exception? exception;
  const Failure(this.message, {this.exception});

  @override
  R when<R>({
    required R Function(T data) success,
    required R Function(String message, Exception? exception) failure,
  }) => failure(message, exception);
}
