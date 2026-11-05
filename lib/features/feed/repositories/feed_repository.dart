import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../shared/models/entry.dart';
import '../../../shared/models/models.dart';

import '../../../core/services/offline_storage_service.dart';

final feedRepositoryProvider = Provider<FeedRepository>((ref) {
  return FeedRepository(
    ref.read(apiClientProvider),
    ref.read(offlineStorageServiceProvider),
  );
});

class FeedRepository {
  final ApiClient _api;
  final OfflineStorageService _storage;

  FeedRepository(this._api, [OfflineStorageService? storage])
      : _storage = storage ?? OfflineStorageService();

  Future<({List<Entry> entries, Pagination pagination})> getFeed({
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final page = (offset / limit).floor() + 1;
      final response = await _api.get(
        ApiEndpoints.feed,
        queryParameters: {'limit': limit, 'page': page},
      );
      final data = response.data as Map<String, dynamic>;

      List<dynamic> rawItems = [];
      if (data['items'] is List) {
        rawItems = data['items'] as List<dynamic>;
      } else if (data['entries'] is List) {
        rawItems = data['entries'] as List<dynamic>;
      } else if (data['feed'] is List) {
        rawItems = data['feed'] as List<dynamic>;
      }

      final entries = <Entry>[];
      for (final item in rawItems) {
        if (item is Map<String, dynamic>) {
          try {
            entries.add(Entry.fromJson(item));
          } catch (e) {
            // Gracefully skip unparseable items
          }
        }
      }

      if (offset == 0 && entries.isNotEmpty) {
        _storage.cacheFeed(entries);
      }

      final hasMore = data['hasMore'] as bool? ?? false;
      return (
        entries: entries,
        pagination: Pagination(
          offset: offset,
          limit: limit,
          total: entries.length,
          hasMore: hasMore,
        ),
      );
    } catch (e) {
      final cached = await _storage.getCachedFeed();
      if (cached.isNotEmpty) {
        return (
          entries: cached,
          pagination: Pagination(
            offset: offset,
            limit: limit,
            total: cached.length,
            hasMore: false,
          ),
        );
      }
      rethrow;
    }
  }

  Future<List<Entry>> getCachedFeed() => _storage.getCachedFeed();

  Future<void> likeEntry(String entryId) async {
    await _api.post(ApiEndpoints.likeEntry(entryId));
  }

  Future<void> unlikeEntry(String entryId) async {
    await _api.delete(ApiEndpoints.likeEntry(entryId));
  }
}
