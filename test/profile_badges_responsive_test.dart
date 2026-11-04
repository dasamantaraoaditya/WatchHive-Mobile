import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
          'id': 'test_user_1',
          'username': 'tarantino_fan_long_username',
          'displayName': 'Quentin Tarantino Cinema Enthusiast',
          'profilePictureUrl': null,
          'bio': 'Lifelong cinephile exploring 70s neo-noir and world cinema classics.',
          'location': 'Los Angeles, California, United States',
          'level': 12,
          'xp': 4580,
          'watchStreak': 15,
          'privacyLevel': 'PUBLIC',
          'showWatchEntries': true,
          'showCurrentlyWatching': true,
          'showWatchlist': true,
          'showRankings': true,
          '_count': {
            'followers': 1205,
            'following': 489,
            'entries': 342,
            'watches': 342,
            'watching': 3,
            'watchlist': 15,
          },
        } as T,
      );
    }

    if (path.contains('/follows/stats/')) {
      return Response<T>(
        requestOptions: RequestOptions(path: path),
        statusCode: 200,
        data: {
          'followersCount': 1205,
          'followingCount': 489,
        } as T,
      );
    }

    if (path.contains('/entries')) {
      return Response<T>(
        requestOptions: RequestOptions(path: path),
        statusCode: 200,
        data: {
          'entries': <dynamic>[],
          'pagination': {
            'total': 0,
            'limit': 50,
            'offset': 0,
          },
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
  testWidgets('Profile Hero Card and Badges render without overflowing on narrow 360px screen', (tester) async {
    // Simulate a compact mobile screen (360px wide, e.g. standard Android / iPhone SE)
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    FlutterErrorDetails? errorDetails;
    final originalOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      errorDetails = details;
    };
    addTearDown(() {
      FlutterError.onError = originalOnError;
    });

    final testUser = User(
      id: 'test_user_1',
      username: 'tarantino_fan_long_username',
      displayName: 'Quentin Tarantino Cinema Enthusiast',
      bio: 'Lifelong cinephile exploring 70s neo-noir and world cinema classics.',
      location: 'Los Angeles, California, United States',
      level: 12,
      xp: 4580,
      watchStreak: 15,
      entriesCount: 342,
      followersCount: 1205,
      followingCount: 489,
      createdAt: DateTime.now(),
    );

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

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: UserProfileScreen(
            userId: testUser.id,
            initialUser: testUser,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify there are NO Flutter render overflow errors
    if (errorDetails != null) {
      debugPrint('CAPTURED_ERROR_DETAILS:\n${errorDetails!.toString()}');
    }
    expect(errorDetails, isNull);

    // Verify badges and elements are rendered cleanly
    expect(find.text('CINEPHILE'), findsOneWidget);
    expect(find.text('LVL 12 · 4580 XP'), findsOneWidget);
    expect(find.textContaining('Badges Unlocked'), findsOneWidget);
    expect(find.text('15-Day Streak'), findsOneWidget);
  });
}
