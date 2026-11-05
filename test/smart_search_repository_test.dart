import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watchhive_mobile/core/api/api_client.dart';
import 'package:watchhive_mobile/core/api/api_endpoints.dart';
import 'package:watchhive_mobile/features/search/repositories/search_repository.dart';

class _MockApiClient implements ApiClient {
  final Map<String, dynamic> responses = {};
  final List<String> requestedQueries = [];

  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    final query = queryParameters?['query']?.toString() ??
        queryParameters?['q']?.toString() ??
        '';
    requestedQueries.add(query);

    if (path == ApiEndpoints.tmdbSearch) {
      if (responses.containsKey(query)) {
        return Response<T>(
          requestOptions: RequestOptions(path: path),
          data: responses[query] as T,
          statusCode: 200,
        );
      }
      return Response<T>(
        requestOptions: RequestOptions(path: path),
        data: {'results': []} as T,
        statusCode: 200,
      );
    }

    if (path == ApiEndpoints.searchUsers) {
      if (responses.containsKey('user:$query')) {
        return Response<T>(
          requestOptions: RequestOptions(path: path),
          data: responses['user:$query'] as T,
          statusCode: 200,
        );
      }
      return Response<T>(
        requestOptions: RequestOptions(path: path),
        data: {'users': []} as T,
        statusCode: 200,
      );
    }

    return Response<T>(
      requestOptions: RequestOptions(path: path),
      data: <String, dynamic>{} as T,
      statusCode: 200,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Smart SearchRepository Tests', () {
    late _MockApiClient mockApi;
    late SearchRepository repo;

    setUp(() {
      mockApi = _MockApiClient();
      repo = SearchRepository(mockApi);
    });

    test(
        'recovers from typo "interstelar" by querying candidate "Interstellar"',
        () async {
      // "interstelar" produces 0 results in TMDB
      mockApi.responses['interstelar'] = {'results': []};
      // "Interstellar" produces the expected movie
      mockApi.responses['Interstellar'] = {
        'results': [
          {
            'id': 157336,
            'title': 'Interstellar',
            'media_type': 'movie',
            'poster_path': '/interstellar.jpg',
            'vote_average': 8.6,
          }
        ]
      };

      final smartResult = await repo.searchMediaSmart('interstelar');

      expect(smartResult.isSmartCorrected, isTrue);
      expect(smartResult.correctedQuery, 'Interstellar');
      expect(smartResult.results, isNotEmpty);
      expect(smartResult.results.first.title, 'Interstellar');
      expect(mockApi.requestedQueries, contains('interstelar'));
      expect(mockApi.requestedQueries, contains('Interstellar'));
    });

    test('backward-compatible searchMedia returns corrected results directly',
        () async {
      mockApi.responses['oppenhiemer'] = {'results': []};
      mockApi.responses['Oppenheimer'] = {
        'results': [
          {
            'id': 872585,
            'title': 'Oppenheimer',
            'media_type': 'movie',
            'poster_path': '/oppenheimer.jpg',
            'vote_average': 8.1,
          }
        ]
      };

      final results = await repo.searchMedia('oppenhiemer');

      expect(results, isNotEmpty);
      expect(results.first.title, 'Oppenheimer');
    });

    test('returns exact matches immediately without unnecessary fallback calls',
        () async {
      mockApi.responses['Inception'] = {
        'results': [
          {
            'id': 27205,
            'title': 'Inception',
            'media_type': 'movie',
            'poster_path': '/inception.jpg',
            'vote_average': 8.4,
          }
        ]
      };

      final smartResult = await repo.searchMediaSmart('Inception');

      expect(smartResult.isSmartCorrected, isFalse);
      expect(smartResult.results.first.title, 'Inception');
      expect(mockApi.requestedQueries.length, 1);
    });
  });
}
