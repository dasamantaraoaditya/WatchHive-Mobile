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

  Future<void> removeFromWatchlist(dynamic target, {String? listId}) async {
    int? tmdbId;
    String? itemId;

    if (target is int) {
      tmdbId = target;
    } else if (target is String) {
      final parsed = int.tryParse(target);
      if (parsed != null) {
        tmdbId = parsed;
      } else {
        itemId = target;
      }
    }

    final watchlistData = await getWatchlist();
    final effectiveListId = listId ?? (watchlistData['id'] as String);

    if (tmdbId == null && itemId != null) {
      final items = watchlistData['items'] as List<dynamic>? ?? [];
      for (final it in items) {
        if (it is Map && it['id']?.toString() == itemId) {
          tmdbId = (it['tmdbId'] as num?)?.toInt() ?? int.tryParse(it['tmdbId']?.toString() ?? '');
          break;
        }
      }
    }

    if (tmdbId != null) {
      await _api.delete('/lists/$effectiveListId/items/$tmdbId');
    }
  }

  Future<void> removeFromWatchlistByTmdbId(int tmdbId, [String? listId]) async {
    await removeFromWatchlist(tmdbId, listId: listId);
  }

  Future<void> removeWatchlistItemById(String itemId, [String? listId]) async {
    await removeFromWatchlist(itemId, listId: listId);
  }
}


