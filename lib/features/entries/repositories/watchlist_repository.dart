import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';

final watchlistRepositoryProvider = Provider<WatchlistRepository>((ref) {
  return WatchlistRepository(ref.read(apiClientProvider));
});

class WatchlistRepository {
  final ApiClient _api;

  WatchlistRepository(this._api);

  Future<Map<String, dynamic>> getWatchlist() async {
    final response = await _api.get('/lists/watchlist');
    return response.data as Map<String, dynamic>;
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
}
