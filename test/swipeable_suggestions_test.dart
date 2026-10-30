import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watchhive_mobile/core/api/api_client.dart';
import 'package:watchhive_mobile/core/api/api_endpoints.dart';
import 'package:watchhive_mobile/features/auth/providers/auth_provider.dart';
import 'package:watchhive_mobile/features/entries/repositories/suggestions_repository.dart';
import 'package:watchhive_mobile/features/entries/widgets/suggestions_tab.dart';
import 'package:watchhive_mobile/features/feed/widgets/smart_suggest_hero_card.dart';
import 'package:watchhive_mobile/features/search/repositories/search_repository.dart';
import 'package:watchhive_mobile/shared/models/user.dart';

class _MockAuthNotifier extends AuthNotifier {
  final AuthState _initial;
  _MockAuthNotifier(this._initial);

  @override
  Future<AuthState> build() async => _initial;
}

class MockSwipeApiClient extends Fake implements ApiClient {
  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) async {
    if (path == '/suggestions/smart-suggest') {
      final mode = queryParameters?['mode'] ?? 'social';
      return Response<T>(
        data: {
          'items': [
            {
              'tmdbId': mode == 'social' ? 101 : (mode == 'critic' ? 202 : 303),
              'mediaType': 'movie',
              'title': '$mode Title',
              'posterPath': '/poster.jpg',
              'score': 95,
              'voteAverage': 8.5,
              'genreNames': ['Sci-Fi'],
              'badges': [
                {'type': 'friend_pick', 'label': 'Friend Pick'}
              ],
            }
          ],
        } as T,
        statusCode: 200,
        requestOptions: RequestOptions(path: path),
      );
    }
    if (path == '/suggestions/me') {
      return Response<T>(
        data: [
          {
            'tmdbId': 101,
            'mediaType': 'movie',
            'suggestions': [
              {
                'id': 's1',
                'fromUserId': 'u1',
                'toUserId': 'me',
                'tmdbId': 101,
                'mediaType': 'movie',
                'message': 'Check this',
                'status': 'pending',
                'createdAt': '2026-10-14T10:00:00Z',
              }
            ],
            'suggestors': [
              {
                'id': 'u1',
                'username': 'alice',
                'displayName': 'Alice',
              }
            ],
            'recipients': [],
          }
        ] as T,
        statusCode: 200,
        requestOptions: RequestOptions(path: path),
      );
    }
    if (path == ApiEndpoints.sentSuggestions) {
      return Response<T>(
        data: [
          {
            'tmdbId': 202,
            'mediaType': 'movie',
            'suggestions': [
              {
                'id': 's2',
                'fromUserId': 'me',
                'toUserId': 'u2',
                'tmdbId': 202,
                'mediaType': 'movie',
                'message': 'Great movie',
                'status': 'pending',
                'createdAt': '2026-10-14T11:00:00Z',
              }
            ],
            'suggestors': [],
            'recipients': [
              {
                'id': 'u2',
                'username': 'bob',
                'displayName': 'Bob',
              }
            ],
          }
        ] as T,
        statusCode: 200,
        requestOptions: RequestOptions(path: path),
      );
    }
    if (path.startsWith('/tmdb/')) {
      return Response<T>(
        data: {
          'id': 101,
          'title': 'Mock Movie Details',
          'poster_path': '/mock.jpg',
          'vote_average': 8.0,
        } as T,
        statusCode: 200,
        requestOptions: RequestOptions(path: path),
      );
    }
    throw UnimplementedError('Path not mocked: $path');
  }
}

void main() {
  testWidgets('SmartSuggestHeroCard supports horizontal swipe sliding between modes', (tester) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final mockApi = MockSwipeApiClient();
    final mockUser = User(
      id: 'test-user-id',
      username: 'tester',
      email: 'test@example.com',
      displayName: 'Test User',
      createdAt: DateTime.now(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith(
            () => _MockAuthNotifier(AuthState(
              isAuthenticated: true,
              user: mockUser,
            )),
          ),
          suggestionsRepositoryProvider.overrideWithValue(SuggestionsRepository(mockApi)),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SmartSuggestHeroCard(),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Initially on Social
    expect(find.text('social Title'), findsOneWidget);

    // Swipe left on the card to move from Social to Critic
    await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Critic should now be visible
    expect(find.text('critic Title'), findsOneWidget);

    // Swipe left again to move from Critic to Explore
    await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Explore should now be visible
    expect(find.text('explore Title'), findsOneWidget);

    // Tap on the Social pill to slide back to Social
    await tester.tap(find.text('Social'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('social Title'), findsOneWidget);
  });

  testWidgets('SuggestionsTab sub-tabs support horizontal swipe sliding', (tester) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final mockApi = MockSwipeApiClient();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          suggestionsRepositoryProvider.overrideWithValue(SuggestionsRepository(mockApi)),
          tmdbMediaDetailsProvider.overrideWith((ref, arg) async => {
            'id': arg.tmdbId,
            'title': 'Mock Movie ${arg.tmdbId}',
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

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Initially on Suggestions (Received) - Alice is visible
    expect(find.text('@alice'), findsOneWidget);

    // Swipe left on the list to move to SmartSuggest (sub-tab index 1)
    await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // SmartSuggest tab elements are visible (e.g. Hive Mind chip)
    expect(find.text('Hive Mind'), findsOneWidget);

    // Swipe left again to move to Suggested (Sent, sub-tab index 2)
    await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Suggested tab shows Bob
    expect(find.text('To: @bob'), findsOneWidget);

    // Swipe right to return to SmartSuggest
    await tester.fling(find.byType(PageView), const Offset(400, 0), 1000);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Hive Mind'), findsOneWidget);
  });
}
