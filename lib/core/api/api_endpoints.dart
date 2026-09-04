import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiEndpoints {
  static String get baseUrl =>
      const String.fromEnvironment('WATCHHIVE_API_URL').isNotEmpty
          ? const String.fromEnvironment('WATCHHIVE_API_URL')
          : (dotenv.isInitialized ? (dotenv.env['WATCHHIVE_API_URL'] ?? 'https://watchhive-api-production.up.railway.app/api/v1') : 'https://watchhive-api-production.up.railway.app/api/v1');

  static String get tmdbImageBase =>
      const String.fromEnvironment('TMDB_IMAGE_BASE_URL').isNotEmpty
          ? const String.fromEnvironment('TMDB_IMAGE_BASE_URL')
          : (dotenv.isInitialized ? (dotenv.env['TMDB_IMAGE_BASE_URL'] ?? 'https://image.tmdb.org/t/p/w500') : 'https://image.tmdb.org/t/p/w500');

  static String tmdbPoster(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    final base = tmdbImageBase.endsWith('/')
        ? tmdbImageBase.substring(0, tmdbImageBase.length - 1)
        : tmdbImageBase;
    final cleanPath = path.startsWith('/') ? path : '/$path';
    return '$base$cleanPath';
  }

  static String tmdbBackdrop(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    final cleanPath = path.startsWith('/') ? path : '/$path';
    return 'https://image.tmdb.org/t/p/w780$cleanPath';
  }

  static String resolveAvatarUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    final cleanBase = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    final rootOrigin = cleanBase.contains('/api/v1') ? cleanBase.replaceAll('/api/v1', '') : cleanBase;
    final cleanPath = path.startsWith('/') ? path : '/$path';
    return '$rootOrigin$cleanPath';
  }

  // Auth
  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String googleAuth = '/auth/google';
  static const String refreshToken = '/auth/refresh';
  static const String logout = '/auth/logout';
  static const String forgotPassword = '/auth/forgot-password';
  static const String resetPassword = '/auth/reset-password';
  static const String setPassword = '/auth/set-password';

  // Entries
  static const String entries = '/entries';
  static String entry(String id) => '/entries/$id';
  static const String entryStats = '/entries/stats/summary';
  static String compareEntries(String userId) => '/entries/compare/$userId';

  // Feed
  static const String feed = '/feed';

  // Users
  static const String me = '/users/me';
  static String user(String id) => '/users/$id';
  static const String searchUsers = '/users/search';
  static const String suggestedUsers = '/users/suggested';
  static const String myAvatar = '/users/me/avatar';
  static String updateAvatar(String id) => '/users/$id/avatar';
  static String updateProfile(String id) => '/users/$id';
  static String userWatchlist(String id) => '/users/$id/watchlist';


  // TMDB
  static const String tmdbSearch = '/tmdb/search/multi';
  static String tmdbMovie(int id) => '/tmdb/movie/$id';
  static String tmdbTv(int id) => '/tmdb/tv/$id';
  static String tmdbTrending({String mediaType = 'all', String timeWindow = 'week'}) =>
      '/tmdb/trending/$mediaType/$timeWindow';
  static const String tmdbPopular = '/tmdb/popular';
  static const String tmdbPopularTv = '/tmdb/popular/tv';
  static const String feedTrending = '/feed/trending';


  // Follows
  static const String follows = '/follows';
  static String followUser(String id) => '/follows/$id';
  static String followers(String id) => '/follows/$id/followers';
  static String following(String id) => '/follows/$id/following';
  static String followStats(String id) => '/follows/stats/$id';
  static String acceptFollowRequest(String id) => '/follows/requests/$id/accept';
  static String rejectFollowRequest(String id) => '/follows/requests/$id/reject';
  static const String pendingFollowRequests = '/follows/requests/pending';

  // Likes
  static String likeEntry(String id) => '/likes/$id';

  // Comments
  static String comments(String entryId) => '/comments/$entryId';
  static String comment(String id) => '/comments/$id';

  // Notifications
  static const String notifications = '/notifications';
  static const String markAllNotificationsRead = '/notifications/read-all';
  static String markNotificationRead(String id) => '/notifications/$id/read';

  // Suggestions
  static const String suggestions = '/suggestions';

  // Lists (Watchlist & Rankings)
  static const String lists = '/lists';
  static String list(String id) => '/lists/$id';
  static String listItems(String id) => '/lists/$id/items';
  static String userRankings(String userId) => '/lists/user/$userId/rankings';

  // Stats
  static const String stats = '/stats';
  static const String detailedStats = '/stats/detailed';

  // Data management
  static const String dataExport = '/data/export';
  static const String dataImport = '/data/import';

  // Push Notifications
  static const String pushSubscribe = '/push/subscribe';
  static const String pushUnsubscribe = '/push/unsubscribe';

  // Health
  static const String health = '/health';
}
