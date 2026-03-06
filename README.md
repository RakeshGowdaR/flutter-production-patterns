# 🦋 Flutter Production Patterns

Battle-tested patterns and architectures used in scalable Flutter applications. Not another todo app tutorial — these are the patterns you need when your app has real users, real complexity, and real deadlines.

---

## Who This Is For

You know Flutter basics. You can build a screen. But you're asking questions like:

- "How do I structure a 50+ screen app without it becoming spaghetti?"
- "Where do API calls go? Who owns the state?"
- "How do I write code that another developer can understand in 6 months?"
- "What does production-ready Flutter actually look like?"

This repo answers those questions with code, not theory.

---

## Table of Contents

### Architecture

| Pattern | What It Solves |
|---------|---------------|
| [Feature-Based Architecture](patterns/feature-based-architecture.md) | Organizing code by feature instead of by type |
| [Repository Pattern](patterns/repository-pattern.md) | Separating data sources from business logic |
| [Service Layer](patterns/service-layer.md) | Reusable business operations across features |
| [Dependency Injection](patterns/dependency-injection.md) | Testable, swappable dependencies without globals |

### State Management

| Pattern | What It Solves |
|---------|---------------|
| [State Management Comparison](patterns/state-management.md) | When to use what: Provider vs Riverpod vs Bloc |
| [Separation of UI and Logic](patterns/ui-logic-separation.md) | Keeping widgets thin and logic testable |

### Production Essentials

| Pattern | What It Solves |
|---------|---------------|
| [Error Handling](patterns/error-handling.md) | Typed errors, global handlers, user-facing messages |
| [Networking Layer](patterns/networking-layer.md) | Dio setup, interceptors, retry logic, offline support |
| [Testing Strategy](patterns/testing-strategy.md) | What to test, how to test it, and what to skip |
| [Environment Config](patterns/environment-config.md) | Managing dev/staging/prod without hardcoded values |

### Code Examples

```
examples/
├── repository_pattern/
│   ├── user_repository.dart           # Abstract + concrete implementations
│   ├── user_repository_impl.dart      # API-backed implementation
│   └── mock_user_repository.dart      # For testing
├── state_management/
│   ├── auth_cubit.dart                # Cubit-based auth state
│   └── auth_state.dart                # Typed, immutable states
├── error_handling/
│   ├── app_exception.dart             # Typed exception hierarchy
│   ├── error_handler.dart             # Global error handling
│   └── result.dart                    # Result<T> type for error propagation
├── networking/
│   ├── api_client.dart                # Configured Dio instance
│   ├── auth_interceptor.dart          # Token refresh interceptor
│   └── api_response.dart              # Typed API responses
└── testing/
    ├── widget_test_example.dart       # Testing widgets with mocked deps
    └── repository_test_example.dart   # Testing data layer
```

---

## Project Structure

The recommended structure for a production Flutter app:

```
lib/
├── app/
│   ├── app.dart                  # MaterialApp, routing, global providers
│   └── app_theme.dart            # Centralized theme definition
│
├── core/
│   ├── network/
│   │   ├── api_client.dart       # Dio configuration
│   │   ├── api_endpoints.dart    # All endpoint URLs in one place
│   │   └── interceptors/        
│   ├── storage/
│   │   ├── local_storage.dart    # SharedPreferences wrapper
│   │   └── secure_storage.dart   # For tokens, sensitive data
│   ├── error/
│   │   ├── app_exception.dart    # Exception types
│   │   └── error_handler.dart    # Global error handling
│   └── di/
│       └── injection.dart        # Dependency injection setup
│
├── features/
│   ├── auth/
│   │   ├── data/
│   │   │   ├── auth_repository.dart
│   │   │   └── models/
│   │   ├── domain/
│   │   │   └── auth_service.dart
│   │   └── presentation/
│   │       ├── login_screen.dart
│   │       ├── login_cubit.dart
│   │       └── widgets/
│   │
│   ├── home/
│   │   ├── data/
│   │   ├── domain/
│   │   └── presentation/
│   │
│   └── profile/
│       ├── data/
│       ├── domain/
│       └── presentation/
│
└── shared/
    ├── widgets/                   # Reusable UI components
    ├── extensions/                # Dart extensions
    ├── constants/                 # App-wide constants
    └── utils/                     # Helper functions
```

### Why This Structure?

**Feature-based** (not layer-based): Everything related to "auth" is in `features/auth/`. You don't have to jump between 5 folders to understand one feature.

**data → domain → presentation**: Each feature follows a clear flow. Data layer fetches, domain layer processes, presentation layer displays.

**core/**: Shared infrastructure that isn't specific to any feature. Network, storage, error handling — the plumbing.

**shared/**: Reusable pieces that multiple features use. Widgets, extensions, constants.

---

## Quick Start

1. **New to architecture?** Start with [Feature-Based Architecture](patterns/feature-based-architecture.md) and [Repository Pattern](patterns/repository-pattern.md)

2. **Setting up a new project?** Read the patterns in order — they build on each other

3. **Refactoring an existing app?** Start with [Error Handling](patterns/error-handling.md) and [Networking Layer](patterns/networking-layer.md) — highest ROI improvements

---

## Contributing

Have a pattern that saved your team? Found a better way to handle something? PRs welcome.

Guidelines:
- Include a real problem statement (not just "here's a pattern")
- Show both the naive approach and the production approach
- Include Dart code that compiles
- Keep explanations concise — developers read code, not essays

---

## License

MIT
