import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';

final mindLensRepositoryProvider = Provider<MindLensRepository>((ref) {
  return MindLensRepository(ref.read(apiClientProvider));
});

class MindLensRepository {
  final ApiClient _api;

  MindLensRepository(this._api);

  Future<Map<String, dynamic>> getInsights() async {
    final response = await _api.get('/stats/insights');
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getInfluenceStats() async {
    final response = await _api.get('/stats/influence');
    return response.data as Map<String, dynamic>;
  }
}
