import 'dart:math';
import '../../../shared/models/models.dart';
import '../../../shared/models/user.dart';

/// Smart Search Engine providing fuzzy matching, typo tolerance,
/// intelligent query correction, and relevance ranking for movies, TV shows, and users.
class SmartSearchEngine {
  SmartSearchEngine._();

  static final SmartSearchEngine instance = SmartSearchEngine._();

  // Dynamic runtime title cache learned from discovery, trending, and user history
  final Set<String> _dynamicTitles = {};

  /// Pre-seeded dictionary of globally iconic and searched movies, TV shows, anime, and franchises.
  static const Set<String> _seedTitles = {
    // Top Movies & Classics
    'Oppenheimer',
    'Interstellar',
    'Inception',
    'The Dark Knight',
    'The Dark Knight Rises',
    'Batman Begins',
    'The Matrix',
    'The Matrix Reloaded',
    'Pulp Fiction',
    'Fight Club',
    'The Shawshank Redemption',
    'Gladiator',
    'Gladiator II',
    'Shutter Island',
    'The Godfather',
    'The Godfather Part II',
    'Forrest Gump',
    'Goodfellas',
    'The Departed',
    'Django Unchained',
    'Inglourious Basterds',
    'The Prestige',
    'Memento',
    'Parasite',
    'Whiplash',
    'La La Land',
    'Blade Runner 2049',
    'Blade Runner',
    'Dune',
    'Dune: Part Two',
    'Titanic',
    'Avatar',
    'Avatar: The Way of Water',
    'Top Gun',
    'Top Gun: Maverick',
    'Barbie',
    'Everything Everywhere All at Once',
    'Spider-Man',
    'Spider-Man: No Way Home',
    'Spider-Man: Across the Spider-Verse',
    'Spider-Man: Into the Spider-Verse',
    'Avengers',
    'The Avengers',
    'Avengers: Infinity War',
    'Avengers: Endgame',
    'Iron Man',
    'Captain America: Civil War',
    'Thor: Ragnarok',
    'Guardians of the Galaxy',
    'Black Panther',
    'Deadpool',
    'Deadpool & Wolverine',
    'The Batman',
    'Joker',
    'Joker: Folie à Deux',
    'Star Wars: A New Hope',
    'Star Wars: The Empire Strikes Back',
    'Star Wars: Return of the Jedi',
    'Harry Potter and the Sorcerer\'s Stone',
    'Harry Potter and the Prisoner of Azkaban',
    'Harry Potter and the Goblet of Fire',
    'Harry Potter and the Deathly Hallows',
    'The Lord of the Rings: The Fellowship of the Ring',
    'The Lord of the Rings: The Two Towers',
    'The Lord of the Rings: The Return of the King',
    'The Silence of the Lambs',
    'Se7en',
    'The Green Mile',
    'Saving Private Ryan',
    'Schindler\'s List',
    'Spirited Away',
    'Your Name',
    'Princess Mononoke',
    'Howl\'s Moving Castle',
    'Suzume',
    'Weathering with You',
    'Alien',
    'Aliens',
    'Alien: Romulus',
    'Predator',
    'Mad Max: Fury Road',
    'Furiosa: A Mad Max Saga',
    'John Wick',
    'John Wick: Chapter 4',
    'Mission: Impossible',
    'Mission: Impossible - Fallout',
    'Fast & Furious',
    'Jurassic Park',
    'Jurassic World',
    'The Lion King',
    'Inside Out',
    'Inside Out 2',
    'Coco',
    'WALL-E',
    'Up',
    'Ratatouille',
    'Toy Story',

    // Top TV Shows & Series
    'Breaking Bad',
    'Better Call Saul',
    'Game of Thrones',
    'House of the Dragon',
    'Stranger Things',
    'The Last of Us',
    'Succession',
    'Severance',
    'Arcane',
    'Squid Game',
    'Peaky Blinders',
    'Chernobyl',
    'The Boys',
    'Ted Lasso',
    'The Bear',
    'Shogun',
    'The Office',
    'Friends',
    'Black Mirror',
    'Yellowstone',
    'True Detective',
    'Fargo',
    'Westworld',
    'The Sopranos',
    'The Wire',
    'Mindhunter',
    'Dark',
    'Fleabag',
    'Sherlock',
    'The Mandalorian',
    'Andor',
    'Loki',
    'Fallout',
    'Invincible',
    'Dexter',
    'Narcos',
    'Prison Break',
    'Lost',
    'Silo',
    'White Lotus',
    'The White Lotus',
    'Euphoria',
    'Beef',
    'Bluey',

    // Anime Series
    'Attack on Titan',
    'Demon Slayer: Kimetsu no Yaiba',
    'Jujutsu Kaisen',
    'Death Note',
    'One Piece',
    'Naruto',
    'Naruto Shippuden',
    'Bleach',
    'Chainsaw Man',
    'Solo Leveling',
    'Fullmetal Alchemist: Brotherhood',
    'Hunter x Hunter',
    'Monster',
    'Steins;Gate',
    'Cowboy Bebop',
    'Neon Genesis Evangelion',
    'Vinland Saga',
    'Mob Psycho 100',
    'Spy x Family',
    'Frieren: Beyond Journey\'s End',
    'Cyberpunk: Edgerunners',
    'My Hero Academia',
  };

