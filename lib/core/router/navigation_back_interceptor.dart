import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_router.dart';
import 'navigation_history_manager.dart';

/// Global widget that intercepts the Android system back button / back gesture
/// through [WidgetsBindingObserver.didPopRoute].
/// Ensures that when the user presses back, the app never exits prematurely from
/// secondary tabs or screens, instead traversing visited history or returning to /feed.
class NavigationBackInterceptor extends ConsumerStatefulWidget {
  final Widget child;
  const NavigationBackInterceptor({super.key, required this.child});

  @override
  ConsumerState<NavigationBackInterceptor> createState() =>
      _NavigationBackInterceptorState();
}

class _NavigationBackInterceptorState extends ConsumerState<NavigationBackInterceptor>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Future<bool> didPopRoute() async {
    // 1. Give the root navigator (dialogs, bottom sheets, active PopScope) first chance to pop
    final rootNav = rootNavigatorKey.currentState;
    if (rootNav != null) {
      final handled = await rootNav.maybePop();
      if (handled) return true;
    }

    // 2. Delegate to NavigationHistoryManager for tab backtracking and double-exit protection
    if (!mounted) return false;
    final context = rootNavigatorKey.currentContext;
    if (context != null && context.mounted) {
      return ref.read(navigationHistoryProvider).handleBack(context);
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
