import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:watchhive_mobile/shared/models/entry.dart';
import 'package:watchhive_mobile/shared/models/models.dart';
import 'package:watchhive_mobile/features/entries/repositories/entries_repository.dart';
import 'package:watchhive_mobile/features/entries/repositories/watchlist_repository.dart';
import 'package:watchhive_mobile/features/search/repositories/search_repository.dart';
import 'package:watchhive_mobile/features/entries/widgets/quick_currently_watching_sheet.dart';

class _FakeSearchRepository implements SearchRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<List<MediaResult>> searchMedia(String query, {String? type}) async {
    return [
      const MediaResult(
        id: 157336,
        title: 'Interstellar',
        mediaType: 'movie',
        releaseDate: '2014-11-05',
        voteAverage: 8.6,
      ),
    ];
  }
}

class _FakeEntriesRepository implements EntriesRepository {
  bool createEntryCalled = false;
  Map<String, dynamic>? lastPayload;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<Entry> createEntry(Map<String, dynamic> data) async {
    createEntryCalled = true;
    lastPayload = data;
    return Entry(
      id: 'entry-new',
      userId: 'user-1',
      tmdbId: data['tmdbId'] as int,
      title: data['title'] as String,
      type: data['type'] as String,
      isWatching: true,
      watchedAt: DateTime.now(),
      createdAt: DateTime.now(),
    );
  }
}

class _FakeWatchlistRepository implements WatchlistRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<void> removeFromWatchlistByTmdbId(int tmdbId, [String? listId]) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('QuickCurrentlyWatchingSheet triggers WHAlert.confirm before adding entry', (tester) async {
    final fakeEntriesRepo = _FakeEntriesRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          searchRepositoryProvider.overrideWithValue(_FakeSearchRepository()),
          entriesRepositoryProvider.overrideWithValue(fakeEntriesRepo),
          watchlistRepositoryProvider.overrideWithValue(_FakeWatchlistRepository()),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: QuickCurrentlyWatchingSheet(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Type in search bar to trigger search
    final textField = find.byType(TextField);
    expect(textField, findsOneWidget);
    await tester.enterText(textField, 'Interstellar');
    // Allow debounce timer (350ms) to fire
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    // Verify search result item appears
    final resultTile = find.widgetWithText(InkWell, 'Interstellar');
    expect(resultTile, findsOneWidget);

    // Tap on the search result
    await tester.tap(resultTile);
    await tester.pumpAndSettle();

    // Verify that the standard WHAlert.confirm dialog appeared!
    expect(find.text('Log as Currently Watching'), findsOneWidget);
    expect(find.text('Would you like to add "Interstellar" to your Currently Watching log?'), findsOneWidget);
    expect(find.text('Add to Watching'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);

    // Entry should NOT be created yet while dialog is showing
    expect(fakeEntriesRepo.createEntryCalled, isFalse);

    // Now tap "Add to Watching" confirm button
    await tester.tap(find.text('Add to Watching'));
    await tester.pumpAndSettle();

    // Verify entry was now created
    expect(fakeEntriesRepo.createEntryCalled, isTrue);
    expect(fakeEntriesRepo.lastPayload?['tmdbId'], equals(157336));
    expect(fakeEntriesRepo.lastPayload?['title'], equals('Interstellar'));
    expect(fakeEntriesRepo.lastPayload?['isWatching'], isTrue);
  });

  testWidgets('QuickCurrentlyWatchingSheet cancel dialog aborts entry creation', (tester) async {
    final fakeEntriesRepo = _FakeEntriesRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          searchRepositoryProvider.overrideWithValue(_FakeSearchRepository()),
          entriesRepositoryProvider.overrideWithValue(fakeEntriesRepo),
          watchlistRepositoryProvider.overrideWithValue(_FakeWatchlistRepository()),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: QuickCurrentlyWatchingSheet(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final textField = find.byType(TextField);
    await tester.enterText(textField, 'Interstellar');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    // Tap on result
    final resultTile = find.widgetWithText(InkWell, 'Interstellar');
    await tester.tap(resultTile);
    await tester.pumpAndSettle();

    expect(find.text('Log as Currently Watching'), findsOneWidget);

    // Tap Cancel
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    // Verify entry was NOT created
    expect(fakeEntriesRepo.createEntryCalled, isFalse);
  });
}
