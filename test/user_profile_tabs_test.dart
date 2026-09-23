import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:watchhive_mobile/core/api/api_client.dart';
import 'package:watchhive_mobile/core/auth/auth_manager.dart';
import 'package:watchhive_mobile/features/auth/providers/auth_provider.dart';
import 'package:watchhive_mobile/features/profile/screens/user_profile_screen.dart';
import 'package:watchhive_mobile/shared/models/user.dart';

class _FakeApiClient extends ApiClient {
  _FakeApiClient() : super(AuthManager());

  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    if (path.contains('/users/') && !path.contains('/watchlist')) {
      return Response<T>(
        requestOptions: RequestOptions(path: path),
        statusCode: 200,
        data: {
          'id': 'test-user-id',
          'username': 'cinephile99',
          'displayName': 'Cinephile 99',
          'profilePictureUrl': null,
          'bio': 'Film buff',
          'privacyLevel': 'PUBLIC',
          'showWatchEntries': true,
          'showCurrentlyWatching': true,
          'showWatchlist': true,
          'showRankings': true,
          '_count': {
            'followers': 42,
            'following': 18,
            'entries': 12,
            'watches': 12,
            'watching': 3,
            'watchlist': 7,
          },
        } as T,
      );
    }

    if (path.contains('/follows/stats/')) {
      return Response<T>(
        requestOptions: RequestOptions(path: path),
        statusCode: 200,
        data: {
          'followersCount': 42,
          'followingCount': 18,
        } as T,
      );
    }

    if (path.contains('/entries')) {
      final isWatching = queryParameters?['isWatching'] == true;
      return Response<T>(
        requestOptions: RequestOptions(path: path),
        statusCode: 200,
        data: {
          'entries': <dynamic>[
            {
              'id': isWatching ? 'watching-1' : 'history-1',
              'userId': 'test-user-id',
              'tmdbId': 101,
              'title': isWatching ? 'Severance' : 'Inception',
              'type': isWatching ? 'TV_SHOW' : 'MOVIE',
              'isWatching': isWatching,
              'createdAt': DateTime.now().toIso8601String(),
            },
          ],
          'pagination': {
            'total': isWatching ? 3 : 12,
            'limit': 50,
            'offset': 0,
          },
        } as T,
      );
    }

    if (path.contains('/watchlist')) {
      return Response<T>(
        requestOptions: RequestOptions(path: path),
        statusCode: 200,
        data: {
          'items': <dynamic>[
            {
              'tmdbId': 550,
              'title': 'Fight Club',
              'mediaType': 'movie',
            },
          ],
        } as T,
      );
    }

    return Response<T>(
      requestOptions: RequestOptions(path: path),
      statusCode: 200,
      data: <String, dynamic>{} as T,
    );
  }
}

class _MockAuthNotifier extends AuthNotifier {
  final AuthState _initial;
  _MockAuthNotifier(this._initial);

  @override
  Future<AuthState> build() async => _initial;
}

void main() {
  group('User Model Tab Counts Parsing', () {
    test('User.fromJson parses watchingCount and watchlistCount from _count', () {
      final json = {
        'id': 'user_123',
        'username': 'filmfan',
        '_count': {
          'followers': 10,
          'following': 5,
          'entries': 15,
          'watches': 15,
          'watching': 2,
          'watchlist': 8,
        },
      };

      final user = User.fromJson(json);
      expect(user.entriesCount, equals(15));
      expect(user.watchingCount, equals(2));
      expect(user.watchlistCount, equals(8));
    });

    test('User.copyWith updates watchingCount and watchlistCount correctly', () {
      final user = User(
        id: '1',
        username: 'cinephile',
        createdAt: DateTime.now(),
        entriesCount: 10,
        watchingCount: 2,
        watchlistCount: 5,
      );

      final updated = user.copyWith(
        entriesCount: 12,
        watchingCount: 3,
        watchlistCount: 6,
      );

      expect(updated.entriesCount, equals(12));
      expect(updated.watchingCount, equals(3));
      expect(updated.watchlistCount, equals(6));
    });

    test('User.toJson includes watchingCount and watchlistCount', () {
      final user = User(
        id: '1',
        username: 'cinephile',
        createdAt: DateTime.now(),
        entriesCount: 10,
        watchingCount: 2,
        watchlistCount: 5,
      );

      final json = user.toJson();
      expect(json['entriesCount'], equals(10));
      expect(json['watchingCount'], equals(2));
      expect(json['watchlistCount'], equals(5));
    });
  });

  group('UserProfileScreen Initial Tab Counts Verification', () {
    testWidgets('Renders tab counts without flashing (0) initially', (tester) async {
      final fakeApi = _FakeApiClient();
      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(fakeApi),
          authStateProvider.overrideWith(
            () => _MockAuthNotifier(AuthState(
              isAuthenticated: true,
              user: User(id: 'me', username: 'me', createdAt: DateTime.now()),
            )),
          ),
        ],
      );

      final router1 = GoRouter(
        initialLocation: '/profile/test-user-id',
        routes: [
          GoRoute(
            path: '/profile/:id',
            builder: (context, state) => const UserProfileScreen(userId: 'test-user-id'),
          ),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: router1,
          ),
        ),
      );

      // Verify that initially during skeleton loading, (0) is NEVER displayed in tabs
      expect(find.text('Watches (0)'), findsNothing);
      expect(find.text('Watching (0)'), findsNothing);
      expect(find.text('Watchlist (0)'), findsNothing);

      // Let asynchronous requests finish
      await tester.pumpAndSettle();

      // Now verify tab labels show confirmed non-zero counts
      expect(find.text('Watches (12)'), findsOneWidget);
      expect(find.text('Watching (3)'), findsOneWidget);
      expect(find.text('Watchlist (7)'), findsOneWidget);

      // Verify header hero chip for watches displays 12
      expect(find.text('12'), findsWidgets);
    });

    testWidgets('Accepts initialUser with non-zero counts and displays them immediately', (tester) async {
      final fakeApi = _FakeApiClient();
      final initialUser = User(
        id: 'test-user-id',
        username: 'cinephile99',
        displayName: 'Cinephile 99',
        createdAt: DateTime.now(),
        entriesCount: 12,
        watchingCount: 3,
        watchlistCount: 7,
      );

      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(fakeApi),
          authStateProvider.overrideWith(
            () => _MockAuthNotifier(AuthState(
              isAuthenticated: true,
              user: User(id: 'me', username: 'me', createdAt: DateTime.now()),
            )),
          ),
        ],
      );

      final router2 = GoRouter(
        initialLocation: '/profile/test-user-id',
        routes: [
          GoRoute(
            path: '/profile/:id',
            builder: (context, state) => UserProfileScreen(
              userId: 'test-user-id',
              initialUser: initialUser,
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: router2,
          ),
        ),
      );

      // Initial frame with initialUser already provided
      expect(find.text('Watches (0)'), findsNothing);
      expect(find.text('Watching (0)'), findsNothing);
      expect(find.text('Watchlist (0)'), findsNothing);

      await tester.pumpAndSettle();

      expect(find.text('Watches (12)'), findsOneWidget);
      expect(find.text('Watching (3)'), findsOneWidget);
      expect(find.text('Watchlist (7)'), findsOneWidget);
    });
  });
}
