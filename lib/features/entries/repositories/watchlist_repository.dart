import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';

import '../../../core/services/offline_storage_service.dart';

final watchlistRepositoryProvider = Provider<WatchlistRepository>((ref) {
  return WatchlistRepository(
    ref.read(apiClientProvider),
    ref.read(offlineStorageServiceProvider),
  );
});

final isInWatchlistProvider = FutureProvider.family<bool, int>((ref, tmdbId) async {
  final repo = ref.read(watchlistRepositoryProvider);
  return await repo.isInWatchlist(tmdbId);
});

class WatchlistRepository {
  final ApiClient _api;
  final OfflineStorageService _storage;

  WatchlistRepository(this._api, [OfflineStorageService? storage])
      : _storage = storage ?? OfflineStorageService();

  Future<Map<String, dynamic>> getWatchlist() async {
    try {
      final response = await _api.get('/lists/watchlist');
      final data = response.data as Map<String, dynamic>;
      final rawItems = data['items'] as List<dynamic>?;
      if (rawItems != null) {
        final list = rawItems
            .whereType<Map<String, dynamic>>()
            .toList();
        _storage.cacheWatchlist(list);
      }
      return data;
    } catch (e) {
      final cached = await _storage.getCachedWatchlist();
      if (cached.isNotEmpty) {
        return {
          'id': 'cached_watchlist',
          'items': cached,
          'isOffline': true,
        };
      }
      rethrow;
    }
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
    final payload = {
      'tmdbId': tmdbId,
      'title': title,
      'mediaType': mediaType == 'TV_SHOW' || mediaType == 'tv' ? 'tv' : 'movie',
      if (posterPath != null && posterPath.isNotEmpty) 'posterPath': posterPath,
      if (overview != null && overview.isNotEmpty) 'overview': overview,
      if (suggestedByUserId != null && suggestedByUserId.isNotEmpty) 'suggestedByUserId': suggestedByUserId,
    };

    try {
      final watchlistData = await getWatchlist();
      final listId = watchlistData['id'] as String;
      if (listId != 'cached_watchlist') {
        await _api.post('/lists/$listId/items', data: payload);
      } else {
        throw Exception('Offline mode');
      }
    } catch (e) {
      // Offline fallback: enqueue sync action & optimistically add to local cached watchlist
      await _storage.enqueueSyncAction(
        action: 'ADD_WATCHLIST_ITEM',
        entityId: 'wl_$tmdbId',
        payload: payload,
      );
      final currentList = await _storage.getCachedWatchlist();
      currentList.insert(0, {
        'id': 'temp_$tmdbId',
        'tmdbId': tmdbId,
        'title': title,
        'mediaType': mediaType,
        'posterPath': posterPath,
        'overview': overview,
        'addedAt': DateTime.now().toIso8601String(),
      });
      await _storage.cacheWatchlist(currentList);
    }
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

    try {
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

      if (effectiveListId != 'cached_watchlist' && tmdbId != null) {
        await _api.delete('/lists/$effectiveListId/items/$tmdbId');
      } else {
        throw Exception('Offline mode');
      }
    } catch (e) {
      if (tmdbId != null) {
        await _storage.enqueueSyncAction(
          action: 'REMOVE_WATCHLIST_ITEM',
          entityId: 'wl_$tmdbId',
          payload: {'itemId': tmdbId.toString()},
        );
        final currentList = await _storage.getCachedWatchlist();
        currentList.removeWhere((item) => item['tmdbId'] == tmdbId || item['tmdbId'] == tmdbId.toString());
        await _storage.cacheWatchlist(currentList);
      }
    }
  }

  Future<void> removeFromWatchlistByTmdbId(int tmdbId, [String? listId]) async {
    await removeFromWatchlist(tmdbId, listId: listId);
  }

  Future<void> removeWatchlistItemById(String itemId, [String? listId]) async {
    await removeFromWatchlist(itemId, listId: listId);
  }
}


