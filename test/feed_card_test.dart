import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:watchhive_mobile/shared/models/entry.dart';
import 'package:watchhive_mobile/shared/models/models.dart';
import 'package:watchhive_mobile/shared/models/user.dart';
import 'package:watchhive_mobile/features/feed/repositories/feed_repository.dart';
import 'package:watchhive_mobile/features/feed/screens/feed_screen.dart';

class _FakeFeedRepository implements FeedRepository {
  final List<Entry> entries;
  _FakeFeedRepository(this.entries);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<({List<Entry> entries, Pagination pagination})> getFeed({
    int limit = 20,
    int offset = 0,
  }) async {
    return (
      entries: entries,
      pagination: const Pagination(total: 1, limit: 20, offset: 0, hasMore: false),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testUser = User(
    id: 'user-abc-123',
    username: 'alexander_the_great',
    displayName: 'Alexander Christopher Montgomery III',
    email: 'alex@example.com',
    createdAt: DateTime(2025, 1, 1),
  );

  final testEntry = Entry(
    id: 'entry-test-1',
    userId: 'user-abc-123',
    tmdbId: 550,
    title: 'Dr. Strangelove or: How I Learned to Stop Worrying and Love the Bomb - Extended Edition',
    type: 'MOVIE',
    watchedAt: DateTime(2025, 8, 15, 20, 30),
    rating: 9.5,
    review: 'A cinematic tour de force that remains astonishingly relevant and hilariously terrifying.',
    tags: ['MindBendingClassicCinema', 'ColdWarSatire', 'StanleyKubrickMasterpiece'],
    watchLocation: 'Grand Cinema Hall 7 (IMAX Laser)',
    isRewatch: true,
    user: testUser,
    likesCount: 12,
    commentsCount: 4,
    createdAt: DateTime(2025, 8, 15, 20, 30),
  );

  group('FeedCard Display & Profile Redirect Tests', () {
    testWidgets('does not show @user_id, displays clean user name and taps to profile', (tester) async {
      String? navigatedRoute;

      final router = GoRouter(
        initialLocation: '/feed',
        routes: [
          GoRoute(
            path: '/feed',
            builder: (context, state) => const FeedScreen(),
          ),
          GoRoute(
            path: '/profile/:id',
            builder: (context, state) {
              navigatedRoute = '/profile/${state.pathParameters['id']}';
              return const Scaffold(body: Text('Profile Screen'));
            },
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            feedRepositoryProvider.overrideWithValue(_FakeFeedRepository([testEntry])),
          ],
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 1. Verify user's display name is visible
      expect(find.textContaining('Alexander Christopher Montgomery III'), findsOneWidget);

      // 2. Verify that @alexander_the_great and @user-abc-123 are NOT displayed
      expect(find.text('@alexander_the_great'), findsNothing);
      expect(find.text('@user-abc-123'), findsNothing);

      // 3. Verify location venue is displayed cleanly
      expect(find.text('Grand Cinema Hall 7 (IMAX Laser)'), findsOneWidget);

      // 4. Tap the user name to test redirect to profile
      await tester.tap(find.textContaining('Alexander Christopher Montgomery III'));
      await tester.pumpAndSettle();

      expect(navigatedRoute, equals('/profile/user-abc-123'));
    });

    testWidgets('suggestion entry displays cleanly without @ and taps friend profile', (tester) async {
      String? navigatedRoute;

      final friendUser = User(
        id: 'friend-xyz-789',
        username: 'sarah_connor',
        displayName: 'Sarah Connor',
        email: 'sarah@example.com',
        createdAt: DateTime(2025, 1, 1),
      );

      final suggestionEntry = Entry(
        id: 'entry-sugg-1',
        userId: 'user-abc-123',
        tmdbId: 280,
        title: 'Terminator 2: Judgment Day',
        type: 'MOVIE',
        watchedAt: DateTime(2025, 8, 15, 20, 30),
        user: testUser,
        suggestedByUser: friendUser,
        suggestionReason: 'Based on your recent sci-fi favorites',
        likesCount: 5,
        commentsCount: 2,
        createdAt: DateTime(2025, 8, 15, 20, 30),
      );

      final router = GoRouter(
        initialLocation: '/feed',
        routes: [
          GoRoute(
            path: '/feed',
            builder: (context, state) => const FeedScreen(),
          ),
          GoRoute(
            path: '/profile/:id',
            builder: (context, state) {
              navigatedRoute = '/profile/${state.pathParameters['id']}';
              return const Scaffold(body: Text('Profile Screen'));
            },
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            feedRepositoryProvider.overrideWithValue(_FakeFeedRepository([suggestionEntry])),
          ],
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Friend display name is shown, no @ handle
      expect(find.text('Sarah Connor'), findsOneWidget);
      expect(find.text('@sarah_connor'), findsNothing);

      // Tap friend to redirect to profile
      await tester.tap(find.text('Sarah Connor'));
      await tester.pumpAndSettle();

      expect(navigatedRoute, equals('/profile/friend-xyz-789'));
    });

    testWidgets('renders long user names, titles, and location without overflowing RenderFlex on narrow screen', (tester) async {
      // Small screen constraints (e.g. 300px width phone)
      tester.view.physicalSize = const Size(300, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            feedRepositoryProvider.overrideWithValue(_FakeFeedRepository([testEntry])),
          ],
          child: const MaterialApp(
            home: FeedScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 700));

      // Ensure no Flutter layout overflow exceptions were thrown
      expect(tester.takeException(), isNull);
    });
  });
}
