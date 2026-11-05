import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watchhive_mobile/features/entries/repositories/entries_repository.dart';
import 'package:watchhive_mobile/features/entries/screens/add_entry_sheet.dart';
import 'package:watchhive_mobile/shared/models/entry.dart';

class MockEntriesRepository implements EntriesRepository {
  final bool hasWatched;
  final Entry? existingEntry;

  MockEntriesRepository({this.hasWatched = true, this.existingEntry});

  @override
  Future<({bool hasWatched, int watchCount, Entry? existingEntry})> checkPreviousWatch(int tmdbId) async {
    return (hasWatched: hasWatched, watchCount: hasWatched ? 1 : 0, existingEntry: existingEntry);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('AddEntrySheet Rewatch & Duplicate Watch Tests', () {
    testWidgets('renders already watched warning and previous watch card when title watched before', (tester) async {
      final previousEntry = Entry(
        id: 'entry-prev-1',
        userId: 'user-1',
        tmdbId: 550,
        title: 'Fight Club',
        type: 'MOVIE',
        rating: 9.0,
        review: 'Incredible mind-bending movie!',
        watchLocation: 'Cinema IMAX',
        isRewatch: false,
        isWatching: false,
        watchedAt: DateTime(2025, 5, 10, 19, 30),
        createdAt: DateTime(2025, 5, 10, 19, 30),
      );

      final mockRepo = MockEntriesRepository(
        hasWatched: true,
        existingEntry: previousEntry,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            entriesRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: AddEntrySheet(
                prefillTmdbId: 550,
                prefillTitle: 'Fight Club',
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check for already watched banner
      expect(find.text('You already watched this title!'), findsOneWidget);
      expect(find.text('REWATCH REQUIRED'), findsOneWidget);
      expect(
        find.text('Rewatch is enabled by default to record this viewing, creating another entry in your Hive history.'),
        findsOneWidget,
      );

      // Check for previous watch summary card
      expect(find.textContaining('Watched May 10, 2025'), findsOneWidget);
      expect(find.text('9.0/10'), findsOneWidget);
      expect(find.text('Watched at Cinema IMAX'), findsOneWidget);
      expect(find.text('"Incredible mind-bending movie!"'), findsOneWidget);

      // Rewatch Status switch should indicate Rewatch
      expect(find.text('Rewatch'), findsWidgets);
    });
  });
}
