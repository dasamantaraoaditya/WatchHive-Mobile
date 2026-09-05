import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watchhive_mobile/core/api/api_client.dart';
import 'package:watchhive_mobile/core/auth/auth_manager.dart';
import 'package:watchhive_mobile/features/auth/providers/auth_provider.dart';
import 'package:watchhive_mobile/features/auth/repositories/auth_repository.dart';
import 'package:watchhive_mobile/shared/models/user.dart';

class MockAuthRepoThrowingNetworkError extends AuthRepository {
  MockAuthRepoThrowingNetworkError(AuthManager authManager)
      : super(ApiClient(authManager), authManager);

  @override
  Future<User> getMe() async {
    throw DioException(
      type: DioExceptionType.connectionError,
      requestOptions: RequestOptions(path: '/auth/me'),
      error: 'Network connection lost',
    );
  }
}

class MockAuthRepoThrowing401 extends AuthRepository {
  MockAuthRepoThrowing401(AuthManager authManager)
      : super(ApiClient(authManager), authManager);

  @override
  Future<User> getMe() async {
    throw DioException(
      type: DioExceptionType.badResponse,
      requestOptions: RequestOptions(path: '/auth/me'),
      response: Response(
        statusCode: 401,
        requestOptions: RequestOptions(path: '/auth/me'),
      ),
    );
  }
}

class MockAuthRepoSuccess extends AuthRepository {
  MockAuthRepoSuccess(AuthManager authManager)
      : super(ApiClient(authManager), authManager);

  @override
  Future<User> getMe() async {
    return User(
      id: 'u1',
      username: 'moviebuff',
      email: 'buff@watchhive.com',
      createdAt: DateTime(2025, 1, 1),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('AuthManager Session Tests', () {
    test('hasValidSession returns false when storage is empty', () async {
      FlutterSecureStorage.setMockInitialValues({});
      final authManager = AuthManager();
      final hasSession = await authManager.hasValidSession();
      expect(hasSession, isFalse);
    });

    test('hasValidSession returns true when only refreshToken is present', () async {
      FlutterSecureStorage.setMockInitialValues({
        'wh_refresh_token': 'sample_valid_refresh_token_xyz',
      });
      final authManager = AuthManager();
      final hasSession = await authManager.hasValidSession();
      expect(hasSession, isTrue);
    });

    test('hasValidSession returns true when both tokens are present', () async {
      FlutterSecureStorage.setMockInitialValues({
        'wh_access_token': 'sample_access_token',
        'wh_refresh_token': 'sample_refresh_token',
      });
      final authManager = AuthManager();
      final hasSession = await authManager.hasValidSession();
      expect(hasSession, isTrue);
    });

    test('logout deletes both tokens from secure storage', () async {
      FlutterSecureStorage.setMockInitialValues({
        'wh_access_token': 'sample_access_token',
        'wh_refresh_token': 'sample_refresh_token',
      });
      final authManager = AuthManager();
      await authManager.logout();

      final access = await authManager.getAccessToken();
      final refresh = await authManager.getRefreshToken();
      final hasSession = await authManager.hasValidSession();

      expect(access, isNull);
      expect(refresh, isNull);
      expect(hasSession, isFalse);
    });
  });

  group('AuthNotifier Session Resilience Tests', () {
    test('Does NOT logout user on network connection drops / offline', () async {
      FlutterSecureStorage.setMockInitialValues({
        'wh_access_token': 'access_123',
        'wh_refresh_token': 'refresh_123',
      });
      final authManager = AuthManager();

      final container = ProviderContainer(
        overrides: [
          authManagerProvider.overrideWithValue(authManager),
          authRepositoryProvider.overrideWithValue(
            MockAuthRepoThrowingNetworkError(authManager),
          ),
        ],
      );
      addTearDown(container.dispose);

      final authState = await container.read(authStateProvider.future);

      // User must remain authenticated so offline session is preserved
      expect(authState.isAuthenticated, isTrue);
      // Tokens must NOT be deleted
      final storedToken = await authManager.getAccessToken();
      expect(storedToken, equals('access_123'));
    });

    test('Logs out user when getMe returns unrecoverable 401 Unauthorized', () async {
      FlutterSecureStorage.setMockInitialValues({
        'wh_access_token': 'expired_access',
        'wh_refresh_token': 'expired_refresh',
      });
      final authManager = AuthManager();

      final container = ProviderContainer(
        overrides: [
          authManagerProvider.overrideWithValue(authManager),
          authRepositoryProvider.overrideWithValue(
            MockAuthRepoThrowing401(authManager),
          ),
        ],
      );
      addTearDown(container.dispose);

      final authState = await container.read(authStateProvider.future);

      expect(authState.isAuthenticated, isFalse);
      // Tokens must be wiped
      final storedToken = await authManager.getAccessToken();
      expect(storedToken, isNull);
    });

    test('Successfully authenticates user when getMe succeeds', () async {
      FlutterSecureStorage.setMockInitialValues({
        'wh_access_token': 'valid_access',
        'wh_refresh_token': 'valid_refresh',
      });
      final authManager = AuthManager();

      final container = ProviderContainer(
        overrides: [
          authManagerProvider.overrideWithValue(authManager),
          authRepositoryProvider.overrideWithValue(
            MockAuthRepoSuccess(authManager),
          ),
        ],
      );
      addTearDown(container.dispose);

      final authState = await container.read(authStateProvider.future);

      expect(authState.isAuthenticated, isTrue);
      expect(authState.user?.username, equals('moviebuff'));
    });
  });
}
