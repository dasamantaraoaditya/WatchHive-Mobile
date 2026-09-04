import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../shared/models/user.dart';
import '../../../core/utils/error_handler.dart';

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository(ref.read(apiClientProvider));
});

class UserRepository {
  final ApiClient _api;

  UserRepository(this._api);

  /// Fetch authenticated current user profile with live follower/following counts
  Future<User> getCurrentUser() async {
    final response = await _api.get(ApiEndpoints.me);
    final data = response.data as Map<String, dynamic>;
    final userJson = data.containsKey('user') ? data['user'] as Map<String, dynamic> : data;
    var user = User.fromJson(userJson);

    // /users/me backend endpoint returns placeholder followers: 0, following: 0.
    // Fetch live follow stats (same as web app) to ensure accurate counts.
    if (user.id.isNotEmpty) {
      try {
        final stats = await getFollowStats(user.id);
        user = user.copyWith(
          followersCount: stats.followersCount,
          followingCount: stats.followingCount,
        );
      } catch (_) {}
    }
    return user;
  }

  /// Fetch public/follower profile for another user
  Future<User> getUserProfile(String userId) async {
    final response = await _api.get(ApiEndpoints.user(userId));
    final data = response.data as Map<String, dynamic>;
    final userJson = data.containsKey('user') ? data['user'] as Map<String, dynamic> : data;
    var user = User.fromJson(userJson);

    // If counts are 0, also query /follows/stats/:userId to guarantee accurate numbers
    if (user.followersCount == 0 && user.followingCount == 0) {
      try {
        final stats = await getFollowStats(userId);
        if (stats.followersCount > 0 || stats.followingCount > 0) {
          user = user.copyWith(
            followersCount: stats.followersCount,
            followingCount: stats.followingCount,
          );
        }
      } catch (_) {}
    }
    return user;
  }

  /// Update user profile data & privacy preferences with multi-endpoint fallback
  Future<User> updateProfile(String userId, Map<String, dynamic> data) async {
    final cleanData = Map<String, dynamic>.from(data);
    // Ensure isPrivate boolean matches privacyLevel if present
    if (cleanData.containsKey('privacyLevel')) {
      cleanData['isPrivate'] = cleanData['privacyLevel'] == 'PRIVATE';
    }

    dynamic resData;
    DioException? lastError;

    // List of candidate endpoints/methods to try (PUT /users/me is canonical backend endpoint)
    final attempts = [
      () => _api.put(ApiEndpoints.me, data: cleanData),
      () => _api.patch(ApiEndpoints.me, data: cleanData),
      () => _api.put(ApiEndpoints.updateProfile(userId), data: cleanData),
      () => _api.patch(ApiEndpoints.updateProfile(userId), data: cleanData),
    ];

    for (final attempt in attempts) {
      try {
        final response = await attempt();
        resData = response.data;
        break;
      } on DioException catch (e) {
        lastError = e;
        // If 404 (route not found) or 405 (method not allowed), try next candidate
        if (e.response?.statusCode == 404 || e.response?.statusCode == 405) {
          continue;
        }
        // If it's a validation error or 400/401/403/500, extract clear error
        final errorMsg = _extractErrorMessage(e);
        throw Exception(errorMsg);
      }
    }

    if (resData == null) {
      final errorMsg = lastError != null ? _extractErrorMessage(lastError) : 'Failed to update profile';
      throw Exception(errorMsg);
    }

    final map = resData is Map<String, dynamic> ? resData : <String, dynamic>{};
    final userJson = map.containsKey('user') ? map['user'] as Map<String, dynamic> : map;
    return User.fromJson(userJson);
  }

  static final Map<String, String?> _tmdbPosterCache = {};

