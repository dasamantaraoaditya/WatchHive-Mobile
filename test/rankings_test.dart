import 'package:flutter_test/flutter_test.dart';
import 'package:watchhive_mobile/features/rankings/models/ranking_stack.dart';

void main() {
  group('Rankings Models Tests', () {
    test('RankedItem parses correctly from JSON with year extraction and local rating', () {
      final json = {
        'id': 'item-1',
        'listId': 'list-100',
        'tmdbId': 157336,
        'mediaType': 'movie',
        'orderIndex': 0,
        'title': 'Interstellar',
        'posterPath': '/gEU2QniE6EwfVDxCzsxPnTe260Y.jpg',
        'releaseDate': '2014-11-05',
        'voteAverage': 8.4,
        'localRating': 10.0,
        'localReview': 'Absolute masterpiece',
        'tags': ['Sci-Fi', 'Nolan'],
      };

      final item = RankedItem.fromJson(json);

      expect(item.id, 'item-1');
      expect(item.listId, 'list-100');
      expect(item.tmdbId, 157336);
      expect(item.mediaType, 'movie');
      expect(item.title, 'Interstellar');
      expect(item.year, '2014');
      expect(item.voteAverage, 8.4);
      expect(item.localRating, 10.0);
      expect(item.tags, contains('Sci-Fi'));
    });

    test('RankingStack parses from JSON and formats items', () {
      final json = {
        'id': 'list-100',
        'userId': 'user-1',
        'name': 'Top 10 Nolan Movies',
        'description': 'Ranked by emotional impact and score',
        'type': 'RANKING_STACK',
        'isPublic': true,
        'items': [
          {
            'id': 'item-1',
            'listId': 'list-100',
            'tmdbId': 157336,
            'mediaType': 'movie',
            'orderIndex': 0,
            'title': 'Interstellar',
            'releaseDate': '2014-11-05',
          },
          {
            'id': 'item-2',
            'listId': 'list-100',
            'tmdbId': 27205,
            'mediaType': 'movie',
            'orderIndex': 1,
            'title': 'Inception',
            'releaseDate': '2010-07-16',
          }
        ],
      };

      final stack = RankingStack.fromJson(json);

      expect(stack.name, 'Top 10 Nolan Movies');
      expect(stack.isPublic, isTrue);
      expect(stack.items.length, 2);
      expect(stack.items.first.title, 'Interstellar');
      expect(stack.items.last.title, 'Inception');
    });

    test('RankingStack copyWith allows immutability modifications', () {
      const initial = RankingStack(
        id: 'list-1',
        userId: 'user-1',
        name: 'Initial Stack',
      );

      final updated = initial.copyWith(
        name: 'Updated Stack',
        isPublic: false,
      );

      expect(updated.name, 'Updated Stack');
      expect(updated.isPublic, isFalse);
      expect(updated.id, 'list-1');
    });
  });
}
