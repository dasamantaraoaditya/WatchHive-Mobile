import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/services/offline_storage_service.dart';
import '../../../shared/models/models.dart';
import '../../../shared/models/user.dart';
import '../services/smart_search_engine.dart';

class SmartMediaSearchResult {
  final List<MediaResult> results;
  final String? correctedQuery;
  final String originalQuery;
  final bool isSmartCorrected;

  const SmartMediaSearchResult({
    required this.results,
    this.correctedQuery,
    required this.originalQuery,
    this.isSmartCorrected = false,
  });
}

final searchRepositoryProvider = Provider<SearchRepository>((ref) {
  return SearchRepository(ref.read(apiClientProvider));
});

class SearchRepository {
  final ApiClient _api;
  final FlutterSecureStorage _storage;
  static const String _recentSearchesKey = 'watchhive_recent_searches';
  List<User> _lastSuggestedUsers = [];

  SearchRepository(this._api, [FlutterSecureStorage? storage])
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  Future<List<MediaResult>> _rawSearchMedia(String query,
      {String? type}) async {
    final clean = query.trim();
    if (clean.isEmpty) return [];
    try {
      final response = await _api.get(
        ApiEndpoints.tmdbSearch,
        queryParameters: {
          'query': clean,
          if (type != null) 'type': type,
        },
      );
      final data = response.data as Map<String, dynamic>;
      final results = data['results'] as List<dynamic>? ?? [];
      return results
          .map((e) => MediaResult.fromJson(e as Map<String, dynamic>))
          .where((r) => r.mediaType == 'movie' || r.mediaType == 'tv')
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Performs an intelligent, typo-tolerant search across TMDB media.
  /// If direct search produces no matches, attempts heuristic recovery and dictionary-guided fuzzy matching.
  Future<SmartMediaSearchResult> searchMediaSmart(String query,
      {String? type}) async {
    final clean = query.trim();
    if (clean.isEmpty) {
      return SmartMediaSearchResult(results: [], originalQuery: clean);
    }

    final engine = SmartSearchEngine.instance;

    // 1. Direct search with user query
    final directResults = await _rawSearchMedia(clean, type: type);
    if (directResults.isNotEmpty) {
      engine.registerTitles(directResults.map((r) => r.title));
      final ranked = engine.rankMediaResults(clean, directResults);
      return SmartMediaSearchResult(
        results: ranked,
        originalQuery: clean,
        isSmartCorrected: false,
      );
    }

    // 2. Direct search returned 0 results. Try typo correction and fuzzy candidate variations.
    if (clean.length >= 3) {
      final candidates = engine.generateQueryCandidates(clean);

      for (final candidate in candidates) {
        if (candidate.toLowerCase() == clean.toLowerCase()) continue;

        final candidateResults = await _rawSearchMedia(candidate, type: type);
        if (candidateResults.isNotEmpty) {
          engine.registerTitles(candidateResults.map((r) => r.title));
          final ranked = engine.rankMediaResults(clean, candidateResults);
          return SmartMediaSearchResult(
            results: ranked,
            originalQuery: clean,
            correctedQuery: candidate,
            isSmartCorrected: true,
          );
        }
      }
    }

    return SmartMediaSearchResult(
      results: [],
      originalQuery: clean,
      isSmartCorrected: false,
    );
  }

  Future<List<MediaResult>> searchMedia(String query, {String? type}) async {
    final smart = await searchMediaSmart(query, type: type);
    return smart.results;
  }

  Future<List<User>> searchUsers(String query) async {
    final clean = query.trim().replaceAll('@', '');
    if (clean.isEmpty) return [];
    try {
      final response = await _api.get(
        ApiEndpoints.searchUsers,
        queryParameters: {'q': clean},
      );
      final data = response.data;
      List<dynamic> users = [];
      if (data is Map<String, dynamic> && data['users'] is List) {
        users = data['users'] as List;
      } else if (data is List) {
        users = data;
      }
      final parsed =
          users.map((u) => User.fromJson(u as Map<String, dynamic>)).toList();
      if (parsed.isNotEmpty) {
        return SmartSearchEngine.instance.fuzzySearchUsers(clean, parsed);
      }
    } catch (_) {}

    // Fallback: If backend returns 0 users, run fuzzy search on suggested/cached users!
    if (_lastSuggestedUsers.isNotEmpty) {
      return SmartSearchEngine.instance
          .fuzzySearchUsers(clean, _lastSuggestedUsers);
    }

    return [];
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
      final parsed =
          users.map((u) => User.fromJson(u as Map<String, dynamic>)).toList();
      _lastSuggestedUsers = parsed;
      return parsed;
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

  Future<Map<String, dynamic>> getTvSeasonDetails(
      int tvId, int seasonNumber) async {
    final response = await _api.get('/tmdb/tv/$tvId/season/$seasonNumber');
    return response.data as Map<String, dynamic>;
  }

  Future<List<MediaResult>> getRecommendations(
      String mediaType, int tmdbId) async {
    try {
      final endpoint = mediaType == 'tv'
          ? '/tmdb/tv/$tmdbId/recommendations'
          : '/tmdb/movie/$tmdbId/recommendations';
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

  Future<List<MediaResult>> getTrending(
      {String mediaType = 'all', String timeWindow = 'week'}) async {
    try {
      final response = await _api.get(ApiEndpoints.tmdbTrending(
          mediaType: mediaType, timeWindow: timeWindow));
      final data = response.data as Map<String, dynamic>;
      final results = data['results'] as List<dynamic>? ?? [];
      final mapped = results
          .map((e) => MediaResult.fromJson(e as Map<String, dynamic>))
          .where((r) => r.mediaType == 'movie' || r.mediaType == 'tv')
          .toList();
      SmartSearchEngine.instance.registerTitles(mapped.map((m) => m.title));
      return mapped;
    } catch (e) {
      return [];
    }
  }

  Future<List<MediaResult>> getPopular({String type = 'movie'}) async {
    try {
      final endpoint =
          type == 'tv' ? ApiEndpoints.tmdbPopularTv : ApiEndpoints.tmdbPopular;
      final response = await _api.get(endpoint);
      final data = response.data as Map<String, dynamic>;
      final results = data['results'] as List<dynamic>? ?? [];
      final mapped = results
          .map((e) => MediaResult.fromJson({
                ...e as Map<String, dynamic>,
                'media_type': type,
              }))
          .toList();
      SmartSearchEngine.instance.registerTitles(mapped.map((m) => m.title));
      return mapped;
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
      current.removeWhere(
          (item) => item.toLowerCase() == query.trim().toLowerCase());
      await _storage.write(key: _recentSearchesKey, value: jsonEncode(current));
    } catch (_) {}
  }

  Future<void> clearRecentSearches() async {
    try {
      await _storage.delete(key: _recentSearchesKey);
    } catch (_) {}
  }
}

final tmdbMediaDetailsProvider = FutureProvider.family<Map<String, dynamic>?,
    ({int tmdbId, String mediaType})>((ref, arg) async {
  if (arg.tmdbId <= 0) return null;
  final searchRepo = ref.read(searchRepositoryProvider);
  final storage = ref.read(offlineStorageServiceProvider);
  final isTv = arg.mediaType.toLowerCase().contains('tv');
  final normType = isTv ? 'tv' : 'movie';

  try {
    Map<String, dynamic> res;
    if (isTv) {
      res = await searchRepo.getTvDetails(arg.tmdbId);
      if (res['poster_path'] == null && res['backdrop_path'] == null) {
        try {
          final movieRes = await searchRepo.getMovieDetails(arg.tmdbId);
          if (movieRes['poster_path'] != null ||
              movieRes['backdrop_path'] != null) {
            res = movieRes;
          }
        } catch (_) {}
      }
    } else {
      res = await searchRepo.getMovieDetails(arg.tmdbId);
      if (res['poster_path'] == null && res['backdrop_path'] == null) {
        try {
          final tvRes = await searchRepo.getTvDetails(arg.tmdbId);
          if (tvRes['poster_path'] != null || tvRes['backdrop_path'] != null) {
            res = tvRes;
          }
        } catch (_) {}
      }
    }

    // Persist details to local SQLite for offline access
    await storage.saveMediaDetails(arg.tmdbId, normType, res);

    final poster = res['poster_path'] as String?;
    final backdrop = res['backdrop_path'] as String?;
    if (poster != null || backdrop != null) {
      await storage.updateEntryPostersByTmdbId(arg.tmdbId,
          posterPath: poster, backdropPath: backdrop);
      storage.prewarmImage(poster);
    }

    return res;
  } catch (_) {
    // Offline or network error: check SQLite media details cache
    final cached = await storage.getCachedMediaDetails(arg.tmdbId, normType);
    if (cached != null) return cached;

    // Fallback: if initial type call failed, try the alternate media type
    try {
      final altType = isTv ? 'movie' : 'tv';
      final altRes = isTv
          ? await searchRepo.getMovieDetails(arg.tmdbId)
          : await searchRepo.getTvDetails(arg.tmdbId);
      await storage.saveMediaDetails(arg.tmdbId, altType, altRes);
      return altRes;
    } catch (_) {
      return await storage.getCachedMediaDetails(
          arg.tmdbId, isTv ? 'movie' : 'tv');
    }
  }
});