  /// Fetch TMDB poster for movie or TV show
  Future<String?> getTmdbPoster(int tmdbId, String type) async {
    final key = '${type.toLowerCase()}_$tmdbId';
    if (_tmdbPosterCache.containsKey(key)) {
      return _tmdbPosterCache[key];
    }
    try {
      final endpoint = type.toUpperCase() == 'TV_SHOW' || type.toLowerCase() == 'tv' ? 'tv' : 'movie';
      final res = await _api.get('/tmdb/$endpoint/$tmdbId');
      final data = res.data is Map<String, dynamic> ? res.data as Map<String, dynamic> : null;
      final posterPath = data?['poster_path'] as String?;
      _tmdbPosterCache[key] = posterPath;
      return posterPath;
    } catch (_) {
      return null;
    }
  }

  /// Compare taste and watch history with another user
  Future<Map<String, dynamic>> compareWithUser(String userId) async {
    try {
      final response = await _api.get(ApiEndpoints.compareEntries(userId));
      final resData = response.data;
      if (resData is Map<String, dynamic>) {
        return resData;
      }
    } on DioException catch (e) {
      // 403 Forbidden is a privacy restriction from backend (user hidden entries or followers only)
      if (e.response?.statusCode == 403) {
        final msg = _extractErrorMessage(e);
        throw Exception('PRIVACY_RESTRICTED:$msg');
      }

      // If backend compare endpoint fails with 500 or 404, run client-side fallback
      try {
        final responses = await Future.wait([
          _api.get('/entries', queryParameters: {'userId': userId, 'limit': 100}),
          _api.get('/entries', queryParameters: {'limit': 100}),
        ]);

        final targetEntriesRes = responses[0].data as Map<String, dynamic>? ?? {};
        final userEntriesRes = responses[1].data as Map<String, dynamic>? ?? {};

        final userBEntries = (targetEntriesRes['entries'] as List<dynamic>?) ?? [];
        final userAEntries = (userEntriesRes['entries'] as List<dynamic>?) ?? [];

        final userAMap = <int, Map<String, dynamic>>{};
        for (final item in userAEntries) {
          if (item is Map<String, dynamic> && item['tmdbId'] != null) {
            userAMap[(item['tmdbId'] as num).toInt()] = item;
          }
        }

        final userBMap = <int, Map<String, dynamic>>{};
        for (final item in userBEntries) {
          if (item is Map<String, dynamic> && item['tmdbId'] != null) {
            userBMap[(item['tmdbId'] as num).toInt()] = item;
          }
        }

        final allTmdbIds = {...userAMap.keys, ...userBMap.keys}.toList();
        final commonItems = <Map<String, dynamic>>[];
        final userAOnlyItems = <Map<String, dynamic>>[];
        final userBOnlyItems = <Map<String, dynamic>>[];

        for (final tmdbId in allTmdbIds) {
          final entryA = userAMap[tmdbId];
          final entryB = userBMap[tmdbId];

          if (entryA != null && entryB != null) {
            commonItems.add({
              'tmdbId': tmdbId,
              'title': entryA['title'] ?? entryB['title'] ?? 'Title #$tmdbId',
              'type': entryA['type'] ?? entryB['type'] ?? 'MOVIE',
              'posterPath': entryA['posterPath'] ?? entryB['posterPath'],
              'entryA': {
                'id': entryA['id'],
                'rating': entryA['rating'],
                'review': entryA['review'],
                'watchedAt': entryA['watchedAt'],
              },
              'entryB': {
                'id': entryB['id'],
                'rating': entryB['rating'],
                'review': entryB['review'],
                'watchedAt': entryB['watchedAt'],
              },
            });
          } else if (entryA != null) {
            userAOnlyItems.add({
              'tmdbId': tmdbId,
              'title': entryA['title'] ?? 'Title #$tmdbId',
              'type': entryA['type'] ?? 'MOVIE',
              'rating': entryA['rating'],
              'watchedAt': entryA['watchedAt'],
              'posterPath': entryA['posterPath'],
            });
          } else if (entryB != null) {
            userBOnlyItems.add({
              'tmdbId': tmdbId,
              'title': entryB['title'] ?? 'Title #$tmdbId',
              'type': entryB['type'] ?? 'MOVIE',
              'rating': entryB['rating'],
              'watchedAt': entryB['watchedAt'],
              'posterPath': entryB['posterPath'],
            });
          }
        }

        final matchPercentage = allTmdbIds.isNotEmpty
            ? ((commonItems.length / allTmdbIds.length) * 100).round()
            : 0;

        return {
          'userA': {'id': 'me', 'username': 'you', 'displayName': 'You'},
          'userB': {'id': userId, 'username': 'friend', 'displayName': 'Friend'},
          'stats': {
            'matchPercentage': matchPercentage,
            'totalCommon': commonItems.length,
            'totalUserAOnly': userAOnlyItems.length,
            'totalUserBOnly': userBOnlyItems.length,
            'totalUnique': allTmdbIds.length,
          },
          'commonItems': commonItems,
          'userAOnlyItems': userAOnlyItems,
          'userBOnlyItems': userBOnlyItems,
        };
      } catch (_) {
        throw Exception(_extractErrorMessage(e));
      }
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Failed to compare watch histories: $e');
    }

    return <String, dynamic>{};
  }

