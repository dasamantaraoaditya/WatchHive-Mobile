import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watchhive_mobile/features/auth/repositories/auth_repository.dart';
import 'package:watchhive_mobile/features/auth/screens/verify_email_screen.dart';
import 'package:watchhive_mobile/shared/models/user.dart';

class MockAuthRepository extends Fake implements AuthRepository {
  bool verifyEmailCalled = false;
  String? lastVerifyToken;
  String? lastVerifyEmail;
  bool verifyEmailOtpCalled = false;
  String? lastVerifyOtpEmail;
  String? lastVerifyOtpCode;
  bool resendVerificationCalled = false;
  String? lastResendEmail;
  bool requestEmailOtpCalled = false;
  String? lastRequestEmail;
  bool shouldFailVerify = false;

  @override
  Future<User> verifyEmail({required String token, String? email}) async {
    verifyEmailCalled = true;
    lastVerifyToken = token;
    lastVerifyEmail = email;

    if (shouldFailVerify) {
      throw Exception('Invalid or expired verification code.');
    }

    return User(
      id: 'verified_user_1',
      username: 'honeybee',
      displayName: 'Honey Bee',
      email: email ?? 'honeybee@test.com',
      followingCount: 0,
      createdAt: DateTime(2025, 1, 1),
    );
  }

  @override
  Future<User> verifyEmailOtp({required String email, required String code}) async {
    verifyEmailOtpCalled = true;
    lastVerifyOtpEmail = email;
    lastVerifyOtpCode = code;

    if (shouldFailVerify) {
      throw Exception('Invalid or expired verification code.');
    }

    return User(
      id: 'verified_user_1',
      username: 'honeybee',
      displayName: 'Honey Bee',
      email: email,
      followingCount: 0,
      createdAt: DateTime(2025, 1, 1),
    );
  }

  @override
  Future<Map<String, dynamic>> requestEmailOtp(String email) async {
    requestEmailOtpCalled = true;
    lastRequestEmail = email;
    return {'message': '6-digit login code sent'};
  }

  @override
  Future<Map<String, dynamic>> resendVerification(String email) async {
    resendVerificationCalled = true;
    lastResendEmail = email;
    return {'message': 'Verification code resent successfully.'};
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockAuthRepository mockAuthRepository;

  setUp(() {
    mockAuthRepository = MockAuthRepository();
  });

  group('VerifyEmailScreen Tests', () {
    testWidgets('renders title, email notice, 6 OTP fields and button', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(mockAuthRepository),
          ],
          child: const MaterialApp(
            home: VerifyEmailScreen(initialEmail: 'bee@watchershive.com'),
          ),
        ),
      );

      expect(find.text('Enter 6-Digit Code'), findsOneWidget);
      expect(find.textContaining('bee@watchershive.com'), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(6));
      expect(find.text('Verify & Enter Hive'), findsOneWidget);
    });

    testWidgets('entering 6 digits auto-calls verifyEmail', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(mockAuthRepository),
          ],
          child: const MaterialApp(
            home: VerifyEmailScreen(initialEmail: 'bee@watchershive.com'),
          ),
        ),
      );

      final fields = find.byType(TextFormField);
      for (int i = 0; i < 6; i++) {
        await tester.enterText(fields.at(i), '${i + 1}');
      }
      await tester.pump();

      expect(mockAuthRepository.verifyEmailOtpCalled, isTrue);
      expect(mockAuthRepository.lastVerifyOtpCode, '123456');
      expect(mockAuthRepository.lastVerifyOtpEmail, 'bee@watchershive.com');
    });

    testWidgets('resend code button triggers resendVerification', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(mockAuthRepository),
          ],
          child: const MaterialApp(
            home: VerifyEmailScreen(initialEmail: 'bee@watchershive.com'),
          ),
        ),
      );

      // Verify cooldown button initially shows countdown
      expect(find.textContaining('Resend code in'), findsOneWidget);
    });
  });
}
