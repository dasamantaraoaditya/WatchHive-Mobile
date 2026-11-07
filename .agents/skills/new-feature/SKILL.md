---
name: new-feature
description: Checklist and best practices for creating a new mobile feature module in watchhive_mobile following Riverpod and Clean Architecture patterns.
---

# New Feature Skill — WatchHive Mobile

## Architecture Checklist for New Mobile Features

When adding a new feature module under `lib/features/<feature_name>/`:

### 1. Data Models (`lib/shared/models/` or `lib/features/<feature>/models/`)
- Define immutable Dart class with `fromJson` and `toJson` methods.
- Provide sensible defaults or null safety for all fields.

### 2. API Endpoints (`lib/core/api/api_endpoints.dart`)
- Declare endpoint URL constant or helper function in `ApiEndpoints`.

### 3. Repository (`lib/features/<feature>/repositories/`)
- Inject `ApiClient` via Riverpod provider.
- Handle error parsing and fallback gracefully.

### 4. State Notifier / Provider (`lib/features/<feature>/providers/`)
- Use `AsyncNotifier<T>` or `FutureProvider<T>`.
- Implement optimistic UI updates where appropriate.

### 5. UI Screen & Widgets (`lib/features/<feature>/screens/` & `widgets/`)
- **Theme**: Always use `Theme.of(context)` and `AppColors` tokens.
- **Contrast**: Never put white text on gold or cream surfaces.
- **Loading State**: Render `WHSkeletonBox` while state is `AsyncLoading`.
- **Error State**: Render informative retry widget.

### 6. Router Integration (`lib/core/router/app_router.dart`)
- Add route to `GoRouter` routes list with normalized paths.
- Test deep link support if route should be accessible via web URL.