  static String _extractErrorMessage(DioException e) {
    return AppErrorHandler.toUserFriendlyMessage(
      e,
      defaultMessage: 'Unable to complete request. Please try again.',
    );
  }

  /// Upload new avatar image via multipart upload
  Future<User> uploadAvatar(XFile file) async {
    final formData = FormData.fromMap({
      'avatar': await MultipartFile.fromFile(
        file.path,
        filename: file.name,
      ),
    });

    final response = await _api.post(
      ApiEndpoints.myAvatar,
      data: formData,
      options: Options(
        headers: {
          'Content-Type': 'multipart/form-data',
        },
      ),
    );

    final resData = response.data as Map<String, dynamic>;
    final userJson = resData.containsKey('user') ? resData['user'] as Map<String, dynamic> : resData;
    return User.fromJson(userJson);
  }

  /// Remove user profile avatar
  Future<void> deleteAvatar() async {
    await _api.delete(ApiEndpoints.myAvatar);
  }

  /// Get list of users following the given user
  Future<List<User>> getFollowers(String userId) async {
    final response = await _api.get(ApiEndpoints.followers(userId));
    final data = response.data;
    final List<dynamic> list;
    if (data is Map<String, dynamic> && data['followers'] is List) {
      list = data['followers'] as List;
    } else if (data is List) {
      list = data;
    } else {
      list = [];
    }
    return list.map((item) {
      final userJson = (item is Map<String, dynamic>)
          ? (item['follower'] ?? item['user'] ?? item)
          : item;
      return User.fromJson(userJson as Map<String, dynamic>);
    }).toList();
  }

  /// Get list of users the given user is following
  Future<List<User>> getFollowing(String userId) async {
    final response = await _api.get(ApiEndpoints.following(userId));
    final data = response.data;
    final List<dynamic> list;
    if (data is Map<String, dynamic> && data['following'] is List) {
      list = data['following'] as List;
    } else if (data is List) {
      list = data;
    } else {
      list = [];
    }
    return list.map((item) {
      final userJson = (item is Map<String, dynamic>)
          ? (item['following'] ?? item['user'] ?? item)
          : item;
      return User.fromJson(userJson as Map<String, dynamic>);
    }).toList();
  }

  /// Fetch follow statistics (followersCount, followingCount) for any user
  Future<({int followersCount, int followingCount})> getFollowStats(String userId) async {
    try {
      final response = await _api.get(ApiEndpoints.followStats(userId));
      final data = response.data;
      if (data is Map<String, dynamic>) {
        int parseInt(dynamic v) {
          if (v == null) return 0;
          if (v is num) return v.toInt();
          if (v is String) return int.tryParse(v) ?? 0;
          return 0;
        }

        final followers = parseInt(data['followersCount'] ?? data['followers']);
        final following = parseInt(data['followingCount'] ?? data['following']);
        return (followersCount: followers, followingCount: following);
      }
    } catch (_) {}

    // Fallback: fetch user details which calculates _count in parallel
    try {
      final response = await _api.get(ApiEndpoints.user(userId));
      final data = response.data as Map<String, dynamic>;
      final userJson = data.containsKey('user') ? data['user'] as Map<String, dynamic> : data;
      final u = User.fromJson(userJson);
      return (followersCount: u.followersCount, followingCount: u.followingCount);
    } catch (_) {}

    return (followersCount: 0, followingCount: 0);
  }


