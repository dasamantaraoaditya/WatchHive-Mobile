/// Centralized registry for all WatchersHive web URLs and shareable deep links.
class WebUrls {
  WebUrls._();

  /// Canonical web base domain
  static const String baseUrl = 'https://watchershive.com';

  /// Deep link URL for a movie or TV show details page.
  /// Supports optional referrer / suggested by attribution.
  /// Example: https://watchhive-web.vercel.app/watch-hive/details/movie/550?suggestedByUserId=123
  static String movieDetails(
    String mediaType,
    int tmdbId, {
    String? suggestedByUserId,
    String? suggestedByUsername,
    String? source,
  }) {
    final cleanMediaType = mediaType.toLowerCase().trim();
    final params = <String>[];
    if (suggestedByUserId != null && suggestedByUserId.trim().isNotEmpty) {
      params.add('suggestedByUserId=${Uri.encodeComponent(suggestedByUserId.trim())}');
    }
    if (suggestedByUsername != null && suggestedByUsername.trim().isNotEmpty) {
      params.add('suggestedByUsername=${Uri.encodeComponent(suggestedByUsername.trim())}');
    }
    if (source != null && source.trim().isNotEmpty) {
      params.add('source=${Uri.encodeComponent(source.trim())}');
    }
    final query = params.isNotEmpty ? '?${params.join('&')}' : '';
    return '$baseUrl/watch-hive/details/$cleanMediaType/$tmdbId$query';
  }

  /// Deep link URL for a user profile.
  /// Supports optional referral query parameter.
  /// Example: https://watchhive-web.vercel.app/watch-hive/profile/user-id-123
  static String userProfile(String userId, {String? refUsername, String? source}) {
    final params = <String>[];
    if (refUsername != null && refUsername.trim().isNotEmpty) {
      params.add('ref=${Uri.encodeComponent(refUsername.trim())}');
    }
    if (source != null && source.trim().isNotEmpty) {
      params.add('source=${Uri.encodeComponent(source.trim())}');
    }
    final query = params.isNotEmpty ? '?${params.join('&')}' : '';
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

  /// URL for the WatchersHive privacy policy.
  /// Example: https://watchhive-web.vercel.app/watch-hive/privacy
  static String privacyPolicy() => '$baseUrl/watch-hive/privacy';
}
