import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:watchhive_mobile/shared/models/entry.dart';
import 'package:watchhive_mobile/shared/models/user.dart';
import 'package:watchhive_mobile/features/feed/repositories/feed_repository.dart';
import 'package:watchhive_mobile/features/feed/widgets/likes_list_sheet.dart';
import 'package:watchhive_mobile/features/feed/widgets/wh_feed_card.dart';

class _FakeLikesFeedRepository implements FeedRepository {
  final List<User> allLikes;
  final List<({int limit, int offset})> calls = [];

  _FakeLikesFeedRepository(this.allLikes);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<({List<User> users, int total, bool hasMore})> getEntryLikes(
    String entryId, {
    int limit = 3,
    int offset = 0,
  }) async {
    calls.add((limit: limit, offset: offset));
    final slice = allLikes.skip(offset).take(limit).toList();
    final total = allLikes.length;
    final hasMore = offset + slice.length < total;
    return (users: slice, total: total, hasMore: hasMore);
  }
}

List<User> _generateUsers(int count) {
  return List.generate(
    count,
    (i) => User(
      id: 'user-${i + 1}',
      username: 'user_${i + 1}',
      displayName: 'User Number ${i + 1}',
      createdAt: DateTime(2025, 1, 1),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LikesListSheet & FeedCard Hyperlink Tests', () {
    testWidgets(
      'loads top 3 likes initially, then loads batches of 10 on See more, and navigates to profile',
      (tester) async {
        final fakeRepo = _FakeLikesFeedRepository(_generateUsers(18));
        String? navigatedRoute;

        final router = GoRouter(
          initialLocation: '/host',
          routes: [
            GoRoute(
              path: '/host',
              builder: (context, state) => Scaffold(
                body: Builder(
                  builder: (ctx) => ElevatedButton(
                    onPressed: () => LikesListSheet.show(
                      ctx,
                      entryId: 'entry-1',
                      entryTitle: 'Inception',
                      initialLikeCount: 18,
                    ),
                    child: const Text('Open Likes'),
                  ),
                ),
              ),
            ),
            GoRoute(
              path: '/profile/:id',
              builder: (context, state) {
                navigatedRoute = '/profile/${state.pathParameters['id']}';
                return const Scaffold(body: Text('Profile Page'));
              },
            ),
          ],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              feedRepositoryProvider.overrideWithValue(fakeRepo),
            ],
            child: MaterialApp.router(routerConfig: router),
          ),
        );

        await tester.tap(find.text('Open Likes'));
        await tester.pumpAndSettle();

        // 1. Initial call should strictly request limit=3, offset=0
        expect(fakeRepo.calls.length, 1);
        expect(fakeRepo.calls.first.limit, 3);
        expect(fakeRepo.calls.first.offset, 0);

        // Top 3 visible, 4th not yet loaded
        expect(find.text('User Number 1'), findsOneWidget);
        expect(find.text('@user_1'), findsOneWidget);
        expect(find.text('User Number 3'), findsOneWidget);
        expect(find.text('User Number 4'), findsNothing);

        // 2. See more button shows batch of 10 of remaining 15
        expect(find.text('See more (next 10 of 15)'), findsOneWidget);
        await tester.tap(find.text('See more (next 10 of 15)'));
        await tester.pumpAndSettle();

        // Second call should request limit=10, offset=3
        expect(fakeRepo.calls.length, 2);
        expect(fakeRepo.calls[1].limit, 10);
        expect(fakeRepo.calls[1].offset, 3);

        // Scroll down inside the sheet to verify remaining 5 button & 13th user
        await tester.scrollUntilVisible(
          find.text('See more (5)'),
          200,
          scrollable: find.byType(Scrollable).last,
        );
        expect(find.text('User Number 13'), findsOneWidget);
        expect(find.text('See more (5)'), findsOneWidget);

        // 3. Tap See more again -> limit=10, offset=13
        await tester.tap(find.text('See more (5)'));
        await tester.pumpAndSettle();

        expect(fakeRepo.calls.length, 3);
        expect(fakeRepo.calls[2].limit, 10);
        expect(fakeRepo.calls[2].offset, 13);

        // No more See more button once all 18 loaded
        expect(find.textContaining('See more'), findsNothing);
        await tester.scrollUntilVisible(
          find.text('User Number 18'),
          200,
          scrollable: find.byType(Scrollable).last,
        );
        expect(find.text('User Number 18'), findsOneWidget);

        // 4. Tap User Number 18 -> navigates to /profile/user-18
        await tester.tap(find.text('User Number 18'));
        await tester.pumpAndSettle();
        expect(navigatedRoute, '/profile/user-18');
      },
    );

    testWidgets(
      'WHFeedCard shows clickable "X likes" hyperlink that opens LikesListSheet',
      (tester) async {
        final fakeRepo = _FakeLikesFeedRepository(_generateUsers(5));

        final entry = Entry(
          id: 'entry-card-1',
          userId: 'author-1',
          tmdbId: 27205,
          title: 'Inception',
          type: 'MOVIE',
          watchedAt: DateTime(2025, 8, 15, 20, 30),
          user: User(
            id: 'author-1',
            username: 'nolan_fan',
            displayName: 'Chris',
            createdAt: DateTime(2025, 1, 1),
          ),
          likesCount: 5,
          commentsCount: 2,
          createdAt: DateTime(2025, 8, 15, 20, 30),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              feedRepositoryProvider.overrideWithValue(fakeRepo),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(
                  child: WHFeedCard(
                    entry: entry,
                    isLiked: false,
                    isOwnEntry: false,
                    onLike: () {},
                    onUserTap: () {},
                    onMediaTap: () {},
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Likes count "5" is visible
        final likesLink = find.text('5');
        expect(likesLink, findsOneWidget);

        // Tapping opens LikesListSheet and loads top 3
        await tester.tap(likesLink);
        await tester.pumpAndSettle();

        expect(find.text('Liked by'), findsOneWidget);
        expect(find.text('User Number 1'), findsOneWidget);
        expect(find.text('User Number 3'), findsOneWidget);
        expect(find.text('See more (2)'), findsOneWidget);
      },
    );
  });
}