  /// Registers titles dynamically into the smart dictionary (e.g. from trending or user history).
  void registerTitles(Iterable<String> titles) {
    for (final title in titles) {
      final clean = title.trim();
      if (clean.length >= 2) {
        _dynamicTitles.add(clean);
      }
    }
  }

  /// Calculates Damerau-Levenshtein distance between two strings,
  /// accounting for insertions, deletions, substitutions, and transpositions.
  static int damerauLevenshtein(String a, String b) {
    final s1 = a.toLowerCase();
    final s2 = b.toLowerCase();
    final len1 = s1.length;
    final len2 = s2.length;

    if (s1 == s2) return 0;
    if (len1 == 0) return len2;
    if (len2 == 0) return len1;

    final matrix = List.generate(len1 + 1, (_) => List.filled(len2 + 1, 0));

    for (int i = 0; i <= len1; i++) {
      matrix[i][0] = i;
    }
    for (int j = 0; j <= len2; j++) {
      matrix[0][j] = j;
    }

    for (int i = 1; i <= len1; i++) {
      for (int j = 1; j <= len2; j++) {
        final cost = s1[i - 1] == s2[j - 1] ? 0 : 1;

        matrix[i][j] = min(
          matrix[i - 1][j] + 1, // deletion
          min(
            matrix[i][j - 1] + 1, // insertion
            matrix[i - 1][j - 1] + cost, // substitution
          ),
        );

        // Transposition check (e.g. "ei" <-> "ie")
        if (i > 1 &&
            j > 1 &&
            s1[i - 1] == s2[j - 2] &&
            s1[i - 2] == s2[j - 1]) {
          matrix[i][j] = min(matrix[i][j], matrix[i - 2][j - 2] + 1);
        }
      }
    }

    return matrix[len1][len2];
  }

  /// Returns similarity score between 0.0 and 1.0 (1.0 = exact match).
  static double similarity(String s1, String s2) {
    final clean1 = s1.trim().toLowerCase();
    final clean2 = s2.trim().toLowerCase();
    if (clean1 == clean2) return 1.0;
    final maxLen = max(clean1.length, clean2.length);
    if (maxLen == 0) return 1.0;
    final dist = damerauLevenshtein(clean1, clean2);
    return (1.0 - (dist / maxLen)).clamp(0.0, 1.0);
  }

  /// Checks if words in query are close to any words in target.
  static double tokenSimilarity(String query, String target) {
    final qTokens = query
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();
    final tTokens = target
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();

    if (qTokens.isEmpty || tTokens.isEmpty) return 0.0;

    double matchedScore = 0.0;
    for (final q in qTokens) {
      double bestWordMatch = 0.0;
      for (final t in tTokens) {
        if (t == q) {
          bestWordMatch = 1.0;
          break;
        }
        if (t.contains(q) || q.contains(t)) {
          bestWordMatch = max(bestWordMatch, 0.85);
        } else {
          final sim = similarity(q, t);
          if (sim > bestWordMatch) bestWordMatch = sim;
        }
      }
      matchedScore += bestWordMatch;
    }

    return matchedScore / qTokens.length;
  }

