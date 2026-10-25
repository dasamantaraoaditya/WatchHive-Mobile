import 'package:flutter_test/flutter_test.dart';
import 'package:watchhive_mobile/core/router/app_router.dart';

void main() {
  group('Deep Link Normalization & Routing Tests', () {
    test('Normalizes custom scheme watchershive://details/movie/550', () {
      final uri = Uri.parse('watchershive://details/movie/550');
      expect(normalizeIncomingRoute(uri), equals('/details/movie/550'));
    });

    test('Normalizes custom scheme watchershive://movie/550 with query parameters', () {
      final uri = Uri.parse('watchershive://movie/550?suggestedByUserId=user123');
      expect(
        normalizeIncomingRoute(uri),
        equals('/details/movie/550?suggestedByUserId=user123'),
      );
    });

    test('Normalizes custom scheme watchershive://profile/abc-123', () {
      final uri = Uri.parse('watchershive://profile/abc-123');
      expect(normalizeIncomingRoute(uri), equals('/profile/abc-123'));
    });

    test('Normalizes custom scheme watchershive://user/abc-123', () {
      final uri = Uri.parse('watchershive://user/abc-123');
      expect(normalizeIncomingRoute(uri), equals('/profile/abc-123'));
    });

    test('Normalizes web URL /watch-hive/details/movie/550', () {
      final uri = Uri.parse('https://watchershive.com/watch-hive/details/movie/550?ref=friend');
      expect(normalizeIncomingRoute(uri), equals('/details/movie/550?ref=friend'));
    });

    test('Normalizes web URL /watch-hive/profile/xyz-789', () {
      final uri = Uri.parse('https://watchhive-web.vercel.app/watch-hive/profile/xyz-789');
      expect(normalizeIncomingRoute(uri), equals('/profile/xyz-789'));
    });

    test('Normalizes web URL /user/xyz-789 to /profile/xyz-789', () {
      final uri = Uri.parse('https://watchershive.com/user/xyz-789');
      expect(normalizeIncomingRoute(uri), equals('/profile/xyz-789'));
    });

    test('Pending deep link is consumed and reset', () {
      // First ensure clean state
      consumePendingDeepLink();
      expect(consumePendingDeepLink(), isNull);
    });
  });
}
