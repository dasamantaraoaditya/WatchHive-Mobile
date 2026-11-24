import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../api/api_endpoints.dart';
import '../../shared/models/user.dart';

final authManagerProvider = Provider<AuthManager>((ref) {
  return AuthManager();
});

/// Outcome of attempting to refresh JWT tokens.
enum TokenRefreshResult {
  /// Token refreshed and saved successfully.
  success,

  /// Token was rejected by backend as invalid, expired, or revoked (HTTP 401/403).
  invalidToken,

  /// Refresh failed due to network connectivity issues or transient server errors.
  networkError,
}

/// Manages JWT access/refresh token storage and silent token refresh.
class AuthManager {
  static const _accessTokenKey = 'wh_access_token';
  static const _refreshTokenKey = 'wh_refresh_token';
  static const _cachedUserKey = 'wh_cached_user';

  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  // --- In-Memory Fast Cache ---
  String? _cachedAccessToken;
  String? _cachedRefreshToken;
  User? _cachedUser;

  // --- Token Accessors ---

  Future<String?> getAccessToken() async {
    if (_cachedAccessToken != null && _cachedAccessToken!.isNotEmpty) {
      return _cachedAccessToken;
    }
    _cachedAccessToken = await _storage.read(key: _accessTokenKey);
    return _cachedAccessToken;
  }

  Future<String?> getRefreshToken() async {
    if (_cachedRefreshToken != null && _cachedRefreshToken!.isNotEmpty) {
      return _cachedRefreshToken;
    }
    _cachedRefreshToken = await _storage.read(key: _refreshTokenKey);
    return _cachedRefreshToken;
  }

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    _cachedAccessToken = accessToken;
    _cachedRefreshToken = refreshToken;
    await Future.wait([
      _storage.write(key: _accessTokenKey, value: accessToken),
      _storage.write(key: _refreshTokenKey, value: refreshToken),
    ]);
  }

  Future<void> saveUser(User user) async {
    _cachedUser = user;
    try {
      final jsonStr = jsonEncode(user.toJson());
      await _storage.write(key: _cachedUserKey, value: jsonStr);
    } catch (_) {}
  }

  Future<User?> getCachedUser() async {
    if (_cachedUser != null) {
      return _cachedUser;
    }
    try {
      final jsonStr = await _storage.read(key: _cachedUserKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final data = jsonDecode(jsonStr) as Map<String, dynamic>;
        _cachedUser = User.fromJson(data);
        return _cachedUser;
      }
    } catch (_) {}
    return null;
  }

  Future<bool> hasValidSession() async {
    final refreshToken = await getRefreshToken();
    if (refreshToken != null && refreshToken.isNotEmpty) {
      return true;
    }
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }

  Future<void> logout() async {
    _cachedAccessToken = null;
    _cachedRefreshToken = null;
    _cachedUser = null;
    await Future.wait([
      _storage.delete(key: _accessTokenKey),
      _storage.delete(key: _refreshTokenKey),
      _storage.delete(key: _cachedUserKey),
    ]);
  }

  Future<TokenRefreshResult>? _ongoingRefresh;

  /// Attempts to silently refresh the access token using the stored refresh token.
  /// Deduplicates concurrent calls so only one HTTP refresh is executed.
  /// Returns [TokenRefreshResult.success], [TokenRefreshResult.invalidToken], or [TokenRefreshResult.networkError].
  Future<TokenRefreshResult> refreshTokens() async {
    if (_ongoingRefresh != null) {
      return _ongoingRefresh!;
    }
    _ongoingRefresh = _executeRefresh();
    try {
      return await _ongoingRefresh!;
    } finally {
      _ongoingRefresh = null;
    }
  }

  Future<TokenRefreshResult> _executeRefresh() async {
    try {
      final refreshToken = await getRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) {
        return TokenRefreshResult.invalidToken;
      }

      final dio = Dio(BaseOptions(
        baseUrl: ApiEndpoints.baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
      ));
      final response = await dio.post(
        ApiEndpoints.refreshToken,
        data: {'refreshToken': refreshToken},
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        await saveTokens(
          accessToken: data['accessToken'] as String,
          refreshToken: data['refreshToken'] as String,
        );
        return TokenRefreshResult.success;
      }
      return TokenRefreshResult.invalidToken;
    } on DioException catch (dioErr) {
      final status = dioErr.response?.statusCode;
      // 401 or 403 explicitly indicates the refresh token is expired, revoked, or invalid
      if (status == 401 || status == 403) {
        return TokenRefreshResult.invalidToken;
      }
      // Any other HTTP code or timeout/connection drop is a network/transient issue
      return TokenRefreshResult.networkError;
    } catch (_) {
      return TokenRefreshResult.networkError;
    }
  }
}
