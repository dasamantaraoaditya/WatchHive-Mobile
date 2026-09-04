import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watchhive_mobile/core/api/api_client.dart';
import 'package:watchhive_mobile/core/api/api_endpoints.dart';
import 'package:watchhive_mobile/features/entries/widgets/wh_entry_grid_card.dart';
import 'package:watchhive_mobile/features/profile/repositories/user_repository.dart';
import 'package:watchhive_mobile/shared/models/user.dart';

import 'package:watchhive_mobile/core/auth/auth_manager.dart';

class _FakeApiClient extends ApiClient {
  _FakeApiClient() : super(AuthManager());

  String? lastGetPath;
  Map<String, dynamic>? lastGetParams;
  String? lastPostPath;
  dynamic lastPostData;

  dynamic mockGetResponse;
  dynamic mockPostResponse;

  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    lastGetPath = path;
    lastGetParams = queryParameters;
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      data: mockGetResponse as T?,
      statusCode: 200,
    );
  }

  @override
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    lastPostPath = path;
    lastPostData = data;
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      data: mockPostResponse as T?,
      statusCode: 200,
    );
  }
}

void main() {
  group('User Location Parsing & Display Tests', () {
    test('parses clean location string and trims leading/trailing spaces', () {
      final json = {
        'id': 'usr-1',
        'username': 'moviebuff',
        'location': '  San Francisco, CA  ',
        'createdAt': '2024-01-01T00:00:00Z',
      };
      final user = User.fromJson(json);
      expect(user.location, equals('San Francisco, CA'));
      expect(user.displayLocation, equals('San Francisco, CA'));
    });

    test('parses empty or whitespace-only location as null', () {
      final jsonEmpty = {
        'id': 'usr-2',
        'username': 'cinelover',
        'location': '   ',
        'createdAt': '2024-01-01T00:00:00Z',
      };
      final user = User.fromJson(jsonEmpty);
      expect(user.location, isNull);
      expect(user.displayLocation, isNull);
    });

    test('parses location from map structure (e.g. city or name)', () {
      final jsonMap = {
        'id': 'usr-3',
        'username': 'tokyoviewer',
        'location': {'city': 'Tokyo', 'country': 'Japan'},
        'createdAt': '2024-01-01T00:00:00Z',
      };
      final user = User.fromJson(jsonMap);
      expect(user.location, equals('Tokyo'));
      expect(user.displayLocation, equals('Tokyo'));
    });
  });

  group('UserRepository Data Export & Import Tests', () {
    late _FakeApiClient fakeApi;
    late UserRepository userRepo;

    setUp(() {
      fakeApi = _FakeApiClient();
      userRepo = UserRepository(fakeApi);
    });

    test('exportData sends correct include=entries,lists and format=json', () async {
      fakeApi.mockGetResponse = '{"entries":[],"lists":[]}';

      final result = await userRepo.exportData(
        includeEntries: true,
        includeLists: true,
        format: 'json',
      );

      expect(fakeApi.lastGetPath, equals(ApiEndpoints.dataExport));
      expect(fakeApi.lastGetParams?['format'], equals('json'));
      expect(fakeApi.lastGetParams?['include'], equals('entries,lists'));
      expect(result, contains('"entries"'));
    });

    test('exportData sends format=csv and single include=entries', () async {
      fakeApi.mockGetResponse = 'title,type,rating\nInception,MOVIE,9.5';

      final result = await userRepo.exportData(
        includeEntries: true,
        includeLists: false,
        format: 'csv',
      );

      expect(fakeApi.lastGetPath, equals(ApiEndpoints.dataExport));
      expect(fakeApi.lastGetParams?['format'], equals('csv'));
      expect(fakeApi.lastGetParams?['include'], equals('entries'));
      expect(result, contains('Inception'));
    });

    test('exportData throws error if neither entries nor lists is selected', () async {
      expect(
        () => userRepo.exportData(includeEntries: false, includeLists: false),
        throwsA(isA<Exception>()),
      );
    });

    test('importData posts payload and returns summary map', () async {
      fakeApi.mockPostResponse = {
        'message': 'Import complete!',
        'entriesImported': 15,
        'entriesSkipped': 2,
        'listsImported': 3,
        'itemsImported': 25,
      };

      final payload = {
        'entries': [
          {'title': 'Dune: Part Two', 'type': 'MOVIE', 'rating': 9.5}
        ],
        'lists': [
          {'name': 'Top Sci-Fi', 'items': []}
        ],
      };

      final res = await userRepo.importData(payload);

      expect(fakeApi.lastPostPath, equals(ApiEndpoints.dataImport));
      expect(fakeApi.lastPostData?['entries'], isA<List>());
      expect(fakeApi.lastPostData?['lists'], isA<List>());
      expect(res['entriesImported'], equals(15));
      expect(res['listsImported'], equals(3));
    });

    test('importData throws error when file does not contain entries or lists', () async {
      expect(
        () => userRepo.importData({'invalid': []}),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('WHEntryGridCard Watch Location Display', () {
    testWidgets('renders watch location badge cleanly in footer when present', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 220,
                height: 340,
                child: WHEntryGridCard(
                  tmdbId: 100,
                  title: 'Oppenheimer',
                  initialPosterPath: 'https://example.com/poster.jpg',
                  mediaType: 'movie',
                  mode: WHEntryCardMode.history,
                  watchLocation: 'IMAX Cinema',
                  watchedAt: DateTime(2024, 7, 21),
                  onTap: () {},
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('IMAX Cinema'), findsOneWidget);
      expect(find.byIcon(Icons.location_on_outlined), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });
  });
}
