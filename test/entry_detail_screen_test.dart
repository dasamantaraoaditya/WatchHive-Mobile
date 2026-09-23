import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:watchhive_mobile/features/entries/repositories/entries_repository.dart';
import 'package:watchhive_mobile/features/entries/screens/entry_detail_screen.dart';
import 'package:watchhive_mobile/features/feed/widgets/wh_feed_card.dart';
import 'package:watchhive_mobile/shared/models/entry.dart';
import 'package:watchhive_mobile/shared/models/user.dart';

class _FakeEntriesRepository implements EntriesRepository {
  final Entry mockEntry;
  _FakeEntriesRepository(this.mockEntry);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<Entry> getEntryById(String id) async {
    return mockEntry;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testUser = User(
    id: 'user-789',
    username: 'moviebuff',
    displayName: 'Movie Buff',
    email: 'buff@example.com',
    createdAt: DateTime(2025, 1, 1),
  );

  final testEntry = Entry(
    id: 'entry-test-101',
    userId: 'user-789',
    tmdbId: 550,
    title: 'Fight Club',
    type: 'MOVIE',
    watchedAt: DateTime(2025, 6, 1, 12, 0),
    rating: 9.0,
    review: 'The first rule of Fight Club is you do not talk about Fight Club.',
    user: testUser,
    likesCount: 42,
    commentsCount: 7,
    createdAt: DateTime(2025, 6, 1, 12, 0),
  );

  testWidgets('EntryDetailScreen renders post details with WHFeedCard', (tester) async {
    final fakeRepo = _FakeEntriesRepository(testEntry);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          entriesRepositoryProvider.overrideWithValue(fakeRepo),
        ],
        child: MaterialApp(
          home: EntryDetailScreen(
            entryId: 'entry-test-101',
            initialEntry: testEntry,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify AppBar title is 'Post'
    expect(find.text('Post'), findsOneWidget);

    // Verify WHFeedCard exists
    expect(find.byType(WHFeedCard), findsOneWidget);

    // Verify Title and User Display
    expect(find.text('Fight Club'), findsOneWidget);
    expect(find.textContaining('Movie Buff'), findsOneWidget);

    // Verify Review
    expect(find.text('"The first rule of Fight Club is you do not talk about Fight Club."'), findsOneWidget);

    // Verify like & comments count
    expect(find.text('42'), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
  });
}
