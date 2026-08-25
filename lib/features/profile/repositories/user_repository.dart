import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../shared/models/user.dart';

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository(ref.read(apiClientProvider));
});

class UserRepository {
  final ApiClient _api;

  UserRepository(this._api);

  /// Fetch authenticated current user profile
  Future<User> getCurrentUser() async {
    final response = await _api.get(ApiEndpoints.me);
    final data = response.data as Map<String, dynamic>;
    final userJson = data.containsKey('user') ? data['user'] as Map<String, dynamic> : data;
    return User.fromJson(userJson);
  }

  /// Fetch public/follower profile for another user
  Future<User> getUserProfile(String userId) async {
    final response = await _api.get(ApiEndpoints.user(userId));
    final data = response.data as Map<String, dynamic>;
    final userJson = data.containsKey('user') ? data['user'] as Map<String, dynamic> : data;
    return User.fromJson(userJson);
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

    // List of candidate endpoints/methods to try
    final attempts = [
      () => _api.patch(ApiEndpoints.me, data: cleanData),
      () => _api.put(ApiEndpoints.me, data: cleanData),
      () => _api.patch(ApiEndpoints.updateProfile(userId), data: cleanData),
      () => _api.put(ApiEndpoints.updateProfile(userId), data: cleanData),
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

  /// Compare taste and watch history with another user
  Future<Map<String, dynamic>> compareWithUser(String userId) async {
    dynamic resData;
    DioException? lastError;

    final attempts = [
      () => _api.get(ApiEndpoints.compareEntries(userId)),
      () => _api.get('/entries/compare', queryParameters: {'userId': userId}),
      () => _api.get('/users/$userId/compare'),
    ];

    for (final attempt in attempts) {
      try {
        final response = await attempt();
        resData = response.data;
        break;
      } on DioException catch (e) {
        lastError = e;
        if (e.response?.statusCode == 404 || e.response?.statusCode == 405) {
          continue;
        }
        final errorMsg = _extractErrorMessage(e);
        throw Exception(errorMsg);
      }
    }

    if (resData == null) {
      final errorMsg = lastError != null ? _extractErrorMessage(lastError) : 'Failed to compare taste data';
      throw Exception(errorMsg);
    }

    return resData is Map<String, dynamic> ? resData : <String, dynamic>{};
  }

  static String _extractErrorMessage(DioException e) {
    if (e.response?.data != null) {
      final data = e.response!.data;
      if (data is Map) {
        if (data['message'] is String) return data['message'] as String;
        if (data['message'] is List && (data['message'] as List).isNotEmpty) {
          return (data['message'] as List).join(', ');
        }
        if (data['error'] is String) return data['error'] as String;
      }
    }
    return e.message ?? 'Network request failed';
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

  /// Export user data as JSON or CSV
  Future<dynamic> exportData({
    bool includeEntries = true,
    bool includeLists = true,
    String format = 'json',
  }) async {
    final response = await _api.get(
      ApiEndpoints.dataExport,
      queryParameters: {
        'includeEntries': includeEntries,
        'includeLists': includeLists,
        'format': format,
      },
    );
    return response.data;
  }
}
