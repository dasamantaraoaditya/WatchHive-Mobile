import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/auth/auth_manager.dart';
import '../../../shared/models/user.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.read(apiClientProvider), ref.read(authManagerProvider));
});

class AuthRepository {
  final ApiClient _api;
  final AuthManager _authManager;

  AuthRepository(this._api, this._authManager);

  Future<User> login({required String email, required String password}) async {
    final response = await _api.post(
      ApiEndpoints.login,
      data: {'email': email, 'password': password},
    );
    final data = response.data as Map<String, dynamic>;
    await _authManager.saveTokens(
      accessToken: data['accessToken'] as String,
      refreshToken: data['refreshToken'] as String,
    );
    return User.fromJson(data['user'] as Map<String, dynamic>);
  }

  Future<User> register({
    required String username,
    required String email,
    required String password,
  }) async {
    final response = await _api.post(
      ApiEndpoints.register,
      data: {'username': username, 'email': email, 'password': password},
    );
    final data = response.data as Map<String, dynamic>;
    await _authManager.saveTokens(
      accessToken: data['accessToken'] as String,
      refreshToken: data['refreshToken'] as String,
    );
    return User.fromJson(data['user'] as Map<String, dynamic>);
  }

  Future<User> googleSignIn(String idToken) async {
    final response = await _api.post(
      ApiEndpoints.googleAuth,
      data: {'idToken': idToken},
    );
    final data = response.data as Map<String, dynamic>;
    await _authManager.saveTokens(
      accessToken: data['accessToken'] as String,
      refreshToken: data['refreshToken'] as String,
    );
    return User.fromJson(data['user'] as Map<String, dynamic>);
  }

  Future<void> logout() async {
    try {
      await _api.post(ApiEndpoints.logout);
    } catch (_) {}
    await _authManager.logout();
  }

  Future<void> forgotPassword(String email) async {
    await _api.post(ApiEndpoints.forgotPassword, data: {'email': email});
  }

  Future<User> getMe() async {
    final response = await _api.get(ApiEndpoints.me);
    final data = response.data as Map<String, dynamic>;
    final userJson = data.containsKey('user') ? data['user'] as Map<String, dynamic> : data;
    var user = User.fromJson(userJson);

    // /users/me backend endpoint hardcodes followers and following to 0.
    // Fetch live follow stats to provide accurate counts.
    if (user.id.isNotEmpty) {
      try {
        final statsRes = await _api.get(ApiEndpoints.followStats(user.id));
        if (statsRes.data is Map<String, dynamic>) {
          final s = statsRes.data as Map<String, dynamic>;
          int parseInt(dynamic v) {
            if (v == null) return 0;
            if (v is num) return v.toInt();
            if (v is String) return int.tryParse(v) ?? 0;
            return 0;
          }

          user = user.copyWith(
            followersCount: parseInt(s['followersCount'] ?? s['followers']),
            followingCount: parseInt(s['followingCount'] ?? s['following']),
          );
        }
      } catch (_) {}
    }
    return user;
  }
}
