import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';

final watchlistRepositoryProvider = Provider<WatchlistRepository>((ref) {
  return WatchlistRepository(ref.read(apiClientProvider));
});

final isInWatchlistProvider = FutureProvider.family<bool, int>((ref, tmdbId) async {
  final repo = ref.read(watchlistRepositoryProvider);
  return await repo.isInWatchlist(tmdbId);
});

class WatchlistRepository {
  final ApiClient _api;

  WatchlistRepository(this._api);

  Future<Map<String, dynamic>> getWatchlist() async {
    final response = await _api.get('/lists/watchlist');
    return response.data as Map<String, dynamic>;
  }

  Future<bool> isInWatchlist(int tmdbId) async {
    try {
      final data = await getWatchlist();
      final items = data['items'] as List<dynamic>? ?? [];
      return items.any((item) {
        final id = item['tmdbId'];
        return id == tmdbId || id == tmdbId.toString();
      });
    } catch (_) {
      return false;
    }
  }

  Future<void> addToWatchlist({
    required int tmdbId,
    required String title,
    required String mediaType,
    String? posterPath,
    String? overview,
    String? suggestedByUserId,
  }) async {
    final watchlistData = await getWatchlist();
    final listId = watchlistData['id'] as String;

    await _api.post('/lists/$listId/items', data: {
      'tmdbId': tmdbId,
      'title': title,
      'mediaType': mediaType == 'TV_SHOW' || mediaType == 'tv' ? 'tv' : 'movie',
      'posterPath': posterPath,
      'overview': overview,
      'suggestedByUserId': suggestedByUserId,
    });
  }

  Future<void> removeFromWatchlist(String itemId) async {
    await _api.delete('/lists/items/$itemId');
  }

  Future<void> removeFromWatchlistByTmdbId(int tmdbId) async {
    final watchlistData = await getWatchlist();
    final listId = watchlistData['id'] as String;
    await _api.delete('/lists/$listId/items/$tmdbId');
  }

  Future<void> removeWatchlistItemById(String itemId) async {
    await _api.delete('/lists/items/$itemId');
  }
}


