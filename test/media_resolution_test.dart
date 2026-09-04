import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watchhive_mobile/shared/models/entry.dart';
import 'package:watchhive_mobile/shared/models/models.dart';
import 'package:watchhive_mobile/features/rankings/models/ranking_stack.dart';
import 'package:watchhive_mobile/features/entries/widgets/wh_entry_grid_card.dart';
import 'package:watchhive_mobile/features/search/repositories/search_repository.dart';

class _FakeSearchRepo implements SearchRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => Future.value(<String, dynamic>{});
}

void main() {
  group('Media Models Parsing & Fallbacks', () {
    test('Entry.fromJson parses tmdb_id snake_case and nested media correctly', () {
      final json = {
        'id': 'entry-uuid-1234',
        'tmdb_id': 550,
        'type': 'MOVIE',
        'media': {
          'title': 'Fight Club',
          'poster_path': '/pB8BM7pdSp6B6Ih7QZ4DrQ3PmJK.jpg',
        },
      };

      final entry = Entry.fromJson(json);
      expect(entry.tmdbId, equals(550));
      expect(entry.title, equals('Fight Club'));
      expect(entry.posterPath, equals('/pB8BM7pdSp6B6Ih7QZ4DrQ3PmJK.jpg'));
    });

    test('Entry.fromJson falls back to backdrop_path when poster is absent', () {
      final json = {
        'id': 'entry-uuid-5678',
        'tmdbId': 105,
        'title': 'Back to the Future',
        'backdrop_path': '/backdrop.jpg',
      };

      final entry = Entry.fromJson(json);
      expect(entry.tmdbId, equals(105));
      expect(entry.title, equals('Back to the Future'));
      expect(entry.posterPath, equals('/backdrop.jpg'));
    });

    test('RankedItem.fromJson extracts title and poster from nested tmdb/media', () {
      final json = {
        'id': 'item-1',
        'listId': 'list-1',
        'orderIndex': 0,
        'tmdb': {
          'id': 27205,
          'title': 'Inception',
          'poster_path': '/inception.jpg',
          'vote_average': 8.8,
        },
      };

      final item = RankedItem.fromJson(json);
      expect(item.tmdbId, equals(27205));
      expect(item.title, equals('Inception'));
      expect(item.posterPath, equals('/inception.jpg'));
      expect(item.voteAverage, equals(8.8));
    });

    test('MediaResult.fromJson extracts original_name and backdrop_path', () {
      final json = {
        'id': 1399,
        'original_name': 'Game of Thrones',
        'backdrop_path': '/got_backdrop.jpg',
        'media_type': 'tv',
      };

      final result = MediaResult.fromJson(json);
      expect(result.id, equals(1399));
      expect(result.title, equals('Game of Thrones'));
      expect(result.posterPath, equals('/got_backdrop.jpg'));
      expect(result.mediaType, equals('tv'));
    });
  });

  group('WHEntryGridCard Title & Image Resilience', () {
    testWidgets('does not display raw "Untitled" text while loading from TMDB', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            searchRepositoryProvider.overrideWithValue(_FakeSearchRepo()),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 200,
                height: 320,
                child: WHEntryGridCard(
                  tmdbId: 550,
                  title: 'Untitled',
                  mediaType: 'movie',
                  mode: WHEntryCardMode.watchlist,
                  onTap: () {},
                ),
              ),
            ),
          ),
        ),
      );

      // Verify that "Untitled" is not rendered on screen while fetching
      expect(find.text('Untitled'), findsNothing);

      // Clean up Shimmer animation timer by disposing widget tree
      await tester.pumpWidget(const SizedBox());
    });
  });
}
