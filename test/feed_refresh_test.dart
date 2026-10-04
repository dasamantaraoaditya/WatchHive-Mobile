import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:watchhive_mobile/shared/models/entry.dart';
import 'package:watchhive_mobile/shared/models/models.dart';
import 'package:watchhive_mobile/shared/models/user.dart';
import 'package:watchhive_mobile/features/feed/repositories/feed_repository.dart';
import 'package:watchhive_mobile/features/feed/screens/feed_screen.dart';

class _FakeFeedRepo implements FeedRepository {
  List<Entry> currentEntries;
  int getFeedCalls = 0;
  Completer<void>? delayCompleter;

  _FakeFeedRepo(this.currentEntries);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<({List<Entry> entries, Pagination pagination})> getFeed({
    int limit = 20,
    int offset = 0,
  }) async {
    getFeedCalls++;
    if (delayCompleter != null) {
      await delayCompleter!.future;
    }
    return (
      entries: currentEntries,
      pagination: Pagination(
        total: currentEntries.length,
        limit: limit,
        offset: offset,
        hasMore: false,
      ),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testUser = User(
    id: 'user_1',
    username: 'cinemafan',
    displayName: 'Cinema Fan',
    email: 'fan@example.com',
    createdAt: DateTime(2025, 1, 1),
  );

  final entryA = Entry(
    id: 'entry_a',
    userId: 'user_1',
    tmdbId: 101,
    title: 'Interstellar',
    type: 'MOVIE',
    watchedAt: DateTime(2025, 1, 1),
    rating: 9,
    review: 'Masterpiece',
    createdAt: DateTime(2025, 1, 1),
    updatedAt: DateTime(2025, 1, 1),
    user: testUser,
  );

  final entryB = Entry(
    id: 'entry_b',
    userId: 'user_2',
    tmdbId: 102,
    title: 'Inception',
    type: 'MOVIE',
    watchedAt: DateTime(2025, 1, 2),
    rating: 10,
    review: 'Mind-bending',
    createdAt: DateTime(2025, 1, 2),
    updatedAt: DateTime(2025, 1, 2),
    user: testUser,
  );

  group('FeedNotifier Unit Tests', () {
    test('initializes and loads feed', () async {
      final repo = _FakeFeedRepo([entryA]);
      final notifier = FeedNotifier(repo);

      await Future.delayed(const Duration(milliseconds: 10));

      expect(notifier.state.entries.length, 1);
      expect(notifier.state.entries.first.title, 'Interstellar');
      expect(notifier.state.isLoading, false);
      expect(notifier.state.lastFetchedAt, isNotNull);
      expect(repo.getFeedCalls, 1);
    });

    test('prependEntry places new entry at top of feed', () async {
      final repo = _FakeFeedRepo([entryA]);
      final notifier = FeedNotifier(repo);
      await Future.delayed(const Duration(milliseconds: 10));

      notifier.prependEntry(entryB);

      expect(notifier.state.entries.length, 2);
      expect(notifier.state.entries.first.title, 'Inception');
      expect(notifier.state.entries[1].title, 'Interstellar');
      expect(notifier.state.isStale, true);
    });

    test('removeEntry removes entry from feed', () async {
      final repo = _FakeFeedRepo([entryA, entryB]);
      final notifier = FeedNotifier(repo);
      await Future.delayed(const Duration(milliseconds: 10));

      notifier.removeEntry('entry_a');

      expect(notifier.state.entries.length, 1);
      expect(notifier.state.entries.first.id, 'entry_b');
    });

    test('onArrivedAtFeed triggers silent refresh when marked stale', () async {
      final repo = _FakeFeedRepo([entryA]);
      final notifier = FeedNotifier(repo);
      await Future.delayed(const Duration(milliseconds: 10));
      expect(repo.getFeedCalls, 1);

      notifier.markStale();
      expect(notifier.state.isStale, true);

      // New entry on server
      repo.currentEntries = [entryB, entryA];
      notifier.onArrivedAtFeed();

      await Future.delayed(const Duration(milliseconds: 10));

      expect(repo.getFeedCalls, 2);
      expect(notifier.state.entries.first.title, 'Inception');
      expect(notifier.state.isStale, false);
    });

    test('detects new posts and sets pendingEntries when user is scrolled down', () async {
      final repo = _FakeFeedRepo([entryA]);
      final notifier = FeedNotifier(repo);
      await Future.delayed(const Duration(milliseconds: 10));

      // Simulate user scrolling down
      notifier.setNearTop(false);
      expect(notifier.state.isNearTop, false);

      // Server now has new entry
      repo.currentEntries = [entryB, entryA];
      await notifier.loadFeed(isSilent: true);

      // User's active list was NOT disrupted, but newPostsCount is 1
      expect(notifier.state.entries.length, 1);
      expect(notifier.state.entries.first.id, 'entry_a');
      expect(notifier.state.newPostsCount, 1);
      expect(notifier.state.pendingEntries?.length, 2);

      // When user applies pending entries or returns to top
      notifier.applyPendingEntries();
      expect(notifier.state.entries.length, 2);
      expect(notifier.state.entries.first.id, 'entry_b');
      expect(notifier.state.newPostsCount, 0);
    });
  });

  group('FeedScreen Widget & Gesture Tests', () {
    testWidgets('FeedScreen has RefreshIndicator that triggers pull to refresh', (tester) async {
      final repo = _FakeFeedRepo([entryA]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            feedRepositoryProvider.overrideWithValue(repo),
          ],
          child: const MaterialApp(
            home: FeedScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(RefreshIndicator), findsOneWidget);
      expect(find.text('Interstellar'), findsOneWidget);

      // Server has updated item
      repo.currentEntries = [entryB, entryA];

      // Pull down from top to trigger RefreshIndicator (force scroll down)
      await tester.fling(find.text('Interstellar'), const Offset(0, 300), 1000);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(repo.getFeedCalls, greaterThanOrEqualTo(2));
      expect(find.text('Inception'), findsOneWidget);
    });

    testWidgets('Tapping feedRefreshTriggerProvider scrolls to top and refreshes', (tester) async {
      final repo = _FakeFeedRepo([entryA]);
      late WidgetRef capturedRef;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            feedRepositoryProvider.overrideWithValue(repo),
          ],
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, child) {
                capturedRef = ref;
                return const FeedScreen();
              },
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final initialCalls = repo.getFeedCalls;
      repo.currentEntries = [entryB, entryA];

      // Trigger via Home tab tap
      capturedRef.read(feedRefreshTriggerProvider.notifier).state++;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(repo.getFeedCalls, initialCalls + 1);
      expect(find.text('Inception'), findsOneWidget);
    });

    testWidgets('Displays _NewPostsPill when new posts arrive while scrolled down and tapping updates feed', (tester) async {
      final repo = _FakeFeedRepo([entryA]);
      late WidgetRef capturedRef;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            feedRepositoryProvider.overrideWithValue(repo),
          ],
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, child) {
                capturedRef = ref;
                return const FeedScreen();
              },
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Simulate scrolled down and silent arrival of new posts
      capturedRef.read(feedProvider.notifier).setNearTop(false);
      repo.currentEntries = [entryB, entryA];
      await capturedRef.read(feedProvider.notifier).loadFeed(isSilent: true);

      await tester.pump();

      // Floating pill should be visible
      expect(find.text('1 new update available'), findsOneWidget);

      // Tap the pill to scroll to top and apply updates
      await tester.tap(find.text('1 new update available'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(find.text('Inception'), findsOneWidget);
      expect(find.text('1 new update available'), findsNothing);
    });
  });
}