  /// Collapses 3 or more repeated characters down to 1 or 2 (e.g. "oppennnheimer" -> "oppenheimer").
  static String collapseRepeatedCharacters(String input) {
    return input.replaceAllMapped(
      RegExp(r'(.)\1{2,}'),
      (match) => match.group(1)!,
    );
  }

  /// Finds the best matching title from the dictionary if similarity is high enough to be a typo.
  String? findBestCorrection(String rawQuery) {
    final query = rawQuery.trim().toLowerCase();
    if (query.length < 3) return null;

    String? bestTitle;
    double highestScore = 0.0;

    final allTitles = <String>{..._seedTitles, ..._dynamicTitles};

    for (final candidate in allTitles) {
      final candLower = candidate.toLowerCase();

      // Fast exact match (no correction needed)
      if (candLower == query) return null;

      final dist = damerauLevenshtein(query, candLower);
      final maxLen = max(query.length, candLower.length);
      final score = 1.0 - (dist / maxLen);

      // Check token match for multi-word titles
      final tokenScore = tokenSimilarity(query, candLower);
      final combinedScore = max(score, tokenScore * 0.95);

      // Typo thresholds:
      // - If dist <= 2 and word length >= 5, it's very likely a typo
      // - If similarity >= 0.75, it's a strong match
      final isHighConfidence =
          (dist <= 2 && query.length >= 5) || combinedScore >= 0.75;

      if (isHighConfidence && combinedScore > highestScore) {
        highestScore = combinedScore;
        bestTitle = candidate;
      }
    }

    return bestTitle;
  }

