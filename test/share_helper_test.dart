import 'package:flutter_test/flutter_test.dart';
import 'package:watchhive_mobile/core/utils/share_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ShareHelper Tests', () {
    test('shareCompletedWatch formats and invokes without throwing', () async {
      // In unit test environment, Share.share channel calls succeed or no-op cleanly
      expect(
        () => ShareHelper.shareCompletedWatch(
          title: 'Inception',
          rating: 9.5,
          review: 'Mind-bending masterpiece!',
          tmdbId: 27205,
          mediaType: 'movie',
          userDisplayName: 'Alice',
        ),
        returnsNormally,
      );
    });
  });
}
