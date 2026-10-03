import 'package:flutter_test/flutter_test.dart';
import 'package:watchhive_mobile/core/config/web_urls.dart';

void main() {
  group('WebUrls Centralized URL Registry Tests', () {
    test('movieDetails generates correct movie URL', () {
      final url = WebUrls.movieDetails('movie', 550);
      expect(url, 'https://watchershive.com/watch-hive/details/movie/550');
    });

    test('movieDetails handles uppercase and whitespace in mediaType', () {
      final url = WebUrls.movieDetails('  TV  ', 1399);
      expect(url, 'https://watchershive.com/watch-hive/details/tv/1399');
    });

    test('userProfile generates correct profile URL without ref', () {
      final url = WebUrls.userProfile('user_uuid_123');
      expect(url, 'https://watchershive.com/watch-hive/profile/user_uuid_123');
    });

    test('userProfile includes encoded referral query when refUsername is provided', () {
      final url = WebUrls.userProfile('user_uuid_123', refUsername: 'aditya_cinephile');
      expect(url, 'https://watchershive.com/watch-hive/profile/user_uuid_123?ref=aditya_cinephile');
    });

    test('userProfile ignores empty/whitespace refUsername', () {
      final url = WebUrls.userProfile('user_uuid_123', refUsername: '   ');
      expect(url, 'https://watchershive.com/watch-hive/profile/user_uuid_123');
    });

    test('userRankings generates URL with rankings tab', () {
      final url = WebUrls.userRankings('user_uuid_123');
      expect(url, 'https://watchershive.com/watch-hive/profile/user_uuid_123?tab=rankings');
    });

    test('rankings generates general rankings page URL', () {
      final url = WebUrls.rankings();
      expect(url, 'https://watchershive.com/watch-hive/rankings');
    });

    test('signup generates clean signup URL', () {
      final url = WebUrls.signup();
      expect(url, 'https://watchershive.com/watch-hive/signup');
    });

    test('signup includes encoded referral query when refUsername is provided', () {
      final url = WebUrls.signup('buff99');
      expect(url, 'https://watchershive.com/watch-hive/signup?ref=buff99');
    });

    test('privacyPolicy generates correct web privacy URL', () {
      final url = WebUrls.privacyPolicy();
      expect(url, 'https://watchershive.com/watch-hive/privacy');
    });
  });

  group('Share Message Format Validation Tests', () {
    test('movie share message contains title and valid details link', () {
      const title = 'Inception';
      final url = WebUrls.movieDetails('movie', 27205);
      final message = 'Check out "$title" on WatchersHive! Track movies, series & anime together 🎬🐝\n\n$url';

      expect(message, contains('Inception'));
      expect(message, contains('https://watchershive.com/watch-hive/details/movie/27205'));
      expect(Uri.tryParse(url)?.hasScheme, true);
    });

    test('profile share message contains profile link with referral', () {
      const userId = 'u_456';
      const username = 'filmfan';
      final profileUrl = WebUrls.userProfile(userId, refUsername: username);
      final message = 'Join me on WatchersHive! Check out my profile and cinematic journey: 🐝🎥\n\n$profileUrl';

      expect(message, contains('https://watchershive.com/watch-hive/profile/u_456?ref=filmfan'));
      expect(Uri.tryParse(profileUrl)?.hasScheme, true);
    });

    test('ranked stack share message contains stack name and rankings link', () {
      const stackName = 'Top Sci-Fi 2024';
      const userId = 'user_789';
      final url = WebUrls.userRankings(userId);
      final message = 'Check out my "$stackName" ranked stack on WatchersHive! 🐝🎬\n\n$url';

      expect(message, contains('Top Sci-Fi 2024'));
      expect(message, contains('https://watchershive.com/watch-hive/profile/user_789?tab=rankings'));
      expect(Uri.tryParse(url)?.hasScheme, true);
    });
  });
}
