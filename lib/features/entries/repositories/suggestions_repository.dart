import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../shared/models/suggestion.dart';

final suggestionsRepositoryProvider = Provider<SuggestionsRepository>((ref) {
  return SuggestionsRepository(ref.read(apiClientProvider));
});

class SuggestionsRepository {
  final ApiClient _api;

  SuggestionsRepository(this._api);

  Future<List<GroupedSuggestion>> getMySuggestions() async {
    final response = await _api.get('/suggestions/me');
    final list = response.data as List<dynamic>;
    return list.map((item) => GroupedSuggestion.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<void> sendSuggestion({
    String? toUserId,
    List<String>? toUserIds,
    required int tmdbId,
    required String title,
    String? mediaType,
    String? message,
  }) async {
    await _api.post(
      ApiEndpoints.suggestions,
      data: {
        if (toUserId != null) 'toUserId': toUserId,
        if (toUserIds != null) 'toUserIds': toUserIds,
        'tmdbId': tmdbId,
        'title': title,
        if (mediaType != null) 'mediaType': mediaType,
        if (message != null) 'message': message,
      },
    );
  }

  Future<void> deleteSuggestion(String id) async {
    await _api.delete('/suggestions/$id');
  }
}
