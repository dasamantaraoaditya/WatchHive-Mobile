import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../shared/models/user.dart';

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository(ref.read(apiClientProvider));
});

class UserRepository {
  final ApiClient _api;

  UserRepository(this._api);

  Future<User> getCurrentUser() async {
    final response = await _api.get(ApiEndpoints.me);
    final data = response.data as Map<String, dynamic>;
    return User.fromJson(data['user'] as Map<String, dynamic>);
  }

  Future<List<User>> getFollowing(String userId) async {
    final response = await _api.get(ApiEndpoints.following(userId));
    final list = response.data as List<dynamic>;
    return list.map((item) {
      final userJson = (item is Map<String, dynamic>) ? (item['following'] ?? item['user'] ?? item) : item;
      return User.fromJson(userJson as Map<String, dynamic>);
    }).toList();
  }

  Future<List<User>> getFollowers(String userId) async {
    final response = await _api.get(ApiEndpoints.followers(userId));
    final list = response.data as List<dynamic>;
    return list.map((item) {
      final userJson = (item is Map<String, dynamic>) ? (item['follower'] ?? item['user'] ?? item) : item;
      return User.fromJson(userJson as Map<String, dynamic>);
    }).toList();
  }
}
