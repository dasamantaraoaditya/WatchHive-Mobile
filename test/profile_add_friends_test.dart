import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watchhive_mobile/features/profile/widgets/add_friends_sheet.dart';
import 'package:watchhive_mobile/features/search/repositories/search_repository.dart';
import 'package:watchhive_mobile/shared/models/models.dart';
import 'package:watchhive_mobile/shared/models/user.dart';

class MockSearchRepository implements SearchRepository {
  @override
  Future<List<User>> getSuggestedUsers() async => [];

  @override
  Future<List<MediaResult>> searchMedia(String query, {String? type}) async => [];

  @override
  Future<SmartMediaSearchResult> searchMediaSmart(String query, {String? type}) async =>
      SmartMediaSearchResult(results: [], originalQuery: query);

  @override
  Future<Map<String, dynamic>> getMovieDetails(int tmdbId) async => {};

  @override
  Future<Map<String, dynamic>> getTvDetails(int tmdbId) async => {};

  @override
  Future<Map<String, dynamic>> getTvSeasonDetails(int tvId, int seasonNumber) async => {};

  @override
  Future<List<MediaResult>> getRecommendations(String mediaType, int tmdbId) async => [];

  @override
  Future<List<User>> searchUsers(String query) async => [];

  @override
  Future<List<MediaResult>> getTrending({String mediaType = 'all', String timeWindow = 'week'}) async => [];

  @override
  Future<List<MediaResult>> getPopular({String type = 'movie'}) async => [];

  @override
  Future<List<Map<String, dynamic>>> getCommunityTrending() async => [];

  @override
  Future<List<String>> getRecentSearches() async => [];

  @override
  Future<void> addRecentSearch(String query) async {}

  @override
  Future<void> removeRecentSearch(String query) async {}

  @override
  Future<void> clearRecentSearches() async {}
}

void main() {
  final testUser = User(
    id: 'user-123',
    username: 'cinephile_sam',
    email: 'sam@watchhive.test',
    displayName: 'Sam Cinema',
    followersCount: 12,
    followingCount: 8,
    createdAt: DateTime.now(),
  );

  group('Profile Add Friends Sheet Tests', () {
    testWidgets('AddFriendsSheet renders all primary actions: Search, Invite, QR Code', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            searchRepositoryProvider.overrideWithValue(MockSearchRepository()),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: AddFriendsSheet(user: testUser),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Header
      expect(find.text('Add Friends to Your Hive'), findsOneWidget);
      expect(find.text('Connect, share suggestions & compare taste'), findsOneWidget);

      // Verify Action Cards
      expect(find.text('Search Friends & People'), findsOneWidget);
      expect(find.text('Find friends by name or @username'), findsOneWidget);

      expect(find.text('Invite Friends'), findsOneWidget);
      expect(find.text('Share your personal invite link'), findsOneWidget);

      expect(find.text('My Hive Code'), findsOneWidget);
      expect(find.text('Show QR for friends to scan'), findsOneWidget);

      expect(find.text('Scan QR Code'), findsOneWidget);
      expect(find.text('Open camera to follow friend'), findsOneWidget);

      // Verify Section Header
      expect(find.text('Suggested Friends'), findsOneWidget);
    });
  });
}
