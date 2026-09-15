import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watchhive_mobile/features/auth/providers/auth_provider.dart';
import 'package:watchhive_mobile/features/auth/screens/login_screen.dart';
import 'package:watchhive_mobile/features/auth/screens/splash_screen.dart';
import 'package:watchhive_mobile/shared/models/user.dart';

class MockLoadingAuthNotifier extends AuthNotifier {
  final Completer<AuthState> completer;
  MockLoadingAuthNotifier(this.completer);

  @override
  Future<AuthState> build() => completer.future;
}

class MockUnauthenticatedAuthNotifier extends AuthNotifier {
  @override
  Future<AuthState> build() async => const AuthState(isAuthenticated: false);
}

class MockAuthenticatedAuthNotifier extends AuthNotifier {
  @override
  Future<AuthState> build() async => AuthState(
        user: User(
          id: 'u-1',
          username: 'moviefan',
          email: 'fan@watchhive.com',
          createdAt: DateTime(2025, 1, 1),
        ),
        isAuthenticated: true,
      );
}

void main() {
  group('SplashScreen Session Restoration Tests', () {
    testWidgets('Displays "Signing you in..." loader while authState is loading in background',
        (tester) async {
      final completer = Completer<AuthState>();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateProvider.overrideWith(() => MockLoadingAuthNotifier(completer)),
          ],
          child: const MaterialApp(
            home: SplashScreen(),
          ),
        ),
      );

      // Verify WatchHive branding
      expect(find.text('WatchHive'), findsOneWidget);
      expect(find.text('Track Movies, Anime, K-Drama & Series'), findsOneWidget);

      // Verify loader indicator and "Signing you in..." text are present
      expect(find.text('Signing you in...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Complete the auth check
      completer.complete(const AuthState(isAuthenticated: true));
      await tester.pump();
    });

    testWidgets('Does not show "Signing you in..." loader once session check has completed',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateProvider.overrideWith(MockUnauthenticatedAuthNotifier.new),
          ],
          child: const MaterialApp(
            home: SplashScreen(),
          ),
        ),
      );

      await tester.pump();

      // "Signing you in..." should not be displayed when auth is no longer loading
      expect(find.text('Signing you in...'), findsNothing);
      expect(find.text('WatchHive'), findsOneWidget);
    });
  });

  group('LoginScreen Auto-Login Safeguard Tests', () {
    testWidgets('Displays signing in loader if background auto-login is active on LoginScreen',
        (tester) async {
      final completer = Completer<AuthState>();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateProvider.overrideWith(() => MockLoadingAuthNotifier(completer)),
          ],
          child: const MaterialApp(
            home: LoginScreen(),
          ),
        ),
      );

      // Should show the reassuring loader rather than the login form
      expect(find.text('Signing you in...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      // Login form inputs should not be visible to confuse the user
      expect(find.text('Welcome back'), findsNothing);
      expect(find.text('Sign In'), findsNothing);

      // Complete the auth check
      completer.complete(const AuthState(isAuthenticated: false));
      await tester.pump();
    });

    testWidgets('Displays normal login form when user is unauthenticated and not loading',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateProvider.overrideWith(MockUnauthenticatedAuthNotifier.new),
          ],
          child: const MaterialApp(
            home: LoginScreen(),
          ),
        ),
      );

      await tester.pump();

      // Normal login form must be visible
      expect(find.text('Welcome back'), findsOneWidget);
      expect(find.text('Sign in to continue tracking'), findsOneWidget);
      expect(find.text('Sign In'), findsOneWidget);
      expect(find.text('Signing you in...'), findsNothing);
    });
  });
}
