import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:watchhive_mobile/shared/models/entry.dart';
import 'package:watchhive_mobile/shared/models/user.dart';
import 'package:watchhive_mobile/shared/models/models.dart';
import 'package:watchhive_mobile/features/entries/screens/movie_details_screen.dart';
import 'package:watchhive_mobile/features/auth/providers/auth_provider.dart';
import 'package:watchhive_mobile/features/search/repositories/search_repository.dart';
import 'package:watchhive_mobile/features/entries/repositories/watchlist_repository.dart';
import 'package:watchhive_mobile/features/entries/repositories/entries_repository.dart';

class _FakeSearchRepository implements SearchRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<Map<String, dynamic>> getMovieDetails(int tmdbId) async {
    return {
      'id': tmdbId,
      'title': 'Fight Club',
      'overview': 'An insomniac office worker forms an underground fight club.',
      'poster_path': '/poster.jpg',
      'backdrop_path': '/backdrop.jpg',
      'vote_average': 8.4,
      'vote_count': 26000,
      'release_date': '1999-10-15',
      'genres': [{'name': 'Drama'}],
      'runtime': 139,
    };
  }

  @override
  Future<List<MediaResult>> getRecommendations(String mediaType, int tmdbId) async {
    return [];
  }
}

class _FakeWatchlistRepository implements WatchlistRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<bool> isInWatchlist(int tmdbId) async => false;
}

class _FakeEntriesRepository implements EntriesRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<Entry?> getEntryForTmdbId(int tmdbId, {String? userId, String? title}) async => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testUser = User(
    id: 'user-123',
    username: 'cinemafan',
    displayName: 'Cinema Fan',
    email: 'fan@watchhive.com',
    createdAt: DateTime(2025, 1, 1),
  );

  final friendUser = User(
    id: 'user-456',
    username: 'cinephile_bob',
    displayName: 'Bob The Cinephile',
    email: 'bob@watchhive.com',
    createdAt: DateTime(2025, 1, 1),
  );

  final testEntry = Entry(
    id: 'entry-789',
    userId: 'user-123',
    tmdbId: 550,
    title: 'Fight Club',
    type: 'MOVIE',
    watchedAt: DateTime(2025, 5, 10),
    rating: 9.5,
    review: 'An absolute masterpiece of cinema with a revolutionary twist.',
    tags: ['MindBending', 'CultClassic'],
    watchLocation: 'Cinema (IMAX)',
    isRewatch: true,
    createdAt: DateTime(2025, 5, 10),
  );

  final friendEntry = Entry(
    id: 'entry-999',
    userId: 'user-456',
    tmdbId: 550,
    title: 'Fight Club',
    type: 'MOVIE',
    watchedAt: DateTime(2025, 4, 1),
    rating: 8.5,
    review: 'Fincher at his best. Brad Pitt and Edward Norton were phenomenal.',
    tags: ['Fincher', 'Classics'],
    watchLocation: 'Home Theater',
    isRewatch: false,
    user: friendUser,
    createdAt: DateTime(2025, 4, 1),
  );

  group('MovieDetailsScreen Logged Review & Rating Display Tests', () {
    testWidgets('renders self-logged review card with score, tags, location, and rewatch', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateProvider.overrideWith(() => _MockAuthNotifier(AuthState(
              user: testUser,
              isAuthenticated: true,
            ))),
            searchRepositoryProvider.overrideWithValue(_FakeSearchRepository()),
            watchlistRepositoryProvider.overrideWithValue(_FakeWatchlistRepository()),
            entriesRepositoryProvider.overrideWithValue(_FakeEntriesRepository()),
          ],
          child: MaterialApp(
            home: MovieDetailsScreen(
              mediaType: 'movie',
              tmdbId: 550,
              initialEntry: testEntry,
              authorUser: testUser,
            ),
          ),
        ),
      );

      // Pump and settle async load
      await tester.pumpAndSettle();

      // Check for "Your Watch Entry & Review" banner
      expect(find.text('Your Watch Entry & Review'), findsOneWidget);

      // Check for score and rating
      expect(find.textContaining('9.5'), findsWidgets);

      // Check for review text
      expect(find.text('An absolute masterpiece of cinema with a revolutionary twist.'), findsOneWidget);

      // Check for tags
      expect(find.text('#MindBending'), findsOneWidget);
      expect(find.text('#CultClassic'), findsOneWidget);

      // Check for location
      expect(find.text('Cinema (IMAX)'), findsOneWidget);

      // Check for Rewatch badge
      expect(find.text('Rewatch'), findsOneWidget);

      // Check that dynamic action button displays logged rating
      expect(find.text('Logged (⭐ 9.5)'), findsOneWidget);
    });

    testWidgets('renders friend review card with friend username, avatar, and score', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateProvider.overrideWith(() => _MockAuthNotifier(AuthState(
              user: testUser,
              isAuthenticated: true,
            ))),
            searchRepositoryProvider.overrideWithValue(_FakeSearchRepository()),
            watchlistRepositoryProvider.overrideWithValue(_FakeWatchlistRepository()),
            entriesRepositoryProvider.overrideWithValue(_FakeEntriesRepository()),
          ],
          child: MaterialApp(
            home: MovieDetailsScreen(
              mediaType: 'movie',
              tmdbId: 550,
              initialEntry: friendEntry,
              authorUser: friendUser,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check for friend's watch entry banner
      expect(find.text("Bob The Cinephile's Watch Entry"), findsOneWidget);
      expect(find.text('@cinephile_bob'), findsOneWidget);

      // Check for friend review text
      expect(find.text('Fincher at his best. Brad Pitt and Edward Norton were phenomenal.'), findsOneWidget);

      // Check for friend's score
      expect(find.textContaining('8.5'), findsWidgets);

      // Check for friend tags and location
      expect(find.text('#Fincher'), findsOneWidget);
      expect(find.text('Home Theater'), findsOneWidget);

      // Check that the viewer sees "View Profile" button for friend
      expect(find.text('View Profile'), findsOneWidget);
    });
  });
}

class _MockAuthNotifier extends AuthNotifier {
  final AuthState _initialState;
  _MockAuthNotifier(this._initialState);

  @override
  Future<AuthState> build() async => _initialState;
}