  /// Follow or request to follow a user
  Future<void> followUser(String userId) async {
    await _api.post(ApiEndpoints.followUser(userId));
  }

  /// Unfollow or cancel follow request
  Future<void> unfollowUser(String userId) async {
    await _api.delete(ApiEndpoints.followUser(userId));
  }

  /// Accept incoming follow request
  Future<void> acceptFollowRequest(String requestId) async {
    await _api.post(ApiEndpoints.acceptFollowRequest(requestId));
  }

  /// Reject incoming follow request
  Future<void> rejectFollowRequest(String requestId) async {
    await _api.post(ApiEndpoints.rejectFollowRequest(requestId));
  }

  /// Fetch user's public watchlist items
  Future<Map<String, dynamic>> getUserWatchlist(String userId) async {
    final response = await _api.get(ApiEndpoints.userWatchlist(userId));
    return response.data as Map<String, dynamic>;
  }

  /// Fetch user's public ranking stacks
  Future<List<dynamic>> getUserRankings(String userId) async {
    final response = await _api.get(ApiEndpoints.userRankings(userId));
    final data = response.data;
    if (data is List) return data;
    if (data is Map && data['items'] is List) return data['items'] as List;
    return [];
  }

  /// Fetch detailed watch statistics for analytics view
  Future<Map<String, dynamic>> getDetailedStats({
    int days = 30,
    String? type,
    String? genre,
    double? minRating,
  }) async {
    final response = await _api.get(
      ApiEndpoints.detailedStats,
      queryParameters: {
        'days': days,
        if (type != null && type.isNotEmpty) 'type': type,
        if (genre != null && genre.isNotEmpty) 'genre': genre,
        if (minRating != null && minRating > 0) 'minRating': minRating,
      },
    );
    return response.data as Map<String, dynamic>;
  }

  /// Set backup password for Google-linked accounts
  Future<void> setPassword(String newPassword) async {
    await _api.post(
      ApiEndpoints.setPassword,
      data: {'newPassword': newPassword},
    );
  }

  /// Export user data as JSON or CSV string
  Future<String> exportData({
    bool includeEntries = true,
    bool includeLists = true,
    String format = 'json',
  }) async {
    final includeParts = <String>[];
    if (includeEntries) includeParts.add('entries');
    if (includeLists) includeParts.add('lists');
    if (includeParts.isEmpty) {
      throw Exception('Select at least one data type to export.');
    }

    final response = await _api.get(
      ApiEndpoints.dataExport,
      queryParameters: {
        'format': format,
        'include': includeParts.join(','),
      },
      options: Options(responseType: ResponseType.plain),
    );

    final raw = response.data;
    if (raw is String) {
      return raw;
    }
    return jsonEncode(raw);
  }

  /// Import user data payload { "entries": [...], "lists": [...] }
  Future<Map<String, dynamic>> importData(Map<String, dynamic> payload) async {
    final body = <String, dynamic>{};
    if (payload['entries'] is List) body['entries'] = payload['entries'];
    if (payload['lists'] is List) body['lists'] = payload['lists'];

    if (!body.containsKey('entries') && !body.containsKey('lists')) {
      throw Exception('File must contain an "entries" and/or "lists" array.');
    }

    final response = await _api.post(
      ApiEndpoints.dataImport,
      data: body,
    );

    if (response.data is Map<String, dynamic>) {
      return response.data as Map<String, dynamic>;
    }
    return <String, dynamic>{'message': 'Import complete!'};
  }
}
