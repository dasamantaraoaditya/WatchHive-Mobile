/// Centralized registry for all WatchHive web URLs and shareable deep links.
class WebUrls {
  WebUrls._();

  /// Canonical web base domain
  static const String baseUrl = 'https://watchhive-web.vercel.app';

  /// Deep link URL for a movie or TV show details page.
  /// Example: https://watchhive-web.vercel.app/watch-hive/details/movie/550
  static String movieDetails(String mediaType, int tmdbId) {
    final cleanMediaType = mediaType.toLowerCase().trim();
    return '$baseUrl/watch-hive/details/$cleanMediaType/$tmdbId';
  }

  /// Deep link URL for a user profile.
  /// Supports optional referral query parameter.
  /// Example: https://watchhive-web.vercel.app/watch-hive/profile/user-id-123
  static String userProfile(String userId, {String? refUsername}) {
    final query = (refUsername != null && refUsername.trim().isNotEmpty)
        ? '?ref=${Uri.encodeComponent(refUsername.trim())}'
        : '';
    return '$baseUrl/watch-hive/profile/$userId$query';
  }

  /// Deep link URL for a user's rankings / stacks tab.
  /// Example: https://watchhive-web.vercel.app/watch-hive/profile/user-id-123?tab=rankings
  static String userRankings(String userId) =>
      '$baseUrl/watch-hive/profile/$userId?tab=rankings';

  /// Deep link URL for the general rankings page.
  /// Example: https://watchhive-web.vercel.app/watch-hive/rankings
  static String rankings() => '$baseUrl/watch-hive/rankings';

  /// Deep link URL for new user signup / invitation.
  /// Example: https://watchhive-web.vercel.app/watch-hive/signup?ref=cinemafan
  static String signup([String? refUsername]) {
    final query = (refUsername != null && refUsername.trim().isNotEmpty)
        ? '?ref=${Uri.encodeComponent(refUsername.trim())}'
        : '';
    return '$baseUrl/watch-hive/signup$query';
  }

  /// URL for the WatchHive privacy policy.
  /// Example: https://watchhive-web.vercel.app/watch-hive/privacy
  static String privacyPolicy() => '$baseUrl/watch-hive/privacy';
}
