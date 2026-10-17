import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:watchhive_mobile/core/api/api_client.dart';
import 'package:watchhive_mobile/core/auth/auth_manager.dart';
import 'package:watchhive_mobile/features/entries/repositories/watchlist_repository.dart';
import 'package:watchhive_mobile/features/entries/widgets/add_to_watchlist_sheet.dart';
import 'package:watchhive_mobile/features/search/repositories/search_repository.dart';
import 'package:watchhive_mobile/shared/models/user.dart';

class _FakeAuthManager extends AuthManager {}

class _FakeWatchlistRepository extends WatchlistRepository {
  bool addToWatchlistCalled = false;
  String? lastSuggestedByUserId;
  String? lastTitle;

  _FakeWatchlistRepository() : super(ApiClient(_FakeAuthManager()));

  @override
  Future<void> addToWatchlist({
    required int tmdbId,
    required String title,
    required String mediaType,
    String? posterPath,
    String? overview,
    String? suggestedByUserId,
  }) async {
    addToWatchlistCalled = true;
    lastTitle = title;
    lastSuggestedByUserId = suggestedByUserId;
  }
}

class _FakeSearchRepository extends SearchRepository {
  _FakeSearchRepository() : super(ApiClient(_FakeAuthManager()));

  @override
  Future<List<User>> searchUsers(String query) async {
    return [
      User(
        id: 'user-friend-1',
        username: 'cinephile_bob',
        displayName: 'Bob The Cinephile',
        profilePictureUrl: null,
        createdAt: DateTime(2026, 1, 1),
      ),
    ];
  }
}

void main() {
  testWidgets('AddToWatchlistSheet displays media preview, allows friend search, and adds to watchlist', (tester) async {
    final fakeWatchlistRepo = _FakeWatchlistRepository();
    final fakeSearchRepo = _FakeSearchRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          watchlistRepositoryProvider.overrideWithValue(fakeWatchlistRepo),
          searchRepositoryProvider.overrideWithValue(fakeSearchRepo),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: AddToWatchlistSheet(
              tmdbId: 157336,
              title: 'Interstellar',
              mediaType: 'movie',
              posterPath: '/gEU2QniE6E77NI6lCU6MxlNBvIx.jpg',
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Title & Suggested By header are displayed
    expect(find.text('Add to Watchlist'), findsNWidgets(2));
    expect(find.text('Interstellar'), findsOneWidget);
    expect(find.text('💡 Suggested By'), findsOneWidget);
    expect(find.text('(optional)'), findsOneWidget);

    // Search for friend
    final searchInput = find.byType(TextField);
    expect(searchInput, findsOneWidget);
    await tester.enterText(searchInput, 'bob');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    // Verify friend search results show up
    expect(find.text('Bob The Cinephile'), findsOneWidget);
    expect(find.text('@cinephile_bob'), findsOneWidget);

    // Tap to select friend
    await tester.tap(find.text('Bob The Cinephile'));
    await tester.pumpAndSettle();

    // Verify selected friend chip is shown
    expect(find.text('Bob The Cinephile'), findsOneWidget);
    expect(find.text('@cinephile_bob'), findsOneWidget);

    // Submit
    final submitButton = find.widgetWithText(ElevatedButton, 'Add with Suggestion');
    expect(submitButton, findsOneWidget);
    await tester.tap(submitButton);
    await tester.pumpAndSettle();

    expect(fakeWatchlistRepo.addToWatchlistCalled, isTrue);
    expect(fakeWatchlistRepo.lastTitle, 'Interstellar');
    expect(fakeWatchlistRepo.lastSuggestedByUserId, 'user-friend-1');
  });

  testWidgets('AddToWatchlistSheet works with prefilled suggestion', (tester) async {
    final fakeWatchlistRepo = _FakeWatchlistRepository();
    final fakeSearchRepo = _FakeSearchRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          watchlistRepositoryProvider.overrideWithValue(fakeWatchlistRepo),
          searchRepositoryProvider.overrideWithValue(fakeSearchRepo),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: AddToWatchlistSheet(
              tmdbId: 1396,
              title: 'Breaking Bad',
              mediaType: 'tv',
              prefillSuggestedByUser: User(
                id: 'alice-1',
                username: 'alice',
                displayName: 'Alice W',
                createdAt: DateTime(2026, 1, 1),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Pre-filled user chip is shown immediately
    expect(find.text('Breaking Bad'), findsOneWidget);
    expect(find.text('Alice W'), findsOneWidget);
    expect(find.text('@alice'), findsOneWidget);

    // Submit
    final submitButton = find.widgetWithText(ElevatedButton, 'Add with Suggestion');
    await tester.tap(submitButton);
    await tester.pumpAndSettle();

    expect(fakeWatchlistRepo.addToWatchlistCalled, isTrue);
    expect(fakeWatchlistRepo.lastTitle, 'Breaking Bad');
    expect(fakeWatchlistRepo.lastSuggestedByUserId, 'alice-1');
  });
}
