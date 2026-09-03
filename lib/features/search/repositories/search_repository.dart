import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../shared/models/models.dart';
import '../../../shared/models/user.dart';

final searchRepositoryProvider = Provider<SearchRepository>((ref) {
  return SearchRepository(ref.read(apiClientProvider));
});

class SearchRepository {
  final ApiClient _api;
  final FlutterSecureStorage _storage;
  static const String _recentSearchesKey = 'watchhive_recent_searches';

  SearchRepository(this._api, [FlutterSecureStorage? storage])
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  Future<List<MediaResult>> searchMedia(String query, {String? type}) async {
    final response = await _api.get(
      ApiEndpoints.tmdbSearch,
      queryParameters: {
        'query': query,
        if (type != null) 'type': type,
      },
    );
    final data = response.data as Map<String, dynamic>;
    final results = data['results'] as List<dynamic>? ?? [];
    return results
        .map((e) => MediaResult.fromJson(e as Map<String, dynamic>))
        .where((r) => r.mediaType == 'movie' || r.mediaType == 'tv')
        .toList();
  }

  Future<List<User>> searchUsers(String query) async {
    if (query.trim().isEmpty) return [];
    try {
      final response = await _api.get(
        ApiEndpoints.searchUsers,
        queryParameters: {'q': query.trim()},
      );
      final data = response.data;
      List<dynamic> users = [];
      if (data is Map<String, dynamic> && data['users'] is List) {
        users = data['users'] as List;
      } else if (data is List) {
        users = data;
      }
      return users.map((u) => User.fromJson(u as Map<String, dynamic>)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<User>> getSuggestedUsers() async {
    try {
      final response = await _api.get(ApiEndpoints.suggestedUsers);
      final data = response.data;
      List<dynamic> users = [];
      if (data is Map<String, dynamic> && data['users'] is List) {
        users = data['users'] as List;
      } else if (data is List) {
        users = data;
      }
      return users.map((u) => User.fromJson(u as Map<String, dynamic>)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>> getMovieDetails(int tmdbId) async {
    final response = await _api.get(ApiEndpoints.tmdbMovie(tmdbId));
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getTvDetails(int tmdbId) async {
    final response = await _api.get(ApiEndpoints.tmdbTv(tmdbId));
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getTvSeasonDetails(int tvId, int seasonNumber) async {
    final response = await _api.get('/tmdb/tv/$tvId/season/$seasonNumber');
    return response.data as Map<String, dynamic>;
  }

  Future<List<MediaResult>> getRecommendations(String mediaType, int tmdbId) async {
    try {
      final endpoint = mediaType == 'tv' ? '/tmdb/tv/$tmdbId/recommendations' : '/tmdb/movie/$tmdbId/recommendations';
      final response = await _api.get(endpoint);
      final data = response.data as Map<String, dynamic>;
      final results = data['results'] as List<dynamic>? ?? [];
      return results
          .map((e) => MediaResult.fromJson({
                ...e as Map<String, dynamic>,
                'media_type': mediaType,
              }))
          .toList();
    } catch (_) {
      return [];
    }
  }


  Future<List<MediaResult>> getTrending({String mediaType = 'all', String timeWindow = 'week'}) async {
    try {
      final response = await _api.get(ApiEndpoints.tmdbTrending(mediaType: mediaType, timeWindow: timeWindow));
      final data = response.data as Map<String, dynamic>;
      final results = data['results'] as List<dynamic>? ?? [];
      return results
          .map((e) => MediaResult.fromJson(e as Map<String, dynamic>))
          .where((r) => r.mediaType == 'movie' || r.mediaType == 'tv')
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<MediaResult>> getPopular({String type = 'movie'}) async {
    try {
      final endpoint = type == 'tv' ? ApiEndpoints.tmdbPopularTv : ApiEndpoints.tmdbPopular;
      final response = await _api.get(endpoint);
      final data = response.data as Map<String, dynamic>;
      final results = data['results'] as List<dynamic>? ?? [];
      return results
          .map((e) => MediaResult.fromJson({
                ...e as Map<String, dynamic>,
                'media_type': type,
              }))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getCommunityTrending() async {
    try {
      final response = await _api.get(ApiEndpoints.feedTrending);
      final data = response.data as Map<String, dynamic>;
      final list = data['trending'] as List<dynamic>? ?? [];
      return list.map((item) => item as Map<String, dynamic>).toList();
    } catch (e) {
      return [];
    }
  }

  // Local Recent Search History
  Future<List<String>> getRecentSearches() async {
    try {
      final raw = await _storage.read(key: _recentSearchesKey);
      if (raw == null || raw.isEmpty) return [];
      final list = jsonDecode(raw);
      if (list is List) {
        return list.map((e) => e.toString()).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<void> addRecentSearch(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) return;
    try {
      final current = await getRecentSearches();
      current.removeWhere((item) => item.toLowerCase() == clean.toLowerCase());
      current.insert(0, clean);
      final trimmed = current.take(8).toList();
      await _storage.write(key: _recentSearchesKey, value: jsonEncode(trimmed));
    } catch (_) {}
  }

  Future<void> removeRecentSearch(String query) async {
    try {
      final current = await getRecentSearches();
      current.removeWhere((item) => item.toLowerCase() == query.trim().toLowerCase());
      await _storage.write(key: _recentSearchesKey, value: jsonEncode(current));
    } catch (_) {}
  }

  Future<void> clearRecentSearches() async {
    try {
      await _storage.delete(key: _recentSearchesKey);
    } catch (_) {}
  }
}


final tmdbMediaDetailsProvider = FutureProvider.family<Map<String, dynamic>?, ({int tmdbId, String mediaType})>((ref, arg) async {
  if (arg.tmdbId <= 0) return null;
  final searchRepo = ref.read(searchRepositoryProvider);
  final isTv = arg.mediaType.toLowerCase().contains('tv');
  try {
    if (isTv) {
      final res = await searchRepo.getTvDetails(arg.tmdbId);
      if (res['poster_path'] != null || res['backdrop_path'] != null) return res;
      try {
        final movieRes = await searchRepo.getMovieDetails(arg.tmdbId);
        if (movieRes['poster_path'] != null || movieRes['backdrop_path'] != null) return movieRes;
      } catch (_) {}
      return res;
    } else {
      final res = await searchRepo.getMovieDetails(arg.tmdbId);
      if (res['poster_path'] != null || res['backdrop_path'] != null) return res;
      try {
        final tvRes = await searchRepo.getTvDetails(arg.tmdbId);
        if (tvRes['poster_path'] != null || tvRes['backdrop_path'] != null) return tvRes;
      } catch (_) {}
      return res;
    }
  } catch (_) {
    // Fallback: if initial type call failed, try the alternate media type
    try {
      if (isTv) {
        return await searchRepo.getMovieDetails(arg.tmdbId);
      } else {
        return await searchRepo.getTvDetails(arg.tmdbId);
      }
    } catch (_) {
      return null;
    }
  }
});
