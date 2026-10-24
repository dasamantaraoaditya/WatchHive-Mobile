import 'package:flutter_test/flutter_test.dart';
import 'package:watchhive_mobile/features/scanner/services/qr_payload_parser.dart';

void main() {
  group('QrPayloadParser Tests', () {
    test('Parses standard watchershive user profile web URL', () {
      const url = 'https://watchershive.com/watch-hive/profile/a77dc349-60da-455d-b24e-9d031faed57a';
      final result = QrPayloadParser.parse(url);

      expect(result, isA<UserQrResult>());
      final userResult = result as UserQrResult;
      expect(userResult.userId, 'a77dc349-60da-455d-b24e-9d031faed57a');
    });

    test('Parses web URL with www and query parameter', () {
      const url = 'https://www.watchershive.com/watch-hive/profile/test-user-123?ref=friend';
      final result = QrPayloadParser.parse(url);

      expect(result, isA<UserQrResult>());
      expect((result as UserQrResult).userId, 'test-user-123');
    });

    test('Parses deep link user profile', () {
      const url = 'watchershive://user/usr-456';
      final result = QrPayloadParser.parse(url);

      expect(result, isA<UserQrResult>());
      expect((result as UserQrResult).userId, 'usr-456');
    });

    test('Parses raw UUID as user result', () {
      const uuid = '6b673119-e74d-4dd7-921f-7d3f8daae63f';
      final result = QrPayloadParser.parse(uuid);

      expect(result, isA<UserQrResult>());
      expect((result as UserQrResult).userId, uuid);
    });

    test('Parses JSON payload for user', () {
      const json = '{"type":"user","id":"usr-789","username":"cinephile","displayName":"Movie Fan"}';
      final result = QrPayloadParser.parse(json);

      expect(result, isA<UserQrResult>());
      final userResult = result as UserQrResult;
      expect(userResult.userId, 'usr-789');
      expect(userResult.username, 'cinephile');
      expect(userResult.displayName, 'Movie Fan');
    });

    test('Parses movie details web URL with /details/movie/:id', () {
      const url = 'https://watchershive.com/watch-hive/details/movie/550';
      final result = QrPayloadParser.parse(url);

      expect(result, isA<MovieQrResult>());
      final movieResult = result as MovieQrResult;
      expect(movieResult.tmdbId, 550);
      expect(movieResult.mediaType, 'movie');
    });

    test('Parses TV details web URL with /details/tv/:id', () {
      const url = 'https://watchershive.com/watch-hive/details/tv/1399';
      final result = QrPayloadParser.parse(url);

      expect(result, isA<MovieQrResult>());
      final movieResult = result as MovieQrResult;
      expect(movieResult.tmdbId, 1399);
      expect(movieResult.mediaType, 'tv');
    });

    test('Parses short movie web URL /movie/:id', () {
      const url = 'https://watchershive.com/watch-hive/movie/693134';
      final result = QrPayloadParser.parse(url);

      expect(result, isA<MovieQrResult>());
      final movieResult = result as MovieQrResult;
      expect(movieResult.tmdbId, 693134);
      expect(movieResult.mediaType, 'movie');
    });

    test('Parses deep link movie details', () {
      const url = 'watchershive://movie/872585';
      final result = QrPayloadParser.parse(url);

      expect(result, isA<MovieQrResult>());
      final movieResult = result as MovieQrResult;
      expect(movieResult.tmdbId, 872585);
      expect(movieResult.mediaType, 'movie');
    });

    test('Parses JSON payload for movie', () {
      const json = '{"type":"movie","id":550,"title":"Fight Club","mediaType":"movie"}';
      final result = QrPayloadParser.parse(json);

      expect(result, isA<MovieQrResult>());
      final movieResult = result as MovieQrResult;
      expect(movieResult.tmdbId, 550);
      expect(movieResult.mediaType, 'movie');
      expect(movieResult.title, 'Fight Club');
    });

    test('Returns UnknownQrResult for unrecognized payloads', () {
      const randomText = 'Some random text without id or url';
      final result = QrPayloadParser.parse(randomText);

      expect(result, isA<UnknownQrResult>());
      expect((result as UnknownQrResult).rawData, randomText);
    });

    test('Handles null or empty string safely', () {
      expect(QrPayloadParser.parse(null), isA<UnknownQrResult>());
      expect(QrPayloadParser.parse('   '), isA<UnknownQrResult>());
    });
  });
}
