import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watchhive_mobile/features/auth/providers/auth_provider.dart';
import 'package:watchhive_mobile/features/search/repositories/search_repository.dart';
import 'package:watchhive_mobile/features/search/screens/search_screen.dart';
import 'package:watchhive_mobile/shared/models/models.dart';
import 'package:watchhive_mobile/shared/models/user.dart';
import 'package:watchhive_mobile/shared/widgets/shared_widgets.dart';

class MockTrendingSearchRepository implements SearchRepository {
  @override
  Future<List<MediaResult>> getTrending(
      {String mediaType = 'all', String timeWindow = 'week'}) async {
    return const [
      MediaResult(
        id: 501,
        title: 'Gladiator II',
        mediaType: 'movie',
        posterPath: '/gladiator2.jpg',
        voteAverage: 8.4,
        releaseDate: '2024-11-22',
        genreIds: [28, 18],
        originalLanguage: 'en',
      ),
      MediaResult(
        id: 502,
        title: 'Arcane',
        mediaType: 'tv',
        posterPath: '/arcane.jpg',
        voteAverage: 9.1,
        releaseDate: '2024-11-09',
        genreIds: [16, 10765],
        originalLanguage: 'en',
      ),
      MediaResult(
        id: 503,
        title: 'Wicked',
        mediaType: 'movie',
        posterPath: '/wicked.jpg',
        voteAverage: 7.8,
        releaseDate: '2024-11-20',
        genreIds: [10402, 14],
        originalLanguage: 'en',
      ),
    ];
  }

  @override
  Future<List<MediaResult>> getPopular({String type = 'movie'}) async {
    return const [
      MediaResult(
        id: 601,
        title: 'Dune: Part Two',
        mediaType: 'movie',
        posterPath: '/dune2.jpg',
        voteAverage: 8.6,
        releaseDate: '2024-03-01',
      ),
    ];
  }

  @override
  Future<List<MediaResult>> searchMedia(String query, {String? type}) async => [];

  @override
  Future<SmartMediaSearchResult> searchMediaSmart(String query, {String? type}) async =>
      SmartMediaSearchResult(results: const [], originalQuery: query);

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
  Future<List<User>> getSuggestedUsers() async => [];

  @override
  Future<List<Map<String, dynamic>>> getCommunityTrending() async => [
        {
          'id': 1,
          'title': 'Gladiator II',
          'type': 'MOVIE',
          'tmdbId': 501,
          'watchesCount': 42,
          'posterPath': '/gladiator2.jpg',
        }
      ];

  @override
  Future<List<String>> getRecentSearches() async => [];

  @override
  Future<void> addRecentSearch(String query) async {}

  @override
  Future<void> removeRecentSearch(String query) async {}

  @override
  Future<void> clearRecentSearches() async {}
}

class _MockAuthNotifier extends AuthNotifier {
  final AuthState _initialState;
  _MockAuthNotifier(this._initialState);

  @override
  Future<AuthState> build() async => _initialState;
}

void main() {
  group('SearchScreen Trending & Popular Movie Cards Robustness', () {
    late MockTrendingSearchRepository mockRepo;

    setUp(() {
      mockRepo = MockTrendingSearchRepository();
    });

    testWidgets('Trending & Popular section renders movie cards with TMDB posters without UnsupportedError', (tester) async {
      final mockUser = User(
        id: 'test_user_id',
        email: 'test@watchershive.com',
        username: 'cinephile',
        preferences: const {
          'languages': ['en'],
          'genres': [28, 18],
        },
        createdAt: DateTime(2024, 1, 1),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            searchRepositoryProvider.overrideWithValue(mockRepo),
            authStateProvider.overrideWith(
              () => _MockAuthNotifier(
                AuthState(user: mockUser, isAuthenticated: true),
              ),
            ),
          ],
          child: const MaterialApp(
            home: SearchScreen(),
          ),
        ),
      );

      // Settle discovery media loading with controlled pumps to avoid infinite animation timeout
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Verify that no unhandled exceptions were thrown
      expect(tester.takeException(), isNull);

      // Verify "Trending & Popular" header is present
      expect(find.text('Trending & Popular'), findsOneWidget);

      // Verify discovery media titles are rendered (Gladiator II & Arcane are visible in first row)
      expect(find.text('Gladiator II'), findsWidgets);
      expect(find.text('Arcane'), findsOneWidget);

      // Verify TMDBPosterImage widgets exist in the grid without errors
      expect(find.byType(TMDBPosterImage), findsWidgets);

      // Verify TV/MOVIE badges
      expect(find.text('TV'), findsOneWidget);
      expect(find.text('MOVIE'), findsWidgets);

      // Verify ratings are displayed
      expect(find.text('8.4'), findsOneWidget);
      expect(find.text('9.1'), findsOneWidget);
    });

    testWidgets('Switching between Trending filters updates grid items without crashing', (tester) async {
      final mockUser = User(
        id: 'test_user_id',
        email: 'test@watchershive.com',
        username: 'cinephile',
        createdAt: DateTime(2024, 1, 1),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            searchRepositoryProvider.overrideWithValue(mockRepo),
            authStateProvider.overrideWith(
              () => _MockAuthNotifier(
                AuthState(user: mockUser, isAuthenticated: true),
              ),
            ),
          ],
          child: const MaterialApp(
            home: SearchScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Tap "Movies" filter chip
      final moviesChip = find.text('Movies');
      expect(moviesChip, findsOneWidget);
      await tester.tap(moviesChip);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);

      // Tap "TV Shows" filter chip
      final tvChip = find.text('TV Shows');
      expect(tvChip, findsOneWidget);
      await tester.tap(tvChip);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
    });
  });
}
