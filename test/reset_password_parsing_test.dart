import 'package:flutter_test/flutter_test.dart';

({String token, String? email})? extractTokenAndEmail(String raw) {
  try {
    final uri = Uri.tryParse(raw);
    if (uri != null && uri.queryParameters.containsKey('token')) {
      return (
        token: uri.queryParameters['token']!.trim(),
        email: uri.queryParameters['email']?.trim(),
      );
    }
    final tokenMatch = RegExp(r'[?&]token=([^&\s]+)').firstMatch(raw);
    if (tokenMatch != null) {
      final token = Uri.decodeComponent(tokenMatch.group(1)!);
      final emailMatch = RegExp(r'[?&]email=([^&\s]+)').firstMatch(raw);
      final email = emailMatch != null ? Uri.decodeComponent(emailMatch.group(1)!) : null;
      return (token: token, email: email);
    }
  } catch (_) {}
  return null;
}

void main() {
  group('Reset Password Link & Token Extraction Tests', () {
    test('Extracts token and email from production web reset URL', () {
      const url =
          'https://www.watchershive.com/watch-hive/reset-password?token=a1b2c3d4e5f6&email=test%40watchershive.com';
      final result = extractTokenAndEmail(url);
      expect(result, isNotNull);
      expect(result!.token, equals('a1b2c3d4e5f6'));
      expect(result.email, equals('test@watchershive.com'));
    });

    test('Extracts token and email from custom scheme deep link', () {
      const url =
          'watchershive://reset-password?token=654321&email=cinephile%40gmail.com';
      final result = extractTokenAndEmail(url);
      expect(result, isNotNull);
      expect(result!.token, equals('654321'));
      expect(result.email, equals('cinephile@gmail.com'));
    });

    test('Leaves plain 6-digit OTP code untouched', () {
      const code = '482910';
      final result = extractTokenAndEmail(code);
      // Because it's not a URL with a token param, extract returns null, allowing direct field usage
      expect(result, isNull);
    });
  });
}
