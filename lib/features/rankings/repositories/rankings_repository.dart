import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../models/ranking_stack.dart';

final rankingsRepositoryProvider = Provider<RankingsRepository>((ref) {
  return RankingsRepository(ref.read(apiClientProvider));
});

class RankingsRepository {
  final ApiClient _api;

  RankingsRepository(this._api);

  Future<List<RankingStack>> getMyRankingStacks() async {
    final response = await _api.get('/lists');
    final data = response.data;
    if (data is! List) return [];
    
    return data
        .where((e) => e is Map<String, dynamic> && e['type'] == 'RANKING_STACK')
        .map((e) => RankingStack.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<({RankingStack stack, List<RankedItem> items})> getRankedStack(String listId, {String? genre}) async {
    final query = genre != null && genre.isNotEmpty ? '?genre=$genre' : '';
    final response = await _api.get('/lists/$listId/ranked$query');
    final data = response.data as Map<String, dynamic>;

    final listJson = data['list'] as Map<String, dynamic>? ?? {};
    final rawItems = data['items'] as List<dynamic>? ?? [];

    final seen = <int>{};
    final uniqueItems = <RankedItem>[];
    for (final itemJson in rawItems) {
      if (itemJson is Map<String, dynamic>) {
        final item = RankedItem.fromJson(itemJson);
        if (!seen.contains(item.tmdbId)) {
          seen.add(item.tmdbId);
          uniqueItems.add(item);
        }
      }
    }

    final stack = RankingStack.fromJson(listJson).copyWith(items: uniqueItems);
    return (stack: stack, items: uniqueItems);
  }

  Future<RankingStack> createRankingStack({
    required String name,
    String? description,
    bool isPublic = true,
  }) async {
    final response = await _api.post(
      '/lists',
      data: {
        'name': name.trim(),
        'description': description?.trim(),
        'type': 'RANKING_STACK',
        'isPublic': isPublic,
      },
    );
    return RankingStack.fromJson(response.data as Map<String, dynamic>);
  }

  Future<RankingStack> updateRankingStack(
    String listId, {
    String? name,
    String? description,
    bool? isPublic,
  }) async {
    final response = await _api.patch(
      '/lists/$listId',
      data: {
        if (name != null) 'name': name.trim(),
        if (description != null) 'description': description.trim(),
        if (isPublic != null) 'isPublic': isPublic,
      },
    );
    return RankingStack.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> deleteRankingStack(String listId) async {
    await _api.delete('/lists/$listId');
  }

  Future<RankedItem> addItemToStack({
    required String listId,
    required int tmdbId,
    String mediaType = 'movie',
    String? suggestedByUserId,
  }) async {
    final response = await _api.post(
      '/lists/$listId/items',
      data: {
        'tmdbId': tmdbId,
        'mediaType': mediaType,
        if (suggestedByUserId != null) 'suggestedByUserId': suggestedByUserId,
      },
    );
    return RankedItem.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> removeItemFromStack({
    required String listId,
    required int tmdbId,
  }) async {
    await _api.delete('/lists/$listId/items/$tmdbId');
  }

  Future<void> reorderStack({
    required String listId,
    required List<({int tmdbId, int orderIndex})> items,
  }) async {
    await _api.patch(
      '/lists/$listId/reorder',
      data: {
        'items': items.map((e) => {'tmdbId': e.tmdbId, 'orderIndex': e.orderIndex}).toList(),
      },
    );
  }

  Future<List<RankingStack>> getUserRankings(String userId) async {
    final response = await _api.get('/lists/user/$userId/rankings');
    final data = response.data;
    if (data is! List) return [];
    return data.map((e) => RankingStack.fromJson(e as Map<String, dynamic>)).toList();
  }
}
