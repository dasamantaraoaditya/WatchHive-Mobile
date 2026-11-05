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
      _TmdBCacheInterceptor(),
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

// ─── TMDb In-Memory SWR Cache Interceptor ────────────────────────────────────

class _TmdBCacheEntry {
  final dynamic data;
  final int statusCode;
  final Headers headers;
  final DateTime expiresAt;

  _TmdBCacheEntry({
    required this.data,
    required this.statusCode,
    required this.headers,
    required this.expiresAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

class _TmdBCacheInterceptor extends Interceptor {
  final Map<String, _TmdBCacheEntry> _cache = {};
  final Map<String, Completer<Response>> _inFlight = {};
  static const int _maxEntries = 500;

  String _buildKey(RequestOptions options) {
    final queryStr = options.queryParameters.entries
        .map((e) => '${e.key}=${e.value}')
        .join('&');
    return '${options.path}?$queryStr';
  }

  Duration _getTtl(String path) {
    if (path.contains('/season/')) return const Duration(days: 7);
    if (path.contains('/movie/') || path.contains('/tv/')) return const Duration(hours: 24);
    if (path.contains('/trending/') || path.contains('/popular')) return const Duration(hours: 1);
    if (path.contains('/search/')) return const Duration(minutes: 10);
    if (path.contains('/discover')) return const Duration(minutes: 30);
    return const Duration(minutes: 30);
  }

  bool _isCacheable(RequestOptions options) {
    if (options.method.toUpperCase() != 'GET') return false;
    if (!options.path.startsWith('/tmdb/')) return false;
    if (options.extra['noCache'] == true ||
        options.headers['Cache-Control'] == 'no-cache') {
      return false;
    }
    return true;
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    if (!_isCacheable(options)) {
      return handler.next(options);
    }

    final key = _buildKey(options);

    // 1. Check in-memory cache
    final entry = _cache[key];
    if (entry != null && !entry.isExpired) {
      return handler.resolve(
        Response(
          requestOptions: options,
          data: entry.data,
          statusCode: entry.statusCode,
          headers: entry.headers,
        ),
      );
    }

    // 2. Single-flight deduplication: await identical in-flight request
    if (_inFlight.containsKey(key)) {
      try {
        final resp = await _inFlight[key]!.future;
        return handler.resolve(
          Response(
            requestOptions: options,
            data: resp.data,
            statusCode: resp.statusCode,
            headers: resp.headers,
          ),
        );
      } catch (_) {
        // Fall through to make fresh request if ongoing one errored
      }
    }

    _inFlight[key] = Completer<Response>();
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (_isCacheable(response.requestOptions) && response.statusCode == 200) {
      final key = _buildKey(response.requestOptions);

      // Evict oldest 20% if cache full
      if (_cache.length >= _maxEntries) {
        final keysToRemove = _cache.keys.take((_maxEntries * 0.2).toInt()).toList();
        for (final k in keysToRemove) {
          _cache.remove(k);
        }
      }

      final ttl = _getTtl(response.requestOptions.path);
      _cache[key] = _TmdBCacheEntry(
        data: response.data,
        statusCode: response.statusCode ?? 200,
        headers: response.headers,
        expiresAt: DateTime.now().add(ttl),
      );

      final completer = _inFlight.remove(key);
      if (completer != null && !completer.isCompleted) {
        completer.complete(response);
      }
    }

    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (_isCacheable(err.requestOptions)) {
      final key = _buildKey(err.requestOptions);
      final completer = _inFlight.remove(key);
      if (completer != null && !completer.isCompleted) {
        completer.completeError(err);
      }

      // Offline / network failure graceful fallback to cached stale data
      final stale = _cache[key];
      if (stale != null) {
        return handler.resolve(
          Response(
            requestOptions: err.requestOptions,
            data: stale.data,
            statusCode: stale.statusCode,
            headers: stale.headers,
          ),
        );
      }
    }

    handler.next(err);
  }
}
