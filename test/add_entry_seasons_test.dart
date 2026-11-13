import 'package:flutter_test/flutter_test.dart';
import 'package:watchhive_mobile/shared/models/entry.dart';

void main() {
  group('Entry Model Seasons Multi-Select Tests', () {
    test('Entry defaults seasons to empty list and parses correctly from json', () {
      final entry = Entry(
        id: '1',
        userId: 'u1',
        tmdbId: 1399,
        title: 'Game of Thrones',
        type: 'TV_SHOW',
        watchedAt: DateTime.now(),
        createdAt: DateTime.now(),
      );
      expect(entry.seasons, isEmpty);
      expect(entry.currentSeason, isNull);

      final jsonWithSeasons = {
        'id': '2',
        'userId': 'u1',
        'tmdbId': 1399,
        'title': 'Game of Thrones',
        'type': 'TV_SHOW',
        'seasons': [1, 2, 3],
        'currentSeason': 3,
        'createdAt': DateTime.now().toIso8601String(),
        'watchedAt': DateTime.now().toIso8601String(),
      };

      final parsed = Entry.fromJson(jsonWithSeasons);
      expect(parsed.seasons, equals([1, 2, 3]));
      expect(parsed.currentSeason, equals(3));

      final outputJson = parsed.toJson();
      expect(outputJson['seasons'], equals([1, 2, 3]));
      expect(outputJson['currentSeason'], equals(3));
    });

    test('Entry copyWith updates seasons list', () {
      final entry = Entry(
        id: '1',
        userId: 'u1',
        tmdbId: 1399,
        title: 'Game of Thrones',
        type: 'TV_SHOW',
        watchedAt: DateTime.now(),
        createdAt: DateTime.now(),
      );

      final updated = entry.copyWith(seasons: [1, 4], currentSeason: 4);
      expect(updated.seasons, equals([1, 4]));
      expect(updated.currentSeason, equals(4));
    });
  });
}
