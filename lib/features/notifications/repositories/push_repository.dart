import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';

final pushRepositoryProvider = Provider<PushRepository>((ref) {
  return PushRepository(ref.read(apiClientProvider));
});

class PushRepository {
  final ApiClient _api;

  PushRepository(this._api);

  /// Register mobile device FCM token on the backend server
  Future<bool> registerDeviceToken(String token, {String? platform}) async {
    try {
      final effectivePlatform = platform ??
          (kIsWeb
              ? 'web'
              : Platform.isIOS
                  ? 'ios'
                  : 'android');

      final response = await _api.post(
        ApiEndpoints.registerDeviceToken,
        data: {
          'token': token,
          'platform': effectivePlatform,
        },
      );

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('[PushRepository] Failed to register device token: $e');
      return false;
    }
  }

  /// Unregister device FCM token from backend upon logout
  Future<bool> unregisterDeviceToken(String token) async {
    try {
      final response = await _api.delete(
        ApiEndpoints.unregisterDeviceToken,
        data: {'token': token},
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[PushRepository] Failed to unregister device token: $e');
      return false;
    }
  }

  /// Send a test push notification to the current user's devices
  Future<bool> sendTestPush() async {
    try {
      final response = await _api.post(ApiEndpoints.testPush);
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[PushRepository] Failed to send test push: $e');
      return false;
    }
  }
}
