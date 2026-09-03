import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watchhive_mobile/core/api/api_client.dart';
import 'package:watchhive_mobile/features/entries/repositories/watchlist_repository.dart';

class MockApiClient extends Fake implements ApiClient {
  String? lastDeletedPath;
  Map<String, dynamic> watchlistResponse = {
    'id': 'watchlist-123',
    'name': 'Watchlist',
    'items': [
      {
        'id': 'item-uuid-1',
        'listId': 'watchlist-123',
        'tmdbId': 157336,
        'title': 'Interstellar',
      },
      {
        'id': 'item-uuid-2',
        'listId': 'watchlist-123',
        'tmdbId': 27205,
        'title': 'Inception',
      }
    ],
  };

  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) async {
    if (path == '/lists/watchlist') {
      return Response<T>(
        data: watchlistResponse as T,
        statusCode: 200,
        requestOptions: RequestOptions(path: path),
      );
    }
    throw UnimplementedError();
  }

  @override
  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    lastDeletedPath = path;
    return Response<T>(
      data: {'message': 'Removed'} as T,
      statusCode: 200,
      requestOptions: RequestOptions(path: path),
    );
  }
}

void main() {
  group('WatchlistRepository Delete Tests', () {
    late MockApiClient mockApi;
    late WatchlistRepository repository;

    setUp(() {
      mockApi = MockApiClient();
      repository = WatchlistRepository(mockApi);
    });

    test('removeFromWatchlist with tmdbId calls backend /lists/:listId/items/:tmdbId', () async {
      await repository.removeFromWatchlist(157336);
      expect(mockApi.lastDeletedPath, '/lists/watchlist-123/items/157336');
    });

    test('removeFromWatchlist with item UUID resolves tmdbId and calls backend', () async {
      await repository.removeFromWatchlist('item-uuid-2');
      expect(mockApi.lastDeletedPath, '/lists/watchlist-123/items/27205');
    });

    test('removeFromWatchlist with explicit listId uses the provided listId', () async {
      await repository.removeFromWatchlist(157336, listId: 'custom-list-456');
      expect(mockApi.lastDeletedPath, '/lists/custom-list-456/items/157336');
    });

    test('removeFromWatchlistByTmdbId invokes delete properly', () async {
      await repository.removeFromWatchlistByTmdbId(27205);
      expect(mockApi.lastDeletedPath, '/lists/watchlist-123/items/27205');
    });
  });
}
