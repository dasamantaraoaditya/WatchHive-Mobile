import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watchhive_mobile/features/entries/widgets/wh_entry_grid_card.dart';
import 'package:watchhive_mobile/features/rankings/models/ranking_stack.dart';
import 'package:watchhive_mobile/features/search/repositories/search_repository.dart';
import 'package:watchhive_mobile/shared/models/entry.dart';

void main() {
  group('Card Rating Display Priority Tests', () {
    testWidgets('WHEntryGridCard displays user rating over TMDB vote_average', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tmdbMediaDetailsProvider((tmdbId: 101, mediaType: 'movie')).overrideWith(
              (ref) => Future.value({
                'title': 'TMDB Movie Title',
                'vote_average': 6.8,
                'poster_path': '/poster.jpg',
              }),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                height: 400,
                width: 250,
                child: WHEntryGridCard(
                  tmdbId: 101,
                  title: '',
                  mediaType: 'movie',
                  rating: 9.5, // User rating
                  mode: WHEntryCardMode.history,
                  onTap: () {},
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Card must display user's rating (9.5), NOT TMDB's vote_average (6.8)!
      expect(find.text('9.5'), findsOneWidget);
      expect(find.text('6.8'), findsNothing);
    });

    test('Entry.fromJson preserves null user rating and does not leak TMDB vote_average for watched entries', () {
      final json = {
        'id': 'entry-123',
        'type': 'WATCH_ENTRY',
        'tmdbId': 550,
        'title': 'Fight Club',
        'rating': null,
        'vote_average': 8.4,
      };

      final entry = Entry.fromJson(json);
      // Watched entry without user rating must stay null
      expect(entry.rating, isNull);
    });

    test('Entry.fromJson adopts TMDB vote_average for platform suggestions', () {
      final json = {
        'id': 'sugg-123',
        'type': 'SUGGESTION',
        'tmdbId': 550,
        'title': 'Fight Club',
        'data': {
          'rating': null,
          'vote_average': 8.4,
        },
      };

      final entry = Entry.fromJson(json);
      // Suggestions can display the TMDB score
      expect(entry.rating, equals(8.4));
    });

    test('RankingStackItem parses local user rating properly', () {
      final item = RankedItem.fromJson({
        'id': 'item-1',
        'listId': 'list-1',
        'tmdbId': 550,
        'mediaType': 'movie',
        'orderIndex': 0,
        'title': 'Fight Club',
        'rating': 9.2,
        'vote_average': 8.4,
      });

      expect(item.localRating, equals(9.2));
    });
  });
}
