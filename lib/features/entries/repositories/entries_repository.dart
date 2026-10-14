import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/services/connectivity_service.dart';
import '../../../core/services/offline_storage_service.dart';
import '../../../shared/models/entry.dart';
import '../../../shared/models/models.dart';

final entriesRepositoryProvider = Provider<EntriesRepository>((ref) {
  return EntriesRepository(
    ref.read(apiClientProvider),
    ref.read(offlineStorageServiceProvider),
    ref.read(connectivityServiceProvider.notifier),
  );
});

class EntriesRepository {
  final ApiClient _api;
  final OfflineStorageService _storage;
  final ConnectivityNotifier? _connectivity;

  EntriesRepository(this._api, [OfflineStorageService? storage, this._connectivity])
      : _storage = storage ?? OfflineStorageService();

  bool _isNetworkError(dynamic e) {
    if (e is DioException) {
      return e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.error.toString().toLowerCase().contains('socket') ||
          e.error.toString().toLowerCase().contains('network') ||
          e.error.toString().toLowerCase().contains('failed host lookup');
    }
    final str = e.toString().toLowerCase();
    return str.contains('socketexception') ||
        str.contains('network') ||
        str.contains('connection refused') ||
        str.contains('offline');
  }

  Future<({List<Entry> entries, Pagination pagination})> getEntries({
    String? type,
    String? search,
    bool? isWatching,
    String sortBy = 'watchedAt',
    String order = 'desc',
    int limit = 20,
    int offset = 0,
    String? userId,
  }) async {
    try {
      final response = await _api.get(
        ApiEndpoints.entries,
        queryParameters: {
          if (type != null) 'type': type,
          if (search != null) 'search': search,
          if (isWatching != null) 'isWatching': isWatching,
          if (userId != null) 'userId': userId,
          'sortBy': sortBy,
          'order': order,
          'limit': limit,
          'offset': offset,
        },
      );
      final data = response.data as Map<String, dynamic>;
      final parsedEntries = (data['entries'] as List<dynamic>)
          .map((e) => Entry.fromJson(e as Map<String, dynamic>))
          .toList();

      if (offset == 0 && search == null) {
        _storage.cacheEntries(parsedEntries, isWatching: isWatching);
      }

      return (
        entries: parsedEntries,
        pagination: Pagination.fromJson(data['pagination'] as Map<String, dynamic>),
      );
    } catch (e) {
      // Check for cached entries fallback on offline/network errors
      if (_isNetworkError(e) || _connectivity?.isOnline == false) {
        final cached = await _storage.getCachedEntries(
          isWatching: isWatching,
          type: type,
          userId: userId,
        );

        if (cached.isNotEmpty) {
          return (
            entries: cached,
            pagination: Pagination(
              total: cached.length,
              limit: cached.length,
              offset: 0,
              hasMore: false,
            ),
          );
        }
      }
      rethrow;
    }
  }

