import 'package:flutter_test/flutter_test.dart';
import 'package:watchhive_mobile/features/profile/models/compare_result.dart';

void main() {
  group('CompareResult Models Tests', () {
    test('parses backend compare response accurately', () {
      final json = {
        'userA': {
          'id': 'user-1',
          'username': 'cinephile1',
          'displayName': 'Alex Cine',
          'profilePictureUrl': 'https://example.com/a.jpg',
        },
        'userB': {
          'id': 'user-2',
          'username': 'cinephile2',
          'displayName': 'Sam Movie',
          'profilePictureUrl': 'https://example.com/b.jpg',
        },
        'stats': {
          'matchPercentage': 78,
          'totalCommon': 5,
          'totalUserAOnly': 10,
          'totalUserBOnly': 8,
          'totalUnique': 23,
        },
        'commonItems': [
          {
            'tmdbId': 157336,
            'title': 'Interstellar',
            'type': 'MOVIE',
            'posterPath': '/gEU2QniE6EwfVDxCzsxPnTe260Y.jpg',
            'entryA': {
              'id': 'entry-1',
              'rating': 9.5,
              'review': 'Phenomenal score',
              'watchedAt': '2024-01-01',
            },
            'entryB': {
              'id': 'entry-2',
              'rating': 9.0,
              'review': 'Love Nolan',
              'watchedAt': '2024-01-05',
            },
          }
        ],
        'userAOnlyItems': [
          {
            'tmdbId': 27205,
            'title': 'Inception',
            'type': 'MOVIE',
            'rating': 9.0,
            'watchedAt': '2023-12-01',
            'posterPath': '/inception.jpg',
          }
        ],
        'userBOnlyItems': [
          {
            'tmdbId': 19995,
            'title': 'Avatar',
            'type': 'MOVIE',
            'rating': 8.0,
            'watchedAt': '2023-11-20',
            'posterPath': '/avatar.jpg',
          }
        ],
      };

      final result = CompareResult.fromJson(json);

      expect(result.userA.username, 'cinephile1');
      expect(result.userB.displayName, 'Sam Movie');
      expect(result.stats.matchPercentage, 78);
      expect(result.stats.totalCommon, 5);
      expect(result.stats.totalUserAOnly, 10);
      expect(result.stats.totalUserBOnly, 8);
      expect(result.stats.totalUnique, 23);

      expect(result.commonItems.length, 1);
      final common = result.commonItems.first;
      expect(common.title, 'Interstellar');
      expect(common.entryA.rating, 9.5);
      expect(common.entryB.rating, 9.0);

      expect(result.userAOnlyItems.length, 1);
      expect(result.userAOnlyItems.first.title, 'Inception');
      expect(result.userAOnlyItems.first.rating, 9.0);

      expect(result.userBOnlyItems.length, 1);
      expect(result.userBOnlyItems.first.title, 'Avatar');
      expect(result.userBOnlyItems.first.rating, 8.0);
    });

    test('handles fallback response format gracefully', () {
      final json = {
        'userA': {'id': 'me', 'username': 'you', 'displayName': 'You'},
        'userB': {'id': 'target-id', 'username': 'friend', 'displayName': 'Friend'},
        'stats': {
          'matchPercentage': 50,
          'totalCommon': 1,
          'totalUserAOnly': 1,
          'totalUserBOnly': 0,
          'totalUnique': 2,
        },
        'commonItems': [
          {
            'tmdbId': 100,
            'title': 'Dune',
            'type': 'MOVIE',
            'entryA': {'rating': '8.5'},
            'entryB': {'rating': 8.0},
          }
        ],
        'userAOnlyItems': [],
        'userBOnlyItems': [],
      };

      final result = CompareResult.fromJson(json);
      expect(result.stats.matchPercentage, 50);
      expect(result.commonItems.first.entryA.rating, 8.5);
      expect(result.commonItems.first.entryB.rating, 8.0);
    });
  });
}
