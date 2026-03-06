# Environment Config

## The Problem

Hardcoded values scattered across the codebase:

```dart
// ❌ Hardcoded — can't switch between dev/staging/prod
final apiUrl = 'https://api.myapp.com';
final stripeKey = 'pk_live_abc123';
```

## The Solution: Compile-Time Configuration

### Define Environments

```dart
// core/config/environment.dart
enum Env { dev, staging, prod }

class Environment {
  static late Env current;
  static late String apiBaseUrl;
  static late String stripeKey;
  static late bool enableLogging;

  static void init(Env env) {
    current = env;
    switch (env) {
      case Env.dev:
        apiBaseUrl = 'http://localhost:8080';
        stripeKey = 'pk_test_dev123';
        enableLogging = true;
      case Env.staging:
        apiBaseUrl = 'https://staging-api.myapp.com';
        stripeKey = 'pk_test_staging456';
        enableLogging = true;
      case Env.prod:
        apiBaseUrl = 'https://api.myapp.com';
        stripeKey = 'pk_live_prod789';
        enableLogging = false;
    }
  }
}
```

### Multiple Entry Points

```dart
// lib/main_dev.dart
void main() {
  Environment.init(Env.dev);
  runApp(const MyApp());
}

// lib/main_staging.dart
void main() {
  Environment.init(Env.staging);
  runApp(const MyApp());
}

// lib/main_prod.dart
void main() {
  Environment.init(Env.prod);
  runApp(const MyApp());
}
```

### Run with Flavor

```bash
# Development
flutter run -t lib/main_dev.dart

# Staging
flutter run -t lib/main_staging.dart

# Production
flutter run -t lib/main_prod.dart --release
```

### Using Dart Defines (Alternative)

```bash
flutter run --dart-define=ENV=dev --dart-define=API_URL=http://localhost:8080
```

```dart
class Environment {
  static const env = String.fromEnvironment('ENV', defaultValue: 'dev');
  static const apiUrl = String.fromEnvironment('API_URL', defaultValue: 'http://localhost:8080');
}
```

## Rules

1. **Never commit secrets** — API keys, signing keys, and tokens should come from CI/CD environment variables or secret managers, not source code.
2. **Don't use `--dart-define` for secrets** — They're embedded in the binary and can be extracted.
3. **Use Firebase Remote Config or similar** for values that change without a deploy (feature flags, maintenance mode).
4. **Always have a dev/staging environment** — Never test against production.