  Future<Entry> createEntry(Map<String, dynamic> data) async {
    try {
      final response = await _api.post(ApiEndpoints.entries, data: data);
      final body = response.data as Map<String, dynamic>;
      final entry = Entry.fromJson(body['entry'] as Map<String, dynamic>);
      await _storage.insertOrUpdateCachedEntry(entry);
      return entry;
    } catch (e) {
      final isOffline = _isNetworkError(e) || (_connectivity?.isOnline == false);
      if (isOffline) {
        final tempId = 'offline_${DateTime.now().millisecondsSinceEpoch}';
        final offlineEntry = Entry(
          id: tempId,
          userId: data['userId']?.toString() ?? 'me',
          tmdbId: (data['tmdbId'] as num?)?.toInt() ?? 0,
          title: data['title']?.toString() ?? 'Offline Watch',
          type: data['type']?.toString() ?? 'MOVIE',
          watchedAt: data['watchedAt'] != null
              ? DateTime.tryParse(data['watchedAt'].toString())?.toLocal() ?? DateTime.now()
              : DateTime.now(),
          rating: (data['rating'] as num?)?.toDouble(),
          review: data['review']?.toString(),
          tags: (data['tags'] as List<dynamic>?)?.map((t) => t.toString()).toList() ?? const [],
          isRewatch: data['isRewatch'] == true,
          isWatching: data['isWatching'] == true,
          startedAt: data['startedAt'] != null ? DateTime.tryParse(data['startedAt'].toString())?.toLocal() : null,
          completedAt: data['completedAt'] != null ? DateTime.tryParse(data['completedAt'].toString())?.toLocal() : null,
          watchLocation: data['watchLocation']?.toString(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          isPendingSync: true,
          posterPath: data['posterPath']?.toString() ?? data['poster_path']?.toString(),
          backdropPath: data['backdropPath']?.toString() ?? data['backdrop_path']?.toString(),
        );

        await _storage.enqueueSyncAction(
          action: 'CREATE_ENTRY',
          entityId: tempId,
          payload: data,
        );

        await _storage.insertOrUpdateCachedEntry(offlineEntry);
        return offlineEntry;
      }
      rethrow;
    }
  }

  Future<Entry> updateEntry(String id, Map<String, dynamic> data) async {
    try {
      final response = await _api.put(ApiEndpoints.entry(id), data: data);
      final body = response.data as Map<String, dynamic>;
      final entry = Entry.fromJson(body['entry'] as Map<String, dynamic>);
      await _storage.insertOrUpdateCachedEntry(entry);
      return entry;
    } catch (e) {
      if (_isNetworkError(e) || (_connectivity?.isOnline == false)) {
        Entry? existing;
        try {
          existing = await getEntryById(id);
        } catch (_) {}

        final updated = (existing != null)
            ? existing.copyWith(
                rating: (data['rating'] as num?)?.toDouble() ?? existing.rating,
                review: data['review']?.toString() ?? existing.review,
                watchLocation: data['watchLocation']?.toString() ?? existing.watchLocation,
                tags: (data['tags'] as List<dynamic>?)?.map((t) => t.toString()).toList() ?? existing.tags,
                isRewatch: data['isRewatch'] ?? existing.isRewatch,
                isWatching: data['isWatching'] ?? existing.isWatching,
                isPendingSync: true,
              )
            : Entry(
                id: id,
                userId: 'me',
                tmdbId: (data['tmdbId'] as num?)?.toInt() ?? 0,
                title: data['title']?.toString() ?? 'Watch Entry',
                type: data['type']?.toString() ?? 'MOVIE',
                watchedAt: DateTime.now(),
                createdAt: DateTime.now(),
                isPendingSync: true,
              );

        await _storage.enqueueSyncAction(
          action: 'UPDATE_ENTRY',
          entityId: id,
          payload: data,
        );
        await _storage.insertOrUpdateCachedEntry(updated);
        return updated;
      }
      rethrow;
    }
  }

  Future<void> deleteEntry(String id) async {
    try {
      await _api.delete(ApiEndpoints.entry(id));
      await _storage.removeCachedEntry(id);
    } catch (e) {
      if (_isNetworkError(e) || (_connectivity?.isOnline == false)) {
        await _storage.enqueueSyncAction(
          action: 'DELETE_ENTRY',
          entityId: id,
          payload: {},
        );
        await _storage.removeCachedEntry(id);
        return;
      }
      rethrow;
    }
  }

  Future<Entry> getEntryById(String id) async {
    try {
      final response = await _api.get(ApiEndpoints.entry(id));
      final body = response.data as Map<String, dynamic>;
      final entryData = body.containsKey('entry') ? body['entry'] : body;
      final entry = Entry.fromJson(entryData as Map<String, dynamic>);
      await _storage.insertOrUpdateCachedEntry(entry);
      return entry;
    } catch (e) {
      final cached = await _storage.getCachedEntries();
      for (final item in cached) {
        if (item.id == id) return item;
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getStats() async {
    final response = await _api.get(ApiEndpoints.entryStats);
    final data = response.data as Map<String, dynamic>;
    return data['stats'] as Map<String, dynamic>;
  }

  Future<Entry?> getEntryForTmdbId(int tmdbId, {String? userId, String? title}) async {
    try {
      final res = await getEntries(
        userId: userId,
        search: title,
        limit: 50,
      );
      for (final entry in res.entries) {
        if (entry.tmdbId == tmdbId) {
          return entry;
        }
      }
      if (title != null && title.isNotEmpty) {
        final broadRes = await getEntries(
          userId: userId,
          limit: 100,
        );
        for (final entry in broadRes.entries) {
          if (entry.tmdbId == tmdbId) {
            return entry;
          }
        }
      }
      return null;
    } catch (_) {
      // Fallback to local cache search
      final cached = await _storage.getCachedEntries(userId: userId);
      for (final entry in cached) {
        if (entry.tmdbId == tmdbId) return entry;
      }
      return null;
    }
  }
}
