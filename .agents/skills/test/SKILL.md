---
name: test
description: Guidelines and commands for executing Flutter unit, widget, and golden tests, with mocking strategies for Riverpod.
---

# Testing Skill — WatchHive Mobile

## Test Execution

### Running All Tests
```bash
flutter test
```

### Running a Specific Test File
```bash
flutter test test/features/entries/continue_watching_test.dart
```

### Code Analysis
Always ensure clean analysis before pushing:
```bash
flutter analyze
```

## Riverpod Testing Best Practices
- Use `ProviderContainer` with overridden providers for unit testing repositories and notifiers:
  ```dart
  final container = ProviderContainer(
    overrides: [
      apiClientProvider.overrideWithValue(mockApiClient),
    ],
  );
  addTearDown(container.dispose);
  ```
- Wrap widgets in `ProviderScope` when testing with `tester.pumpWidget()`.
