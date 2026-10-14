import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watchhive_mobile/core/api/api_client.dart';
import 'package:watchhive_mobile/core/api/api_endpoints.dart';
import 'package:watchhive_mobile/features/entries/repositories/suggestions_repository.dart';
import 'package:watchhive_mobile/features/entries/widgets/suggestions_tab.dart';
import 'package:watchhive_mobile/features/search/repositories/search_repository.dart';

class MockSuggestionsApiClient extends Fake implements ApiClient {
  List<dynamic> receivedResponse = [
    {
      'tmdbId': 157336,
      'mediaType': 'movie',
      'suggestions': [
        {
          'id': 'sugg-1',
          'fromUserId': 'user-1',
          'toUserId': 'me',
          'tmdbId': 157336,
          'mediaType': 'movie',
          'message': 'You have to watch this!',
          'status': 'pending',
          'createdAt': '2026-10-14T10:00:00Z',
        }
      ],
      'suggestors': [
        {
          'id': 'user-1',
          'username': 'alice',
          'displayName': 'Alice W',
          'profilePictureUrl': null,
        }
      ],
      'recipients': [],
    }
  ];

  List<dynamic> sentResponse = [
    {
      'tmdbId': 27205,
      'mediaType': 'movie',
      'suggestions': [
        {
          'id': 'sugg-2',
          'fromUserId': 'me',
          'toUserId': 'user-2',
          'tmdbId': 27205,
          'mediaType': 'movie',
          'message': 'Mind blowing film',
          'status': 'pending',
          'createdAt': '2026-10-14T11:00:00Z',
        }
      ],
      'suggestors': [],
      'recipients': [
        {
          'id': 'user-2',
          'username': 'bob',
          'displayName': 'Bob M',
          'profilePictureUrl': null,
        }
      ],
    }
  ];

  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) async {
    if (path == '/suggestions/me') {
      return Response<T>(
        data: receivedResponse as T,
        statusCode: 200,
        requestOptions: RequestOptions(path: path),
      );
    }
    if (path == ApiEndpoints.sentSuggestions) {
      return Response<T>(
        data: sentResponse as T,
        statusCode: 200,
        requestOptions: RequestOptions(path: path),
      );
    }
    if (path.startsWith('/tmdb/')) {
      return Response<T>(
        data: {
          'id': 157336,
          'title': 'Mock Movie',
          'poster_path': '/poster.jpg',
          'vote_average': 8.5,
        } as T,
        statusCode: 200,
        requestOptions: RequestOptions(path: path),
      );
    }
    throw UnimplementedError('Path not mocked: $path');
  }
}

void main() {
  testWidgets('SuggestionsTab displays Received Suggestions and Suggested Items tabs with counts', (tester) async {
    final mockApi = MockSuggestionsApiClient();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          suggestionsRepositoryProvider.overrideWithValue(SuggestionsRepository(mockApi)),
          tmdbMediaDetailsProvider.overrideWith((ref, arg) async => {
            'id': arg.tmdbId,
            'title': 'Mock Title ${arg.tmdbId}',
            'poster_path': '/mock.jpg',
            'vote_average': 8.0,
          }),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SuggestionsTab(),
          ),
        ),
      ),
    );

    // Initial pump and wait for async fetch and animation
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    // Verify sub-tab labels exist
    expect(find.text('Suggestions'), findsOneWidget);
    expect(find.text('Suggested'), findsOneWidget);

    // Verify counts
    expect(find.text('1'), findsNWidgets(2)); // 1 received, 1 sent

    // Verify received subtab description
    expect(find.text('Recommendations from your Hive'), findsOneWidget);

    // Tap on "Suggested" sub-tab
    await tester.tap(find.text('Suggested'));
    await tester.pump(const Duration(milliseconds: 250));

    // Verify switched description
    expect(find.text('Titles you recommended to friends'), findsOneWidget);
  });
}
