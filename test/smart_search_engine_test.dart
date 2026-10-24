import 'package:flutter_test/flutter_test.dart';
import 'package:watchhive_mobile/features/search/services/smart_search_engine.dart';
import 'package:watchhive_mobile/shared/models/models.dart';
import 'package:watchhive_mobile/shared/models/user.dart';

void main() {
  group('SmartSearchEngine Tests', () {
    test('Damerau-Levenshtein correctly handles transpositions and typos', () {
      // Adjacent transposition: "ei" <-> "ie"
      expect(SmartSearchEngine.damerauLevenshtein('oppenhiemer', 'oppenheimer'),
          1);
      // Single character deletion
      expect(
          SmartSearchEngine.damerauLevenshtein('interstelar', 'interstellar'),
          1);
      // Single character substitution
      expect(SmartSearchEngine.damerauLevenshtein('avangers', 'avengers'), 1);
      // Single character insertion
      expect(
          SmartSearchEngine.damerauLevenshtein('gladiatorr', 'gladiator'), 1);
    });

    test('similarity computes accurate normalized scores', () {
      expect(SmartSearchEngine.similarity('Oppenheimer', 'oppenheimer'), 1.0);
      expect(SmartSearchEngine.similarity('interstelar', 'interstellar'),
          greaterThan(0.90));
      expect(SmartSearchEngine.similarity('breakng bad', 'breaking bad'),
          greaterThan(0.90));
      expect(SmartSearchEngine.similarity('apple', 'banana'), lessThan(0.3));
    });

    test('collapseRepeatedCharacters condenses spammy letters', () {
      expect(SmartSearchEngine.collapseRepeatedCharacters('oppennnheimer'),
          'oppenheimer');
      expect(SmartSearchEngine.collapseRepeatedCharacters('avvvvengers'),
          'avengers');
      expect(SmartSearchEngine.collapseRepeatedCharacters('gladiatorrr'),
          'gladiator');
    });

    test(
        'findBestCorrection identifies common misspellings from seed dictionary',
        () {
      final engine = SmartSearchEngine.instance;

      expect(engine.findBestCorrection('interstelar'), 'Interstellar');
      expect(engine.findBestCorrection('oppenhiemer'), 'Oppenheimer');
      expect(engine.findBestCorrection('avangers'), 'Avengers');
      expect(engine.findBestCorrection('breakng bad'), 'Breaking Bad');
      expect(engine.findBestCorrection('shutter islan'), 'Shutter Island');
      expect(engine.findBestCorrection('gladiatorr'), 'Gladiator');
      expect(engine.findBestCorrection('stranger thing'), 'Stranger Things');
    });

    test('generateQueryCandidates produces ordered, sensible recovery queries',
        () {
      final engine = SmartSearchEngine.instance;

      final candidates = engine.generateQueryCandidates('interstelar');
      expect(candidates, contains('Interstellar'));

      final spiderManCandidates = engine.generateQueryCandidates('spiderman');
      expect(spiderManCandidates, contains('Spider-Man'));

      final duneCandidates = engine.generateQueryCandidates('dune 2');
      expect(duneCandidates, contains('Dune: Part Two'));

      final blinderCandidates = engine.generateQueryCandidates('peaky blinder');
      expect(blinderCandidates, contains('Peaky Blinders'));
    });

    test('rankMediaResults puts closest and highest quality match on top', () {
      final engine = SmartSearchEngine.instance;

      final results = [
        const MediaResult(
            id: 1,
            title: 'Random Documentary',
            mediaType: 'movie',
            voteAverage: 4.0),
        const MediaResult(
            id: 2, title: 'Interstellar', mediaType: 'movie', voteAverage: 8.7),
        const MediaResult(
            id: 3,
            title: 'The Making of Interstellar',
            mediaType: 'movie',
            voteAverage: 6.5),
      ];

      final ranked = engine.rankMediaResults('interstelar', results);
      expect(ranked.first.title, 'Interstellar');
    });

    test('dynamic title registration expands smart dictionary at runtime', () {
      final engine = SmartSearchEngine.instance;

      // Register a custom new movie title
      engine.registerTitles(['Kalki 2898 AD', 'Challengers']);

      expect(engine.findBestCorrection('kalki 2898'), 'Kalki 2898 AD');
      expect(engine.findBestCorrection('chalengers'), 'Challengers');
    });

    test('fuzzySearchUsers matches usernames with typos or missing @ symbol',
        () {
      final engine = SmartSearchEngine.instance;

      final users = [
        User(
          id: '1',
          username: 'jonathan_nolan',
          displayName: 'Jonathan Nolan',
          createdAt: DateTime.now(),
        ),
        User(
          id: '2',
          username: 'christopher_nolan',
          displayName: 'Christopher Nolan',
          createdAt: DateTime.now(),
        ),
      ];

      // Typo in username query: "johnathan"
      final matches = engine.fuzzySearchUsers('johnathan', users);
      expect(matches, isNotEmpty);
      expect(matches.first.username, 'jonathan_nolan');

      // Query with @ symbol
      final matchesWithAt = engine.fuzzySearchUsers('@christopher', users);
      expect(matchesWithAt, isNotEmpty);
      expect(matchesWithAt.first.username, 'christopher_nolan');
    });
  });
}
