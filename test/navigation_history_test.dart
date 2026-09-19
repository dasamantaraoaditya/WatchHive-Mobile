import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:watchhive_mobile/core/router/navigation_history_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NavigationHistoryManager unit tests', () {
    late NavigationHistoryManager manager;

    setUp(() {
      manager = NavigationHistoryManager();
    });

    test('records routes in history', () {
      manager.recordLocation('/search');
      manager.recordLocation('/profile');

      expect(manager.history, equals(['/search', '/profile']));
    });

    test('avoids duplicate entries and keeps most recent', () {
      manager.recordLocation('/search');
      manager.recordLocation('/entries');
      manager.recordLocation('/search');

      expect(manager.history, equals(['/entries', '/search']));
    });

    test('ignores splash and auth routes', () {
      manager.recordLocation('/splash');
      manager.recordLocation('/login');
      manager.recordLocation('/signup');
      manager.recordLocation('/forgot-password');

      expect(manager.history, isEmpty);
    });

    test('navigating to /feed clears the history', () {
      manager.recordLocation('/search');
      manager.recordLocation('/entries');
      expect(manager.history.length, equals(2));

      manager.recordLocation('/feed');
      expect(manager.history, isEmpty);
    });

    test('clear() resets the history', () {
      manager.recordLocation('/search');
      manager.clear();
      expect(manager.history, isEmpty);
    });
  });

  group('NavigationHistoryManager handleBack widget tests', () {
    late NavigationHistoryManager manager;
    late GoRouter router;

    setUp(() {
      manager = NavigationHistoryManager();
      router = GoRouter(
        initialLocation: '/feed',
        routes: [
          GoRoute(
            path: '/feed',
            builder: (context, state) => const Scaffold(body: Text('Feed Screen')),
          ),
          GoRoute(
            path: '/search',
            builder: (context, state) => const Scaffold(body: Text('Search Screen')),
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) => const Scaffold(body: Text('Profile Screen')),
          ),
        ],
      );
    });

    testWidgets('navigates back to previous route when history is present', (tester) async {
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      // Navigate to /search and record
      router.go('/search');
      manager.recordLocation('/search');
      await tester.pumpAndSettle();

      // Navigate to /profile and record
      router.go('/profile');
      manager.recordLocation('/profile');
      await tester.pumpAndSettle();

      expect(find.text('Profile Screen'), findsOneWidget);

      // Handle back
      final element = tester.element(find.text('Profile Screen'));
      final handled = manager.handleBack(element);
      expect(handled, isTrue);

      await tester.pumpAndSettle();
      // Should have returned to /search
      expect(find.text('Search Screen'), findsOneWidget);
    });

    testWidgets('redirects to /feed when history is exhausted on non-feed screen', (tester) async {
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      // Navigate directly to /search without prior history
      router.go('/search');
      manager.recordLocation('/search');
      await tester.pumpAndSettle();

      expect(find.text('Search Screen'), findsOneWidget);

      final element = tester.element(find.text('Search Screen'));
      final handled = manager.handleBack(element);
      expect(handled, isTrue);

      await tester.pumpAndSettle();
      // Should redirect to /feed
      expect(find.text('Feed Screen'), findsOneWidget);
    });

    testWidgets('shows double-back SnackBar when on /feed', (tester) async {
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      expect(find.text('Feed Screen'), findsOneWidget);

      final element = tester.element(find.text('Feed Screen'));
      final handled = manager.handleBack(element);
      expect(handled, isTrue);

      await tester.pump();
      expect(find.text('Press back again to exit'), findsOneWidget);
    });

    testWidgets('calls SystemNavigator.pop on double press within 2s on /feed', (tester) async {
      int popCount = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (methodCall) async {
        if (methodCall.method == 'SystemNavigator.pop') {
          popCount++;
        }
        return null;
      });

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      final element = tester.element(find.text('Feed Screen'));

      // First press: shows snackbar
      manager.handleBack(element);
      await tester.pump();
      expect(popCount, equals(0));

      // Second press within 2s: invokes SystemNavigator.pop
      manager.handleBack(element);
      await tester.pump();
      expect(popCount, equals(1));

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });
  });
}