  /// Generates intelligent candidate query variations to retry when direct search returns no results.
  List<String> generateQueryCandidates(String rawQuery) {
    final candidates = <String>[];
    final trimmed = rawQuery.trim();
    if (trimmed.isEmpty) return candidates;

    // 1. Check for dictionary-based typo correction
    final bestCorrection = findBestCorrection(trimmed);
    if (bestCorrection != null &&
        bestCorrection.toLowerCase() != trimmed.toLowerCase()) {
      candidates.add(bestCorrection);
    }

    // 2. Collapsed repeated characters (e.g. "gladiatorr" -> "gladiator", "avvengers" -> "avengers")
    final collapsed = collapseRepeatedCharacters(trimmed);
    if (collapsed != trimmed && !candidates.contains(collapsed)) {
      candidates.add(collapsed);
      final collapsedCorrection = findBestCorrection(collapsed);
      if (collapsedCorrection != null &&
          !candidates.contains(collapsedCorrection)) {
        candidates.add(collapsedCorrection);
      }
    }

    // 3. Known phrase boundary joins/splits
    final lower = trimmed.toLowerCase();
    final Map<String, String> commonReplacements = {
      'spiderman': 'Spider-Man',
      'spider man': 'Spider-Man',
      'spider-man': 'Spider-Man',
      'ironman': 'Iron Man',
      'iron man': 'Iron Man',
      'starwars': 'Star Wars',
      'star wars': 'Star Wars',
      'topgun': 'Top Gun',
      'top gun': 'Top Gun',
      'batman': 'Batman',
      'godfather': 'The Godfather',
      'god father': 'The Godfather',
      'deadpool': 'Deadpool',
      'xmen': 'X-Men',
      'x men': 'X-Men',
      'dune 2': 'Dune: Part Two',
      'dune part 2': 'Dune: Part Two',
      'stranger thing': 'Stranger Things',
      'squid games': 'Squid Game',
      'peaky blinder': 'Peaky Blinders',
      'the boys': 'The Boys',
      'last of us': 'The Last of Us',
      'fast and furious': 'Fast & Furious',
      'breaking bad': 'Breaking Bad',
      'better call saul': 'Better Call Saul',
    };

    if (commonReplacements.containsKey(lower)) {
      final rep = commonReplacements[lower]!;
      if (!candidates.contains(rep)) candidates.add(rep);
    }

    // 4. Singular / Plural toggles
    if (lower.endsWith('s') && lower.length > 3) {
      final singular = trimmed.substring(0, trimmed.length - 1);
      if (!candidates.contains(singular)) candidates.add(singular);
    } else if (!lower.endsWith('s')) {
      final plural = '${trimmed}s';
      if (!candidates.contains(plural)) candidates.add(plural);
    }

    // 5. Clean punctuation (remove colons, dashes, apostrophes)
    final cleanPunct = trimmed
        .replaceAll(RegExp(r"[':\-_.,!?]"), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (cleanPunct != trimmed && !candidates.contains(cleanPunct)) {
      candidates.add(cleanPunct);
    }

    // 6. Number to words / words to number (e.g. "part 2" <-> "part two")
    if (lower.contains('part 2') || lower.contains('part ii')) {
      final partTwo = trimmed.replaceAll(
          RegExp(r'part\s+(2|ii)', caseSensitive: false), 'Part Two');
      if (!candidates.contains(partTwo)) candidates.add(partTwo);
    } else if (lower.contains('part two')) {
      final part2 = trimmed.replaceAll(
          RegExp(r'part\s+two', caseSensitive: false), 'Part 2');
      if (!candidates.contains(part2)) candidates.add(part2);
    }

    // 7. Extract significant multi-word root if query has >= 3 words
    final words = cleanPunct.split(' ');
    if (words.length >= 3) {
      final prefix = words.take(2).join(' ');
      if (!candidates.contains(prefix)) candidates.add(prefix);
    }

    return candidates;
  }

  /// Ranks search results by relevance to the query, scoring exact matches, prefix matches,
  /// fuzzy similarity, and rating quality.
  List<MediaResult> rankMediaResults(String query, List<MediaResult> results) {
    if (results.isEmpty) return results;

    final q = query.trim().toLowerCase();
    final scored = <({MediaResult item, double score})>[];

    for (final item in results) {
      final title = item.title.trim().toLowerCase();
      double score = 0.0;

      // 1. Exact match
      if (title == q) {
        score += 100.0;
      }
      // 2. Starts with query
      else if (title.startsWith(q)) {
        score += 75.0;
      }
      // 3. Substring match
      else if (title.contains(q)) {
        score += 55.0;
      }

      // 4. Fuzzy Damerau-Levenshtein similarity
      final sim = similarity(q, title);
      score += sim * 40.0;

      // 5. Token overlap similarity
      final tSim = tokenSimilarity(q, title);
      score += tSim * 30.0;

      // 6. Popularity / Quality tie-breaker
      if (item.voteAverage != null && item.voteAverage! > 0) {
        score += (item.voteAverage! / 10.0) * 8.0;
      }

      // 7. Has poster bonus
      if (item.posterPath != null && item.posterPath!.isNotEmpty) {
        score += 5.0;
      }

      scored.add((item: item, score: score));
    }

    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.map((e) => e.item).toList();
  }

  /// Fuzzy matches and ranks a pool of users against a query when backend search returns 0.
  List<User> fuzzySearchUsers(String query, List<User> userPool) {
    final q = query.trim().toLowerCase().replaceAll('@', '');
    if (q.isEmpty || userPool.isEmpty) return [];

    final scored = <({User user, double score})>[];

    for (final u in userPool) {
      final username = u.username.toLowerCase();
      final displayName = (u.displayName ?? '').toLowerCase();

      double score = 0.0;

      // Exact matches
      if (username == q || displayName == q) {
        score += 100.0;
      } else if (username.startsWith(q) || displayName.startsWith(q)) {
        score += 70.0;
      } else if (username.contains(q) || displayName.contains(q)) {
        score += 50.0;
      }

      // Check individual words / tokens in username and displayName
      final userTokens = [
        ...username.split(RegExp(r'[_.\-]')),
        ...displayName.split(RegExp(r'\s+')),
      ].where((t) => t.isNotEmpty);

      for (final t in userTokens) {
        if (t == q) {
          score = max(score, 90.0);
        } else if (t.startsWith(q)) {
          score = max(score, 65.0);
        } else {
          final tSim = similarity(q, t);
          final tDist = damerauLevenshtein(q, t);
          if (tSim >= 0.75 || (tDist <= 1 && q.length >= 4)) {
            score = max(score, tSim * 50.0);
          }
        }
      }

      if (score > 0.0) {
        scored.add((user: u, score: score));
      }
    }

    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.map((e) => e.user).toList();
  }
}
