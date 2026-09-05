import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:watchhive_mobile/features/entries/repositories/entries_repository.dart';
import 'package:watchhive_mobile/features/entries/repositories/watchlist_repository.dart';
import 'package:watchhive_mobile/features/entries/widgets/watchlist_tab.dart';
import 'package:watchhive_mobile/features/entries/widgets/wh_entry_grid_card.dart';
import 'package:watchhive_mobile/features/search/repositories/search_repository.dart';
import 'package:watchhive_mobile/shared/models/entry.dart';

class _FakeWatchlistRepo implements WatchlistRepository {
  final List<Map<String, dynamic>> items;
  _FakeWatchlistRepo(this.items);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<Map<String, dynamic>> getWatchlist() async {
    return {'id': 'watchlist-test-1', 'items': items};
  }

  @override
  Future<void> removeFromWatchlist(dynamic target, {String? listId}) async {}
}

class _FakeSearchRepo implements SearchRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<Map<String, dynamic>> getMovieDetails(int tmdbId) async {
    if (tmdbId == 157336) {
      return {'id': 157336, 'title': 'Interstellar', 'poster_path': '/interstellar.jpg'};
    }
    if (tmdbId == 550) {
      return {'id': 550, 'title': 'Fight Club', 'poster_path': '/fight_club.jpg'};
    }
    return {'id': tmdbId, 'title': 'Test Movie', 'poster_path': '/test.jpg'};
  }

  @override
  Future<Map<String, dynamic>> getTvDetails(int tmdbId) async {
    return {'id': tmdbId, 'name': 'Test TV Show', 'poster_path': '/test_tv.jpg'};
  }
}

class _FakeEntriesRepo implements EntriesRepository {
  Map<String, dynamic>? lastCreatedPayload;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<Entry> createEntry(Map<String, dynamic> data) async {
    lastCreatedPayload = data;
    return Entry.fromJson({
      'id': 'entry-new-1',
      'userId': 'user-1',
      'tmdbId': data['tmdbId'],
      'title': data['title'],
      'type': data['type'] ?? 'MOVIE',
      'isWatching': true,
      'createdAt': DateTime.now().toIso8601String(),
    });
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WHEntryGridCard & WatchlistTab Title Resolution', () {
    testWidgets('WHEntryGridCard passes resolved movie title to onMoveToWatchingWithTitle', (tester) async {
      String? passedTitle;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            searchRepositoryProvider.overrideWithValue(_FakeSearchRepo()),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 200,
                  height: 320,
                  child: WHEntryGridCard(
                    tmdbId: 157336,
                    title: 'Interstellar',
                    mediaType: 'movie',
                    mode: WHEntryCardMode.watchlist,
                    onTap: () {},
                    onMoveToWatchingWithTitle: (title) {
                      passedTitle = title;
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Tap 3-dots popup menu
      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Tap 'Log as Watching'
      await tester.tap(find.text('Log as Watching'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(passedTitle, equals('Interstellar'));
      expect(passedTitle, isNot(contains('this title')));
    });

    testWidgets('WatchlistTab resolves TMDB title and displays actual movie name in confirm dialog', (tester) async {
      final fakeEntries = _FakeEntriesRepo();
      final rawWatchlistItems = [
        {
          'id': 'item-raw-1',
          'listId': 'watchlist-test-1',
          'tmdbId': 157336,
          'mediaType': 'movie',
          'addedAt': '2025-08-20T10:00:00Z',
        }
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            watchlistRepositoryProvider.overrideWithValue(_FakeWatchlistRepo(rawWatchlistItems)),
            searchRepositoryProvider.overrideWithValue(_FakeSearchRepo()),
            entriesRepositoryProvider.overrideWithValue(fakeEntries),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: WatchlistTab(),
            ),
          ),
        ),
      );

      // Pump initial load & enrichment
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Open 3-dots menu on card
      expect(find.byIcon(Icons.more_vert_rounded), findsOneWidget);
      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Select 'Log as Watching'
      expect(find.text('Log as Watching'), findsOneWidget);
      await tester.tap(find.text('Log as Watching'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Confirmation dialog must show the real title "Interstellar"
      expect(find.text('Move to Currently Watching'), findsOneWidget);
      expect(find.textContaining('Interstellar'), findsWidgets);
      expect(find.textContaining('this title'), findsNothing);

      // Confirm moving to watching
      await tester.tap(find.text('Move to Watching'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify payload received real title
      expect(fakeEntries.lastCreatedPayload?['title'], equals('Interstellar'));
      expect(fakeEntries.lastCreatedPayload?['isWatching'], isTrue);
    });

    testWidgets('WatchlistTab active TMDB fetch fallback when raw item has no title on instant tap', (tester) async {
      final fakeEntries = _FakeEntriesRepo();
      final rawWatchlistItems = [
        {
          'id': 'item-raw-fightclub',
          'listId': 'watchlist-test-1',
          'tmdbId': 550,
          'title': null,
          'mediaType': 'movie',
          'addedAt': '2025-08-20T10:00:00Z',
        }
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            watchlistRepositoryProvider.overrideWithValue(_FakeWatchlistRepo(rawWatchlistItems)),
            searchRepositoryProvider.overrideWithValue(_FakeSearchRepo()),
            entriesRepositoryProvider.overrideWithValue(fakeEntries),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: WatchlistTab(),
            ),
          ),
        ),
      );

      // Immediately tap 3-dots without waiting for background enrichment
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byIcon(Icons.more_vert_rounded), findsOneWidget);
      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Tap 'Log as Watching'
      expect(find.text('Log as Watching'), findsOneWidget);
      await tester.tap(find.text('Log as Watching'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Must display "Fight Club" and never "this title"
      expect(find.text('Move to Currently Watching'), findsOneWidget);
      expect(find.textContaining('Fight Club'), findsWidgets);
      expect(find.textContaining('this title'), findsNothing);

      // Confirm
      await tester.tap(find.text('Move to Watching'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(fakeEntries.lastCreatedPayload?['title'], equals('Fight Club'));
    });
  });
}
