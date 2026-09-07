import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watchhive_mobile/core/api/api_client.dart';
import 'package:watchhive_mobile/core/api/api_endpoints.dart';
import 'package:watchhive_mobile/features/notifications/repositories/push_repository.dart';

class MockApiClient extends Fake implements ApiClient {
  String? lastPath;
  dynamic lastData;
  int mockStatusCode = 200;
  bool shouldThrow = false;

  @override
  Future<Response<T>> post<T>(
    String path, {
    data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    lastPath = path;
    lastData = data;
    if (shouldThrow) throw Exception('Network error');
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      statusCode: mockStatusCode,
      data: {'success': true} as T,
    );
  }

  @override
  Future<Response<T>> delete<T>(
    String path, {
    data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    lastPath = path;
    lastData = data;
    if (shouldThrow) throw Exception('Network error');
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      statusCode: mockStatusCode,
      data: {'success': true} as T,
    );
  }
}

void main() {
  group('PushRepository Tests', () {
    late MockApiClient mockApi;
    late PushRepository pushRepo;

    setUp(() {
      mockApi = MockApiClient();
      pushRepo = PushRepository(mockApi);
    });

    test('registerDeviceToken sends token and platform to ApiEndpoints.registerDeviceToken', () async {
      final success = await pushRepo.registerDeviceToken('fcm_test_token_123', platform: 'android');

      expect(success, true);
      expect(mockApi.lastPath, ApiEndpoints.registerDeviceToken);
      expect(mockApi.lastData, {
        'token': 'fcm_test_token_123',
        'platform': 'android',
      });
    });

    test('registerDeviceToken returns false when API fails', () async {
      mockApi.shouldThrow = true;
      final success = await pushRepo.registerDeviceToken('fcm_test_token_123');

      expect(success, false);
    });

    test('unregisterDeviceToken sends token to ApiEndpoints.unregisterDeviceToken', () async {
      final success = await pushRepo.unregisterDeviceToken('fcm_test_token_123');

      expect(success, true);
      expect(mockApi.lastPath, ApiEndpoints.unregisterDeviceToken);
      expect(mockApi.lastData, {'token': 'fcm_test_token_123'});
    });

    test('unregisterDeviceToken returns false on failure', () async {
      mockApi.shouldThrow = true;
      final success = await pushRepo.unregisterDeviceToken('fcm_test_token_123');

      expect(success, false);
    });

    test('sendTestPush calls ApiEndpoints.testPush', () async {
      final success = await pushRepo.sendTestPush();

      expect(success, true);
      expect(mockApi.lastPath, ApiEndpoints.testPush);
    });
  });
}
