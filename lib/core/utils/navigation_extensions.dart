import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

extension SafeNavigationExtension on BuildContext {
  /// Safely pops the current route if possible; otherwise navigates to [fallbackRoute].
  /// Prevents [GoError: There is nothing to pop] when screens are opened directly.
  void safePop({String fallbackRoute = '/feed'}) {
    try {
      if (canPop()) {
        pop();
        return;
      }
    } catch (_) {
      // GoRouter not in context or cannot pop
    }

    try {
      if (Navigator.of(this).canPop()) {
        Navigator.of(this).pop();
        return;
      }
    } catch (_) {
      // Navigator not found
    }

    try {
      go(fallbackRoute);
    } catch (_) {
      // Fallback
    }
  }

  /// Safely checks if current context can pop without throwing if GoRouter is not available.
  bool get safeCanPop {
    try {
      if (canPop()) return true;
    } catch (_) {}
    try {
      if (Navigator.of(this).canPop()) return true;
    } catch (_) {}
    return false;
  }
}
