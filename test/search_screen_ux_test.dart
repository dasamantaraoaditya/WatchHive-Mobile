import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watchhive_mobile/features/search/repositories/search_repository.dart';
import 'package:watchhive_mobile/features/search/screens/search_screen.dart';
import 'package:watchhive_mobile/shared/models/models.dart';
import 'package:watchhive_mobile/shared/models/user.dart';

class FakeSearchRepository implements SearchRepository {
  int searchMediaCalls = 0;
  int searchUsersCalls = 0;
  String lastQuery = '';

  @override
  Future<List<MediaResult>> searchMedia(String query, {String? type}) async {
    searchMediaCalls++;
    lastQuery = query;
    return [
      const MediaResult(
        id: 101,
        title: 'Dune: Part Two',
        mediaType: 'movie',
        posterPath: '/dune.jpg',
      ),
    ];
  }

  @override
  Future<Map<String, dynamic>> getMovieDetails(int tmdbId) async => {};

  @override
  Future<Map<String, dynamic>> getTvDetails(int tmdbId) async => {};

  @override
  Future<Map<String, dynamic>> getTvSeasonDetails(int tvId, int seasonNumber) async => {};

  @override
  Future<List<MediaResult>> getRecommendations(String mediaType, int tmdbId) async => [];

  @override
  Future<List<User>> searchUsers(String query) async {
    searchUsersCalls++;
    return [];
  }

  @override
  Future<List<MediaResult>> getTrending({String mediaType = 'all', String timeWindow = 'week'}) async {
    return [];
  }

  @override
  Future<List<MediaResult>> getPopular({String type = 'movie'}) async {
    return [];
  }

  @override
  Future<List<User>> getSuggestedUsers() async {
    return [];
  }

  @override
  Future<List<Map<String, dynamic>>> getCommunityTrending() async {
    return [];
  }

  @override
  Future<List<String>> getRecentSearches() async => ['Oppenheimer'];

  @override
  Future<void> addRecentSearch(String query) async {}

  @override
  Future<void> removeRecentSearch(String query) async {}

  @override
  Future<void> clearRecentSearches() async {}
}

void main() {
  group('SearchScreen UX & Debounce Tests', () {
    late FakeSearchRepository fakeRepo;

    setUp(() {
      fakeRepo = FakeSearchRepository();
    });

    testWidgets('search box auto-focuses on open and sits at the bottom of the screen', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            searchRepositoryProvider.overrideWithValue(fakeRepo),
          ],
          child: const MaterialApp(
            home: SearchScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify the search box TextField exists
      final textFieldFinder = find.byType(TextField);
      expect(textFieldFinder, findsOneWidget);

      // Verify the search field has focus (auto-selected)
      final textFieldWidget = tester.widget<TextField>(textFieldFinder);
      expect(textFieldWidget.focusNode?.hasFocus, isTrue);

      // Verify position: the search box is located in the bottom half of the screen
      final textFieldRect = tester.getRect(textFieldFinder);
      expect(textFieldRect.bottom, greaterThan(500)); // Standard test screen is 600 in height
    });

    testWidgets('debounces search by 2 seconds and retains focus across typing', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            searchRepositoryProvider.overrideWithValue(fakeRepo),
          ],
          child: const MaterialApp(
            home: SearchScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final textFieldFinder = find.byType(TextField);

      // Enter 2 letters
      await tester.enterText(textFieldFinder, 'Du');
      await tester.pump(); // Immediate pump

      // Immediately after typing, network search should NOT have fired yet (debouncing)
      expect(fakeRepo.searchMediaCalls, 0);

      // Verify focus is STILL on the text field after typing 2 characters
      final focusNode = tester.widget<TextField>(textFieldFinder).focusNode;
      expect(focusNode?.hasFocus, isTrue);

      // Advance by 1 second - still should not have fired
      await tester.pump(const Duration(seconds: 1));
      expect(fakeRepo.searchMediaCalls, 0);
      expect(focusNode?.hasFocus, isTrue);

      // Continue typing more letters before 2s - timer resets
      await tester.enterText(textFieldFinder, 'Dune');
      await tester.pump();
      expect(fakeRepo.searchMediaCalls, 0);
      expect(focusNode?.hasFocus, isTrue);

      // Advance by 1.5 seconds - still pending
      await tester.pump(const Duration(milliseconds: 1500));
      expect(fakeRepo.searchMediaCalls, 0);
      expect(focusNode?.hasFocus, isTrue);

      // Advance to full 2 seconds since last keystroke - should fire!
      await tester.pump(const Duration(milliseconds: 600));
      expect(fakeRepo.searchMediaCalls, 1);
      expect(fakeRepo.lastQuery, 'Dune');
      expect(focusNode?.hasFocus, isTrue);

      // Complete async response
      await tester.pump();
      await tester.pump();

      // Verify results are visible and focus is STILL preserved!
      expect(find.text('Dune: Part Two'), findsOneWidget);
      expect(focusNode?.hasFocus, isTrue);
    });

    testWidgets('pressing enter/submitted triggers search immediately without waiting 2 seconds', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            searchRepositoryProvider.overrideWithValue(fakeRepo),
          ],
          child: const MaterialApp(
            home: SearchScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final textFieldFinder = find.byType(TextField);

      await tester.enterText(textFieldFinder, 'Interstellar');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();

      // Should have triggered immediately on submitted
      expect(fakeRepo.searchMediaCalls, 1);
      expect(fakeRepo.lastQuery, 'Interstellar');
    });
  });
}
