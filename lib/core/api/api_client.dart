import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/auth_manager.dart';
import 'api_endpoints.dart';

/// Singleton Dio client with JWT auth interceptors and token refresh.
final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(ref.read(authManagerProvider));
});

class ApiClient {
  late final Dio _dio;
  final AuthManager _authManager;

  ApiClient(this._authManager) {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiEndpoints.baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    _dio.interceptors.addAll([
      _AuthInterceptor(_authManager, _dio),
      LogInterceptor(
        request: false,
        responseBody: false,
        error: true,
      ),
    ]);
  }

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) =>
      _dio.get<T>(path, queryParameters: queryParameters, options: options);

  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) =>
      _dio.post<T>(path, data: data, queryParameters: queryParameters, options: options);

  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Options? options,
  }) =>
      _dio.put<T>(path, data: data, options: options);

  Future<Response<T>> patch<T>(
    String path, {
    dynamic data,
    Options? options,
  }) =>
      _dio.patch<T>(path, data: data, options: options);

  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Options? options,
  }) =>
      _dio.delete<T>(path, data: data, options: options);
}

class _AuthInterceptor extends Interceptor {
  final AuthManager _authManager;
  final Dio _dio;
  Completer<bool>? _refreshCompleter;

  _AuthInterceptor(this._authManager, this._dio);

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _authManager.getAccessToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    // If not a 401 or if it's the refresh endpoint itself, pass through
    if (err.response?.statusCode != 401 ||
        err.requestOptions.path.contains('/auth/refresh')) {
      return handler.next(err);
    }

    // If another request is currently refreshing tokens, await its completion
    if (_refreshCompleter != null) {
      try {
        final refreshed = await _refreshCompleter!.future;
        if (refreshed) {
          final newToken = await _authManager.getAccessToken();
          err.requestOptions.headers['Authorization'] = 'Bearer $newToken';
          final response = await _dio.fetch(err.requestOptions);
          return handler.resolve(response);
        }
      } on DioException catch (retryErr) {
        return handler.next(retryErr);
      } catch (_) {}
      return handler.next(err);
    }

    final completer = Completer<bool>();
    _refreshCompleter = completer;

    try {
      final refreshed = await _authManager.refreshTokens();
      completer.complete(refreshed);

      if (refreshed) {
        final newToken = await _authManager.getAccessToken();
        err.requestOptions.headers['Authorization'] = 'Bearer $newToken';
        final response = await _dio.fetch(err.requestOptions);
        return handler.resolve(response);
      } else {
        await _authManager.logout();
      }
    } on DioException catch (retryErr) {
      return handler.next(retryErr);
    } catch (e) {
      completer.complete(false);
      await _authManager.logout();
    } finally {
      _refreshCompleter = null;
    }

    handler.next(err);
  }
}
