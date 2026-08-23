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

  SearchRepository(this._api);

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
    final response = await _api.get(
      ApiEndpoints.searchUsers,
      queryParameters: {'query': query},
    );
    final data = response.data as Map<String, dynamic>;
    final users = data['users'] as List<dynamic>? ?? [];
    return users.map((u) => User.fromJson(u as Map<String, dynamic>)).toList();
  }

  Future<Map<String, dynamic>> getMovieDetails(int tmdbId) async {
    final response = await _api.get(ApiEndpoints.tmdbMovie(tmdbId));
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getTvDetails(int tmdbId) async {
    final response = await _api.get(ApiEndpoints.tmdbTv(tmdbId));
    return response.data as Map<String, dynamic>;
  }

  Future<List<MediaResult>> getTrending() async {
    final response = await _api.get(ApiEndpoints.tmdbTrending);
    final data = response.data as Map<String, dynamic>;
    final results = data['results'] as List<dynamic>? ?? [];
    return results
        .map((e) => MediaResult.fromJson(e as Map<String, dynamic>))
        .where((r) => r.mediaType == 'movie' || r.mediaType == 'tv')
        .take(10)
        .toList();
  }

  Future<List<MediaResult>> getPopular() async {
    final response = await _api.get(ApiEndpoints.tmdbPopular);
    final data = response.data as Map<String, dynamic>;
    final results = data['results'] as List<dynamic>? ?? [];
    return results
        .map((e) => MediaResult.fromJson(e as Map<String, dynamic>))
        .take(10)
        .toList();
  }
}

final tmdbMediaDetailsProvider = FutureProvider.family<Map<String, dynamic>?, ({int tmdbId, String mediaType})>((ref, arg) async {
  if (arg.tmdbId <= 0) return null;
  final searchRepo = ref.read(searchRepositoryProvider);
  try {
    if (arg.mediaType == 'tv') {
      return await searchRepo.getTvDetails(arg.tmdbId);
    } else {
      return await searchRepo.getMovieDetails(arg.tmdbId);
    }
  } catch (e) {
    return null;
  }
});
