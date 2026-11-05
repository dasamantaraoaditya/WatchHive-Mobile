import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:watchhive_mobile/core/services/data_parser_service.dart';

void main() {
  group('DataParserService', () {
    test('Letterboxd diary.csv: scales 5-star rating 2x and prioritizes Watched Date', () {
      const csv = '''Date,Name,Year,Letterboxd URI,Rating,Rewatch,Tags,Watched Date
2024-03-01,Dune: Part Two,2024,https://boxd.it/test1,4.5,Yes,"sci-fi, imax",2024-03-02
2024-02-15,Oppenheimer,2023,https://boxd.it/test2,5.0,No,"cinema",2024-02-16
2024-01-10,Past Lives,2023,https://boxd.it/test3,3.5,No,"drama",2024-01-10''';

      final bytes = utf8.encode(csv);
      final result = DataParserService.parseFile(bytes, 'diary.csv');

      expect(result['entries'], isNotNull);
      final entries = result['entries'] as List<Map<String, dynamic>>;
      expect(entries.length, 3);

      // Dune: Part Two: 4.5 * 2 = 9.0, watchedAt should use Watched Date (2024-03-02)
      final dune = entries[0];
      expect(dune['title'], 'Dune: Part Two');
      expect(dune['year'], 2024);
      expect(dune['rating'], 9.0);
      expect(dune['isRewatch'], true);
      expect(dune['watchedAt'], contains('2024-03-02'));
      expect(dune['tags'], contains('sci-fi'));

      // Oppenheimer: 5.0 * 2 = 10.0
      final oppenheimer = entries[1];
      expect(oppenheimer['title'], 'Oppenheimer');
      expect(oppenheimer['rating'], 10.0);
      expect(oppenheimer['isRewatch'], false);
      expect(oppenheimer['watchedAt'], contains('2024-02-16'));

      // Past Lives: 3.5 * 2 = 7.0
      final pastLives = entries[2];
      expect(pastLives['title'], 'Past Lives');
      expect(pastLives['rating'], 7.0);
    });

    test('IMDb ratings.csv: maps Const to imdbId and retains 10-point scale', () {
      const csv = '''Const,Your Rating,Date Rated,Title,URL,Title Type,IMDb Rating,Runtime (mins),Year,Genres,Num Votes,Release Date,Directors
tt15239678,9,2024-03-10,Dune: Part Two,https://www.imdb.com/title/tt15239678/,movie,8.6,166,2024,"Action, Adventure, Sci-Fi",500000,2024-03-01,Denis Villeneuve
tt0903747,10,2023-11-05,Breaking Bad,https://www.imdb.com/title/tt0903747/,tvSeries,9.5,49,2008,"Crime, Drama, Thriller",2000000,2008-01-20,Vince Gilligan''';

      final bytes = utf8.encode(csv);
      final result = DataParserService.parseFile(bytes, 'ratings.csv');

      expect(result['entries'], isNotNull);
      final entries = result['entries'] as List<Map<String, dynamic>>;
      expect(entries.length, 2);

      final dune = entries[0];
      expect(dune['title'], 'Dune: Part Two');
      expect(dune['imdbId'], 'tt15239678');
      expect(dune['rating'], 9.0);
      expect(dune['type'], 'MOVIE');
      expect(dune['watchedAt'], contains('2024-03-10'));

      final bb = entries[1];
      expect(bb['title'], 'Breaking Bad');
      expect(bb['imdbId'], 'tt0903747');
      expect(bb['rating'], 10.0);
      expect(bb['type'], 'TV_SHOW');
      expect(bb['watchedAt'], contains('2023-11-05'));
    });

    test('Trakt CSV export: maps watched_at, plays (>1 -> isRewatch), and tmdb_id', () {
      const csv = '''title,year,type,tmdb_id,imdb_id,rating,watched_at,plays
Inception,2010,movie,27205,tt1375666,9,2023-08-20T21:00:00.000Z,2
Succession,2018,show,76331,tt7660850,10,2023-06-01T19:00:00.000Z,1''';

      final bytes = utf8.encode(csv);
      final result = DataParserService.parseFile(bytes, 'trakt_history.csv');

      expect(result['entries'], isNotNull);
      final entries = result['entries'] as List<Map<String, dynamic>>;
      expect(entries.length, 2);

      final inception = entries[0];
      expect(inception['title'], 'Inception');
      expect(inception['tmdbId'], 27205);
      expect(inception['imdbId'], 'tt1375666');
      expect(inception['rating'], 9.0);
      expect(inception['isRewatch'], true);
      expect(inception['type'], 'MOVIE');

      final succession = entries[1];
      expect(succession['title'], 'Succession');
      expect(succession['tmdbId'], 76331);
      expect(succession['imdbId'], 'tt7660850');
      expect(succession['rating'], 10.0);
      expect(succession['isRewatch'], false);
      expect(succession['type'], 'TV_SHOW');
    });

    test('IMDb Watchlist CSV: maps items to Watchlist instead of diary entries', () {
      const csv = '''Position,Const,Created,Modified,Description,Title,URL,Title Type,IMDb Rating,Runtime (mins),Year,Genres,Num Votes,Release Date,Directors
1,tt11198330,2024-01-01,2024-01-01,,House of the Dragon,https://www.imdb.com/title/tt11198330/,tvSeries,8.4,50,2022,"Action, Adventure, Drama",400000,2022-08-21,''';

      final bytes = utf8.encode(csv);
      final result = DataParserService.parseFile(bytes, 'watchlist.csv');

      expect(result['lists'], isNotNull);
      final lists = result['lists'] as List<dynamic>;
      expect(lists.length, 1);
      final list = lists[0] as Map<String, dynamic>;
      expect(list['title'], 'Watchlist');
      final items = list['items'] as List<dynamic>;
      expect(items.length, 1);
      expect(items[0]['imdbId'], 'tt11198330');
    });

    test('WatchersHive JSON Backup: parses entries and lists directly', () {
      const jsonContent = '''{
        "entries": [
          {
            "tmdbId": 550,
            "title": "Fight Club",
            "type": "MOVIE",
            "rating": 9,
            "watchedAt": "2024-01-01T12:00:00.000Z"
          }
        ],
        "lists": [
          {
            "title": "Favorites",
            "items": [{"tmdbId": 550, "type": "MOVIE"}]
          }
        ]
      }''';

      final bytes = utf8.encode(jsonContent);
      final result = DataParserService.parseFile(bytes, 'watchhive_backup.json');

      expect(result['entries'], isNotNull);
      final entries = result['entries'] as List<dynamic>;
      expect(entries.length, 1);
      expect(entries[0]['title'], 'Fight Club');
      expect(entries[0]['tmdbId'], 550);

      expect(result['lists'], isNotNull);
      final lists = result['lists'] as List<dynamic>;
      expect(lists.length, 1);
      expect(lists[0]['title'], 'Favorites');
    });

    test('Trakt nested JSON export: extracts nested IDs, title, year, and listed_at', () {
      const jsonContent = '''[
        {
          "type": "movie",
          "movie": {
            "ids": {
              "imdb": "tt40210362",
              "plex": {"guid": "69a1880ce6ce67b5f905a45d", "slug": "the-last-temptation-of-becky-2026"},
              "slug": "the-last-temptation-of-becky-2026",
              "tmdb": 1642568,
              "trakt": 1357606
            },
            "year": 2026,
            "title": "The Last Temptation of Becky"
          },
          "rank": 1,
          "id": 1559018996,
          "listed_at": "2026-11-05T08:05:47.000Z",
          "notes": null,
          "my_rating": null
        }
      ]''';

      final bytes = utf8.encode(jsonContent);
      final result = DataParserService.parseFile(bytes, 'trakt_list.json');

      expect(result['entries'], isNotNull);
      final entries = result['entries'] as List<dynamic>;
      expect(entries.length, 1);
      final item = entries[0] as Map<String, dynamic>;
      expect(item['title'], 'The Last Temptation of Becky');
      expect(item['year'], 2026);
      expect(item['type'], 'MOVIE');
      expect(item['tmdbId'], 1642568);
      expect(item['imdbId'], 'tt40210362');
      expect(item['watchedAt'], '2026-11-05T08:05:47.000Z');
    });
  });
}
