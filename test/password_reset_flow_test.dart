import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watchhive_mobile/features/auth/repositories/auth_repository.dart';
import 'package:watchhive_mobile/features/auth/screens/forgot_password_screen.dart';
import 'package:watchhive_mobile/features/auth/screens/reset_password_screen.dart';

class MockAuthRepository extends Fake implements AuthRepository {
  bool forgotPasswordCalled = false;
  String? lastForgotEmail;
  bool resetPasswordCalled = false;
  String? lastResetToken;
  String? lastResetEmail;
  String? lastResetNewPassword;

  bool shouldFailReset = false;

  @override
  Future<Map<String, dynamic>> forgotPassword(String email) async {
    forgotPasswordCalled = true;
    lastForgotEmail = email;
    return {
      'message': 'If that email is registered, a reset link has been sent.',
      'devToken': 'mock_dev_token_123',
    };
  }

  @override
  Future<String> resetPassword({
    required String token,
    required String email,
    required String newPassword,
  }) async {
    resetPasswordCalled = true;
    lastResetToken = token;
    lastResetEmail = email;
    lastResetNewPassword = newPassword;

    if (shouldFailReset) {
      throw Exception('Invalid or expired reset link. Please request a new one.');
    }
    return 'Password has been reset successfully. You can now sign in.';
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockAuthRepository mockAuthRepository;

  setUp(() {
    mockAuthRepository = MockAuthRepository();
  });

  group('ForgotPasswordScreen Tests', () {
    testWidgets('pre-fills initialEmail if supplied', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(mockAuthRepository),
          ],
          child: const MaterialApp(
            home: ForgotPasswordScreen(initialEmail: 'cinemafan@test.com'),
          ),
        ),
      );

      expect(find.text('cinemafan@test.com'), findsOneWidget);
    });

    testWidgets('shows validation error for empty or invalid email', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(mockAuthRepository),
          ],
          child: const MaterialApp(
            home: ForgotPasswordScreen(),
          ),
        ),
      );

      await tester.tap(find.text('Send Reset Link'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter your email address.'), findsOneWidget);
      expect(mockAuthRepository.forgotPasswordCalled, isFalse);

      // Enter invalid email format
      await tester.enterText(find.byType(TextField).first, 'notanemail');
      await tester.tap(find.text('Send Reset Link'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter a valid email address (e.g. name@example.com).'), findsOneWidget);
      expect(mockAuthRepository.forgotPasswordCalled, isFalse);
    });

    testWidgets('submits email and shows confirmation with Enter Code option', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(mockAuthRepository),
          ],
          child: const MaterialApp(
            home: ForgotPasswordScreen(),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField).first, 'user@watchershive.com');
      await tester.tap(find.text('Send Reset Link'));
      await tester.pumpAndSettle();

      expect(mockAuthRepository.forgotPasswordCalled, isTrue);
      expect(mockAuthRepository.lastForgotEmail, equals('user@watchershive.com'));
      expect(find.text('Check your inbox!'), findsOneWidget);
      expect(find.text('Enter Reset Code / Token'), findsOneWidget);
    });
  });

  group('ResetPasswordScreen Tests', () {
    testWidgets('pre-fills token and email from route parameters', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(mockAuthRepository),
          ],
          child: const MaterialApp(
            home: ResetPasswordScreen(
              initialToken: 'test_token_abc',
              initialEmail: 'alice@test.com',
            ),
          ),
        ),
      );

      expect(find.text('alice@test.com'), findsOneWidget);
      expect(find.text('test_token_abc'), findsOneWidget);
    });

    testWidgets('smart paste: extracts token and email when full link is pasted', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(mockAuthRepository),
          ],
          child: const MaterialApp(
            home: ResetPasswordScreen(),
          ),
        ),
      );

      // Paste full email link into token input
      final textFields = find.byType(TextField);
      await tester.enterText(
        textFields.at(1),
        'https://watchershive.com/watch-hive/reset-password?token=secret12345&email=pasted%40test.com',
      );
      await tester.pumpAndSettle();

      // Token field should have extracted token only, and email field should have extracted email
      expect(find.text('secret12345'), findsOneWidget);
      expect(find.text('pasted@test.com'), findsOneWidget);
    });

    testWidgets('validates password requirements live', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(mockAuthRepository),
          ],
          child: const MaterialApp(
            home: ResetPasswordScreen(
              initialEmail: 'test@example.com',
              initialToken: 'valid_token_xyz',
            ),
          ),
        ),
      );

      expect(find.text('PASSWORD REQUIREMENTS'), findsOneWidget);
      expect(find.text('At least 8 characters'), findsOneWidget);
      expect(find.text('Uppercase and lowercase letters'), findsOneWidget);
      expect(find.text('At least one number (0-9)'), findsOneWidget);
      expect(find.text('Passwords match'), findsOneWidget);
    });

    testWidgets('resets password successfully and shows confirmation', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(mockAuthRepository),
          ],
          child: const MaterialApp(
            home: ResetPasswordScreen(
              initialEmail: 'test@example.com',
              initialToken: 'valid_token_xyz',
            ),
          ),
        ),
      );

      final textFields = find.byType(TextField);
      // New password field
      await tester.enterText(textFields.at(2), 'WatchHive2026!');
      // Confirm password field
      await tester.enterText(textFields.at(3), 'WatchHive2026!');
      await tester.pumpAndSettle();

      final submitBtn = find.text('Reset Password & Sign In');
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(mockAuthRepository.resetPasswordCalled, isTrue);
      expect(mockAuthRepository.lastResetToken, equals('valid_token_xyz'));
      expect(mockAuthRepository.lastResetEmail, equals('test@example.com'));
      expect(mockAuthRepository.lastResetNewPassword, equals('WatchHive2026!'));

      expect(find.text('Password Reset Successfully!'), findsOneWidget);
    });

    testWidgets('displays error message gracefully when reset fails', (tester) async {
      mockAuthRepository.shouldFailReset = true;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(mockAuthRepository),
          ],
          child: const MaterialApp(
            home: ResetPasswordScreen(
              initialEmail: 'test@example.com',
              initialToken: 'expired_token',
            ),
          ),
        ),
      );

      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(2), 'WatchHive2026!');
      await tester.enterText(textFields.at(3), 'WatchHive2026!');
      await tester.pumpAndSettle();

      final submitBtn = find.text('Reset Password & Sign In');
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(find.textContaining('Invalid or expired reset link'), findsOneWidget);
      expect(find.text('Request a new reset link →'), findsOneWidget);
    });
  });
}
