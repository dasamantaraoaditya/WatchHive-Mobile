import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final navigationHistoryProvider = Provider<NavigationHistoryManager>((ref) {
  return NavigationHistoryManager();
});

class NavigationHistoryManager {
  final List<String> _history = [];
  bool _isNavigatingBack = false;
  DateTime? _lastBackPressTime;
  static const Duration _exitGracePeriod = Duration(seconds: 2);

  List<String> get history => List.unmodifiable(_history);

  /// Records a visited route location into the history stack.
  void recordLocation(String location) {
    // If this navigation was triggered by back navigation, don't re-push it
    if (_isNavigatingBack) {
      _isNavigatingBack = false;
      return;
    }

    // Ignore splash and auth routes
    if (location.isEmpty ||
        location == '/splash' ||
        location.startsWith('/login') ||
        location.startsWith('/signup') ||
        location.startsWith('/forgot-password')) {
      return;
    }

    // When explicitly navigating to /feed, clear tab history since Home is the base
    if (location == '/feed') {
      _history.clear();
      return;
    }

    // Remove any previous occurrence to avoid circular loops
    _history.remove(location);
    _history.add(location);
  }

  /// Clears the history stack.
  void clear() {
    _history.clear();
  }

  /// Handles back button press across tabs and screens.
  /// Returns true if the back press was handled.
  bool handleBack(BuildContext context) {
    // 1. If any modal, dialog, or nested route can pop, pop it!
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return true;
    }

    String currentLocation = '/feed';
    try {
      currentLocation = GoRouterState.of(context).matchedLocation;
    } catch (_) {
      try {
        currentLocation = GoRouter.of(context).routerDelegate.currentConfiguration.uri.path;
      } catch (_) {}
    }

    // 2. If user is NOT on the Home/Feed screen:
    if (currentLocation != '/feed') {
      // Remove current location if it is at the top of the stack
      if (_history.isNotEmpty && _history.last == currentLocation) {
        _history.removeLast();
      }

      // If there is a last visited screen in history, navigate to it
      if (_history.isNotEmpty) {
        final previousRoute = _history.removeLast();
        _isNavigatingBack = true;
        context.go(previousRoute);
        return true;
      } else {
        // No last screen in history: redirect to /feed as requested
        _isNavigatingBack = true;
        context.go('/feed');
        return true;
      }
    }

    // 3. User is already on Home/Feed (/feed) and there is no last screen:
    _history.clear();

    final now = DateTime.now();
    if (_lastBackPressTime == null || now.difference(_lastBackPressTime!) > _exitGracePeriod) {
      _lastBackPressTime = now;
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Press back again to exit',
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.fromLTRB(16, 0, 16, 76),
        ),
      );
      return true;
    }

    // Pressed again within 2 seconds: close the app
    SystemNavigator.pop();
    return true;
  }
}
