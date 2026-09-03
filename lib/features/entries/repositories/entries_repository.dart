import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../shared/models/entry.dart';
import '../../../shared/models/models.dart';

final entriesRepositoryProvider = Provider<EntriesRepository>((ref) {
  return EntriesRepository(ref.read(apiClientProvider));
});

class EntriesRepository {
  final ApiClient _api;

  EntriesRepository(this._api);

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
    return (
      entries: (data['entries'] as List<dynamic>)
          .map((e) => Entry.fromJson(e as Map<String, dynamic>))
          .toList(),
      pagination: Pagination.fromJson(data['pagination'] as Map<String, dynamic>),
    );
  }

  Future<Entry> createEntry(Map<String, dynamic> data) async {
    final response = await _api.post(ApiEndpoints.entries, data: data);
    final body = response.data as Map<String, dynamic>;
    return Entry.fromJson(body['entry'] as Map<String, dynamic>);
  }

  Future<Entry> updateEntry(String id, Map<String, dynamic> data) async {
    final response = await _api.put(ApiEndpoints.entry(id), data: data);
    final body = response.data as Map<String, dynamic>;
    return Entry.fromJson(body['entry'] as Map<String, dynamic>);
  }

  Future<void> deleteEntry(String id) async {
    await _api.delete(ApiEndpoints.entry(id));
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
      return null;
    }
  }
}
