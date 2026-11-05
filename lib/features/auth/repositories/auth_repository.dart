import 'package:dio/dio.dart';
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

  String _cleanEmail(String email) {
    return email
        .replaceAll(RegExp(r'[\u0000-\u001F\u007F\u00A0\u2000-\u200D\u2028\u2029\u202F\u205F\u2060\u3000\uFEFF\s]+'), '')
        .trim()
        .toLowerCase();
  }

  Future<User> login({required String email, required String password}) async {
    final response = await _api.post(
      ApiEndpoints.login,
      data: {'email': _cleanEmail(email), 'password': password},
    );
    final data = response.data as Map<String, dynamic>;
    await _authManager.saveTokens(
      accessToken: data['accessToken'] as String,
      refreshToken: data['refreshToken'] as String,
    );
    final user = User.fromJson(data['user'] as Map<String, dynamic>);
    await _authManager.saveUser(user);
    return user;
  }

  Future<Map<String, dynamic>> requestEmailOtp(String email) async {
    final response = await _api.post(
      ApiEndpoints.requestEmailOtp,
      data: {'email': _cleanEmail(email)},
    );
    return response.data as Map<String, dynamic>;
  }

  Future<User> verifyEmailOtp({
    required String email,
    required String code,
  }) async {
    final response = await _api.post(
      ApiEndpoints.verifyEmailOtp,
      data: {
        'email': _cleanEmail(email),
        'code': code.trim(),
      },
    );
    final data = response.data as Map<String, dynamic>;
    await _authManager.saveTokens(
      accessToken: data['accessToken'] as String,
      refreshToken: data['refreshToken'] as String,
    );
    final user = User.fromJson(data['user'] as Map<String, dynamic>);
    await _authManager.saveUser(user);
    return user;
  }

  Future<Map<String, dynamic>> register({
    required String username,
    required String email,
    required String password,
  }) async {
    final response = await _api.post(
      ApiEndpoints.register,
      data: {'username': username.trim(), 'email': _cleanEmail(email), 'password': password},
    );
    return response.data as Map<String, dynamic>;
  }

  Future<User> verifyEmail({
    required String token,
    String? email,
  }) async {
    final response = await _api.post(
      ApiEndpoints.verifyEmail,
      data: {
        'token': token.trim(),
        if (email != null && email.isNotEmpty) 'email': _cleanEmail(email),
      },
    );
    final data = response.data as Map<String, dynamic>;
    await _authManager.saveTokens(
      accessToken: data['accessToken'] as String,
      refreshToken: data['refreshToken'] as String,
    );
    final user = User.fromJson(data['user'] as Map<String, dynamic>);
    await _authManager.saveUser(user);
    return user;
  }

  Future<Map<String, dynamic>> resendVerification(String email) async {
    final response = await _api.post(
      ApiEndpoints.resendVerification,
      data: {'email': _cleanEmail(email)},
    );
    return response.data as Map<String, dynamic>;
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
    final user = User.fromJson(data['user'] as Map<String, dynamic>);
    await _authManager.saveUser(user);
    return user;
  }

  Future<User> appleSignIn({
    required String identityToken,
    required String userIdentifier,
    String? email,
    String? givenName,
    String? familyName,
  }) async {
    final response = await _api.post(
      ApiEndpoints.appleAuth,
      data: {
        'identityToken': identityToken,
        'userIdentifier': userIdentifier,
        'email': email != null ? _cleanEmail(email) : null,
        'givenName': givenName,
        'familyName': familyName,
      },
    );
    final data = response.data as Map<String, dynamic>;
    await _authManager.saveTokens(
      accessToken: data['accessToken'] as String,
      refreshToken: data['refreshToken'] as String,
    );
    final user = User.fromJson(data['user'] as Map<String, dynamic>);
    await _authManager.saveUser(user);
    return user;
  }

  Future<void> logout() async {
    try {
      await _api.post(ApiEndpoints.logout);
    } catch (_) {}
    await _authManager.logout();
  }

  Future<Map<String, dynamic>> forgotPassword(String email) async {
    final response = await _api.post(
      ApiEndpoints.forgotPassword,
      data: {'email': _cleanEmail(email)},
    );
    if (response.data is Map<String, dynamic>) {
      final data = response.data as Map<String, dynamic>;
      if (data['emailSent'] == false) {
        throw Exception(
          data['message'] as String? ?? 'Failed to send password reset email. The email service could not dispatch the message.',
        );
      }
      return data;
    }
    return {'message': 'If that email is registered, a reset link has been sent.'};
  }

  Future<String> resetPassword({
    required String token,
    required String email,
    required String newPassword,
  }) async {
    try {
      final response = await _api.post(
        ApiEndpoints.resetPassword,
        data: {
          'token': token.trim(),
          'email': _cleanEmail(email),
          'newPassword': newPassword,
        },
      );
      if (response.data is Map<String, dynamic> && response.data['message'] != null) {
        return response.data['message'] as String;
      }
      return 'Password has been reset successfully. You can now sign in.';
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map<String, dynamic>) {
        if (data['details'] is List && (data['details'] as List).isNotEmpty) {
          final detailsList = data['details'] as List;
          final messages = detailsList
              .whereType<Map<String, dynamic>>()
              .map((d) => d['message']?.toString())
              .where((m) => m != null && m.isNotEmpty)
              .toList();
          if (messages.isNotEmpty) {
            throw Exception(messages.join('. '));
          }
        }
        if (data['error'] is String && (data['error'] as String).isNotEmpty) {
          throw Exception(data['error']);
        }
      }
      rethrow;
    }
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
    await _authManager.saveUser(user);
    return user;
  }
}
