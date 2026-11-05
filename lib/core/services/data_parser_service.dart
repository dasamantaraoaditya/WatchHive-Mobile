import 'dart:convert';

/// Universal parser for importing watch history from Letterboxd, IMDb, Trakt,
/// Notion, and WatchersHive native exports (CSV or JSON).
class DataParserService {
  static const String aiImportPrompt = '''Convert my movie/TV watch history notes into a valid WatchHive import JSON object.

Output MUST strictly follow this JSON format:
{
  "entries": [
    {
      "title": "Exact Title of the movie or show (Required)",
      "year": 2024,
      "type": "MOVIE" or "TV_SHOW",
      "watchedAt": "YYYY-MM-DDTHH:mm:ssZ (Watch date is optional. If date is present but exact time is unknown, use 12:00:00Z)",
      "rating": 8.5,
      "review": "Your review or reaction notes",
      "tags": ["sci-fi", "cinema", "action"],
      "isRewatch": false,
      "watchLocation": "Cinema / Home / Netflix"
    }
  ]
}

Key Rules:
1. "title" is mandatory for TMDb auto-matching.
2. "watchedAt" is optional: format as ISO 8601 (e.g. "2024-05-12T20:30:00Z"). If time is omitted in my notes, default to 12:00:00Z. DO NOT invent dates if missing.
3. "rating" must be a number on a 0.0 to 10.0 scale (convert 5-star ratings by multiplying by 2).
4. Output ONLY valid JSON without Markdown backticks or commentary so I can save directly to a .json file.

Here is my watch history:
[PASTE YOUR NOTES OR LIST HERE]''';

  /// Recursively find entry list anywhere in arbitrary JSON
  static List<dynamic> findEntryListInJson(dynamic data) {
    if (data is List) return data;
    if (data is! Map) return [];

    final map = data as Map<String, dynamic>;

    // Priority keys for watch entry arrays
    const priorityKeys = [
      'entries', 'movies', 'items', 'history', 'watches',
      'watchlist', 'results', 'data', 'diary', 'films'
    ];

    for (final k in priorityKeys) {
      if (map[k] is List) return map[k] as List;
    }

    // Secondary search for any nested list of maps
    for (final v in map.values) {
      if (v is List && v.isNotEmpty && v.first is Map) {
        return v;
      }
      if (v is Map<String, dynamic>) {
        final nested = findEntryListInJson(v);
        if (nested.isNotEmpty) return nested;
      }
    }

    return [];
  }

  /// Parses raw file bytes (CSV or JSON) into { "entries": [...], "lists": [...] }
  static Map<String, dynamic> parseFile(List<int> bytes, String fileName) {
    if (bytes.isEmpty) {
      throw Exception('The selected file is empty.');
    }

    final isCsv = fileName.toLowerCase().endsWith('.csv');
    final content = utf8.decode(bytes);

    if (!isCsv) {
      // Try JSON first
      try {
        final decoded = jsonDecode(content);
        final foundEntries = findEntryListInJson(decoded);
        final lists = (decoded is Map<String, dynamic> && decoded['lists'] is List)
            ? decoded['lists'] as List
            : null;

        if (foundEntries.isNotEmpty || (lists != null && lists.isNotEmpty)) {
          final entries = _normalizeJsonEntries(foundEntries);
          if (entries.isNotEmpty || (lists != null && lists.isNotEmpty)) {
            return {
              if (entries.isNotEmpty) 'entries': entries,
              if (lists != null) 'lists': lists,
            };
          }
        }
      } catch (_) {
        // Fallback to CSV if JSON decoding fails
      }
    }

    // Parse as CSV
    return parseCsvContent(content);
  }

  /// Parses CSV string into { "entries": [...], "lists": [...] }
  static Map<String, dynamic> parseCsvContent(String input) {
    // Check if it's WatchersHive native CSV with section headers
    if (input.contains('# WATCH ENTRIES') || input.contains('# WATCH LISTS')) {
      return _parseWatchHiveNativeCsv(input);
    }

    final rows = parseCsvRows(input);
    if (rows.length < 2) {
      throw Exception('CSV file contains no data rows.');
    }

    final rawHeaders = rows[0];

    // Detect platforms
    final isLetterboxd = rawHeaders.any((h) => RegExp(r'letterboxd', caseSensitive: false).hasMatch(h));
    final isImdb = rawHeaders.any((h) => RegExp(r'const', caseSensitive: false).hasMatch(h)) ||
        rawHeaders.any((h) => RegExp(r'imdbrating', caseSensitive: false).hasMatch(h));
    final isWatchlistExport = rawHeaders.any((h) => RegExp(r'^position$', caseSensitive: false).hasMatch(h.trim())) && isImdb;

    // Header index mappings
    final titleIdx = rawHeaders.indexWhere(isTitleHeader);

    // Prefer explicit viewing/watch date over generic creation/log date (crucial for Letterboxd)
    int watchDateIdx = rawHeaders.indexWhere((h) {
      final s = h.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      return RegExp(r'(?:watch(?:ed)?(?:date|at)|datewatched|viewed(?:date|at)|seen(?:date|at))', caseSensitive: false).hasMatch(s);
    });
    if (watchDateIdx == -1) {
      watchDateIdx = rawHeaders.indexWhere(isWatchDateHeader);
    }

    final watchTimeIdx = rawHeaders.indexWhere(isWatchTimeHeader);
    final releaseYearIdx = rawHeaders.indexWhere(isReleaseYearHeader);
    final ratingIdx = rawHeaders.indexWhere(isRatingHeader);
    final typeIdx = rawHeaders.indexWhere(isTypeHeader);
    final statusIdx = rawHeaders.indexWhere(isStatusHeader);
    final reviewIdx = rawHeaders.indexWhere(isReviewHeader);
    final tagsIdx = rawHeaders.indexWhere(isTagsHeader);
    final rewatchIdx = rawHeaders.indexWhere(isRewatchHeader);
    final locationIdx = rawHeaders.indexWhere(isLocationHeader);
    final tmdbIdx = rawHeaders.indexWhere(isTmdbHeader);
    final imdbIdx = rawHeaders.indexWhere(isImdbHeader);
    final urlIdx = rawHeaders.indexWhere(isUrlHeader);

    if (titleIdx == -1) {
      throw Exception('Could not find a Title or Name column in the CSV file. Please make sure the header row contains "Name", "Title", or "Movie".');
    }

    final entries = <Map<String, dynamic>>[];
    final watchlistItems = <Map<String, dynamic>>[];

    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (titleIdx >= row.length) continue;
      final title = row[titleIdx].trim();
      if (title.isEmpty) continue;

      int? tmdbId;
      String? imdbId;
      String? detectedType;

      if (tmdbIdx != -1 && tmdbIdx < row.length && row[tmdbIdx].isNotEmpty) {
        final parsed = parseLinksAndIds(row[tmdbIdx]);
        if (parsed['tmdbId'] != null) tmdbId = parsed['tmdbId'] as int;
      }

      if (imdbIdx != -1 && imdbIdx < row.length && row[imdbIdx].isNotEmpty) {
        final parsed = parseLinksAndIds(row[imdbIdx]);
        if (parsed['imdbId'] != null) imdbId = parsed['imdbId'] as String;
      }

      // Check any cell for IMDb ID (e.g. IMDb Const column)
      if (imdbId == null) {
        for (final cell in row) {
          final trimmed = cell.trim();
          if (RegExp(r'^tt\d{7,10}$', caseSensitive: false).hasMatch(trimmed)) {
            imdbId = trimmed;
            break;
          }
        }
      }

      if (urlIdx != -1 && urlIdx < row.length && row[urlIdx].isNotEmpty) {
        final parsed = parseLinksAndIds(row[urlIdx]);
        if (parsed['tmdbId'] != null && tmdbId == null) tmdbId = parsed['tmdbId'] as int;
        if (parsed['imdbId'] != null && imdbId == null) imdbId = parsed['imdbId'] as String;
        if (parsed['type'] != null) detectedType = parsed['type'] as String;
      }

      // Media Type
      final typeRaw = (typeIdx != -1 && typeIdx < row.length) ? row[typeIdx] : '';
      final type = detectedType ?? parseMediaType(typeRaw);

      // Rating (Letterboxd 5-star ratings automatically scaled 2x to 10-point scale)
      final ratingRaw = (ratingIdx != -1 && ratingIdx < row.length) ? row[ratingIdx] : '';
      final rating = ratingRaw.isNotEmpty ? parseRating(ratingRaw, isLetterboxd: isLetterboxd) : null;

      // Status
      final statusRaw = (statusIdx != -1 && statusIdx < row.length) ? row[statusIdx].toLowerCase() : '';
      final isWatching = statusRaw.contains('watching') || statusRaw.contains('in progress') || statusRaw.contains('current');
      final isWatchlist = isWatchlistExport ||
          statusRaw.contains('plan') ||
          statusRaw.contains('to watch') ||
          statusRaw.contains('want to watch') ||
          statusRaw.contains('watchlist') ||
          statusRaw.contains('queue') ||
          statusRaw.contains('backlog');

      // Watch date & time
      final dateRaw = (watchDateIdx != -1 && watchDateIdx < row.length) ? row[watchDateIdx] : '';
      final timeRaw = (watchTimeIdx != -1 && watchTimeIdx < row.length) ? row[watchTimeIdx] : '';
      final dateInfo = dateRaw.isNotEmpty ? parseDateString(dateRaw, timeRaw) : null;

      // Release year
      final releaseYearRaw = (releaseYearIdx != -1 && releaseYearIdx < row.length) ? row[releaseYearIdx].trim() : '';
      final match = RegExp(r'\b(19\d\d|20\d\d)\b').firstMatch(releaseYearRaw);
      final releaseYear = match?.group(1);

      // Review
      final review = (reviewIdx != -1 && reviewIdx < row.length && row[reviewIdx].trim().isNotEmpty) ? row[reviewIdx].trim() : null;

      // Tags
      List<String> tags = [];
      if (tagsIdx != -1 && tagsIdx < row.length && row[tagsIdx].trim().isNotEmpty) {
        tags = row[tagsIdx].split(RegExp(r'[,|;]')).map((t) => t.trim()).where((t) => t.isNotEmpty).toList();
      }

      // Rewatch
      bool isRewatch = false;
      if (rewatchIdx != -1 && rewatchIdx < row.length && row[rewatchIdx].isNotEmpty) {
        final rw = row[rewatchIdx].toLowerCase().trim();
        final isPlaysHeader = rawHeaders[rewatchIdx].toLowerCase().trim() == 'plays';
        final playCount = int.tryParse(rw);
        if (isPlaysHeader) {
          isRewatch = playCount != null && playCount > 1;
        } else {
          isRewatch = rw == 'yes' || rw == 'true' || rw == '1' || rw == 'checked' || (playCount != null && playCount > 1);
        }
      }

      // Location
      final watchLocation = (locationIdx != -1 && locationIdx < row.length && row[locationIdx].trim().isNotEmpty) ? row[locationIdx].trim() : null;

      final entry = <String, dynamic>{
        'title': title,
        'type': type,
        if (tmdbId != null) 'tmdbId': tmdbId,
        if (imdbId != null) 'imdbId': imdbId,
        if (rating != null) 'rating': rating,
        if (review != null) 'review': review,
        if (tags.isNotEmpty) 'tags': tags,
        'isRewatch': isRewatch,
        'isWatching': isWatching,
        if (watchLocation != null) 'watchLocation': watchLocation,
        if (releaseYear != null) 'year': int.tryParse(releaseYear) ?? releaseYear,
        if (dateInfo?['watchedAt'] != null) 'watchedAt': dateInfo!['watchedAt'],
        if (dateInfo?['startedAt'] != null) 'startedAt': dateInfo!['startedAt'],
        if (dateInfo?['completedAt'] != null) 'completedAt': dateInfo!['completedAt'],
        'inWatchlist': isWatchlist,
      };

      entries.add(entry);

      if (isWatchlist) {
        watchlistItems.add({
          'title': title,
          if (tmdbId != null) 'tmdbId': tmdbId,
          if (imdbId != null) 'imdbId': imdbId,
          'mediaType': type == 'TV_SHOW' ? 'tv' : 'movie',
        });
      }
    }

    final lists = <Map<String, dynamic>>[];
    if (watchlistItems.isNotEmpty) {
      lists.add({
        'title': 'Watchlist',
        'name': 'Watchlist',
        'type': 'WATCHLIST',
        'description': isImdb ? 'Imported from IMDb' : (isLetterboxd ? 'Imported from Letterboxd' : 'Imported Watchlist'),
        'items': watchlistItems,
      });
    }

    return {
      'entries': entries,
      if (lists.isNotEmpty) 'lists': lists,
    };
  }

  // ─── CSV ROWS PARSER (RFC 4180) ──────────────────────────────────────────

  static List<List<String>> parseCsvRows(String input) {
    final rows = <List<String>>[];
    final str = input.replaceAll('^\uFEFF', '');
    List<String> currentRow = [];
    final currentCell = StringBuffer();
    bool inQuotes = false;

    for (int i = 0; i < str.length; i++) {
      final char = str[i];
      final nextChar = (i + 1 < str.length) ? str[i + 1] : '';

      if (char == '"') {
        if (inQuotes && nextChar == '"') {
          currentCell.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (char == ',' && !inQuotes) {
        currentRow.add(currentCell.toString().trim());
        currentCell.clear();
      } else if ((char == '\r' || char == '\n') && !inQuotes) {
        if (char == '\r' && nextChar == '\n') {
          i++;
        }
        currentRow.add(currentCell.toString().trim());
        currentCell.clear();
        if (currentRow.any((c) => c.isNotEmpty)) {
          rows.add(currentRow);
        }
        currentRow = [];
      } else {
        currentCell.write(char);
      }
    }

    if (currentCell.isNotEmpty || currentRow.isNotEmpty) {
      currentRow.add(currentCell.toString().trim());
      if (currentRow.any((c) => c.isNotEmpty)) {
        rows.add(currentRow);
      }
    }

    return rows;
  }

  // ─── COLUMN CLASSIFIERS ──────────────────────────────────────────────────

  static bool isReleaseDateHeader(String raw) {
    final s = raw.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    return RegExp(r'^(?:release(?:date|year)?|yearofrelease|released(?:date|at)?|airdate|aired(?:date)?|firstair(?:date)?|premiere(?:date)?|publicationdate|published(?:date)?|reldate|relyear)$', caseSensitive: false).hasMatch(s) ||
        RegExp(r'(?:release|premiere|published|firstair|airdate)', caseSensitive: false).hasMatch(s);
  }

  static bool isWatchDateHeader(String raw) {
    if (isReleaseDateHeader(raw)) return false;
    final s = raw.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    if (RegExp(r'(?:watch(?:ed)?(?:date|at|time|year|day)?|date(?:watched|seen|logged|finished|completed|added|viewed|rated)|(?:logged|finished|completed|seen|viewed|rated)(?:date|at|time)?)', caseSensitive: false).hasMatch(s)) {
      return true;
    }
    return RegExp(r'^(?:date|watched|logged|viewed|finished|completed|timestamp)$', caseSensitive: false).hasMatch(s);
  }

  static bool isWatchTimeHeader(String raw) {
    final s = raw.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    return RegExp(r'^(?:watchtime|time|watchedtime|timewatched|hour|watchhour)$', caseSensitive: false).hasMatch(s);
  }

  static bool isTitleHeader(String raw) {
    final s = raw.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    if (RegExp(r'(?:user|director|actor|writer|author|creator|genre|list|id|url|link|poster|backdrop|status|rating|date|year)', caseSensitive: false).hasMatch(s)) {
      return false;
    }
    if (RegExp(r'^(?:title|name|movie|film|show|series|item|entry|moviename|filmtitle|movietitle|showname|seriestitle)$', caseSensitive: false).hasMatch(s)) {
      return true;
    }
    return RegExp(r'(?:^|[\s_-])(title|name|movie|film|show|series)(?:$|[\s_-])', caseSensitive: false).hasMatch(raw);
  }

  static bool isRatingHeader(String raw) {
    final s = raw.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    if (RegExp(r'^(?:imdbrating|tmdb(?:rating|vote)?|metacritic|rottentomatoes|community|average|avg|numvotes)$', caseSensitive: false).hasMatch(s)) {
      return false;
    }
    return RegExp(r'^(?:rating|score|myrating|myscore|personalrating|stars?|grade|rate|userrating|yourrating)$', caseSensitive: false).hasMatch(s) ||
        RegExp(r'(?:my_?rating|user_?rating|your_?rating|score|stars?)', caseSensitive: false).hasMatch(s);
  }

  static bool isReleaseYearHeader(String raw) {
    if (isWatchDateHeader(raw)) return false;
    final s = raw.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    return RegExp(r'^(?:releaseyear|yearofrelease|releasedate|relyear|release|year)$', caseSensitive: false).hasMatch(s);
  }

  static bool isTypeHeader(String raw) {
    final s = raw.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    return RegExp(r'^(?:type|mediatype|format|category|kind|titletype)$', caseSensitive: false).hasMatch(s);
  }

  static bool isStatusHeader(String raw) {
    final s = raw.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    return RegExp(r'^(?:status|state|watchstatus|progress|watchstate)$', caseSensitive: false).hasMatch(s);
  }

  static bool isReviewHeader(String raw) {
    final s = raw.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    return RegExp(r'^(?:review|notes?|comments?|thoughts?|critique|memo|description)$', caseSensitive: false).hasMatch(s);
  }

  static bool isTagsHeader(String raw) {
    final s = raw.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    return RegExp(r'^(?:tags?|genres?)$', caseSensitive: false).hasMatch(s);
  }

  static bool isRewatchHeader(String raw) {
    final s = raw.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    return RegExp(r'^(?:rewatch|isrewatch|rewatched|repeat|plays)$', caseSensitive: false).hasMatch(s);
  }

  static bool isLocationHeader(String raw) {
    final s = raw.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    return RegExp(r'^(?:location|watchlocation|platform|service|wheretowatch|streaming(?:service)?|cinema|theater)$', caseSensitive: false).hasMatch(s);
  }

  static bool isTmdbHeader(String raw) {
    final s = raw.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    return RegExp(r'^(?:tmdbid|tmdb|tmdblink|tmdburl)$', caseSensitive: false).hasMatch(s);
  }

  static bool isImdbHeader(String raw) {
    final s = raw.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    return RegExp(r'^(?:imdbid|imdb|imdblink|imdburl|const)$', caseSensitive: false).hasMatch(s);
  }

  static bool isUrlHeader(String raw) {
    final s = raw.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    return RegExp(r'^(?:url|link|website)$', caseSensitive: false).hasMatch(s);
  }

  // ─── PARSING HELPERS ─────────────────────────────────────────────────────

  static double? parseRating(String raw, {bool isLetterboxd = false}) {
    if (raw.trim().isEmpty) return null;
    final s = raw.trim();

    // Star emojis
    final starMatches = RegExp(r'[⭐⭐️★🌟]').allMatches(s).toList();
    if (starMatches.isNotEmpty) {
      final count = starMatches.length;
      if (count <= 5) return double.parse((count * 2.0).toStringAsFixed(1));
      return double.parse(count.clamp(0, 10).toStringAsFixed(1));
    }

    // Fraction e.g. "4/5", "8.5/10"
    final fracMatch = RegExp(r'^(\d+(?:\.\d+)?)\s*\/\s*(\d+(?:\.\d+)?)$').firstMatch(s);
    if (fracMatch != null) {
      final num = double.tryParse(fracMatch.group(1) ?? '');
      final denom = double.tryParse(fracMatch.group(2) ?? '');
      if (num != null && denom != null && denom > 0) {
        final normalized = (num / denom) * 10.0;
        return double.parse(normalized.clamp(0.0, 10.0).toStringAsFixed(1));
      }
    }

    // Direct number
    final num = double.tryParse(s);
    if (num != null) {
      final finalNum = (isLetterboxd && num <= 5.0) ? num * 2.0 : num;
      return double.parse(finalNum.clamp(0.0, 10.0).toStringAsFixed(1));
    }

    return null;
  }

  static String parseMediaType(String raw) {
    final s = raw.toLowerCase().trim();
    if (s.contains('tv') || s.contains('series') || s.contains('show') || s.contains('drama') || s.contains('anime') || s.contains('season')) {
      return 'TV_SHOW';
    }
    if (s.contains('episode')) {
      return 'EPISODE';
    }
    return 'MOVIE';
  }

  static Map<String, dynamic> parseLinksAndIds(String raw) {
    if (raw.trim().isEmpty) return {};
    final s = raw.trim();

    // Direct number
    if (RegExp(r'^\d+$').hasMatch(s)) {
      return {'tmdbId': int.tryParse(s)};
    }

    // TMDb URL
    final tmdbMatch = RegExp(r'themoviedb\.org\/(movie|tv)\/(\d+)', caseSensitive: false).firstMatch(s);
    if (tmdbMatch != null) {
      return {
        'type': tmdbMatch.group(1)?.toLowerCase() == 'tv' ? 'TV_SHOW' : 'MOVIE',
        'tmdbId': int.tryParse(tmdbMatch.group(2) ?? ''),
      };
    }

    // IMDb URL or Const ID
    final imdbMatch = RegExp(r'(tt\d{7,10})', caseSensitive: false).firstMatch(s);
    if (imdbMatch != null) {
      return {'imdbId': imdbMatch.group(1)};
    }

    return {};
  }

  static Map<String, String>? parseDateString(String rawDate, [String? rawTime]) {
    if (rawDate.trim().isEmpty) return null;
    String dStr = rawDate.trim().replaceAll(RegExp(r'^@'), '').trim();

    // Range e.g. "2024-01-01 -> 2024-01-05"
    if (dStr.contains('->') || dStr.contains(' to ')) {
      final parts = dStr.split(RegExp(r'->|\bto\b')).map((p) => p.trim()).toList();
      final d1 = _parseSingleDate(parts[0], rawTime);
      final d2 = parts.length > 1 ? _parseSingleDate(parts[1]) : null;
      if (d1 != null) {
        return {
          'watchedAt': d2 != null ? d2.toIso8601String() : d1.toIso8601String(),
          'startedAt': d1.toIso8601String(),
          if (d2 != null) 'completedAt': d2.toIso8601String(),
        };
      }
    }

    final d = _parseSingleDate(dStr, rawTime);
    if (d != null) {
      return {'watchedAt': d.toIso8601String()};
    }
    return null;
  }

  static DateTime? _parseSingleDate(String rawDate, [String? rawTime]) {
    if (rawDate.trim().isEmpty) return null;
    String dStr = rawDate.trim().replaceAll(RegExp(r'^@'), '').trim();
    final tStr = rawTime?.trim() ?? '';

    // Standard ISO YYYY-MM-DD: set to 12:00:00 UTC to protect against date rollover across timezones
    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(dStr)) {
      return DateTime.tryParse('${dStr}T12:00:00Z');
    }

    final hasEmbeddedTime = RegExp(r'T\d{2}:\d{2}', caseSensitive: false).hasMatch(dStr) ||
        RegExp(r'\b\d{1,2}:\d{2}(?::\d{2})?(?:\s*[ap]m)?\b', caseSensitive: false).hasMatch(dStr);

    if (tStr.isNotEmpty && !hasEmbeddedTime) {
      final combined = DateTime.tryParse('$dStr $tStr');
      if (combined != null) return combined;
    }

    final parsed = DateTime.tryParse(dStr);
    if (parsed != null) {
      if (!hasEmbeddedTime && parsed.hour == 0 && parsed.minute == 0) {
        return DateTime(parsed.year, parsed.month, parsed.day, 12, 0, 0);
      }
      return parsed;
    }

    return null;
  }

  /// Extracts normalized entry metadata from arbitrary or nested JSON objects
  /// (handles Trakt movie.ids.tmdb, Letterboxd, Notion, and custom shapes)
  static Map<String, dynamic>? extractEntryMetadata(dynamic rawItem) {
    if (rawItem is! Map) return null;
    final map = Map<String, dynamic>.from(rawItem);

    String clean(dynamic k) => k.toString().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

    const validTitleKeys = [
      'title', 'name', 'movietitle', 'showtitle', 'film', 'movie',
      'originaltitle', 'originalname', 'heading', 'track', 'subject'
    ];

    const entityContainerKeys = [
      'movie', 'show', 'tv', 'series', 'film', 'media', 'item', 'entry', 'episode'
    ];

    // 1. EXTRACT TITLE
    String title = '';
    Map<String, dynamic>? matchedContainer;

    // Check top-level
    for (final entry in map.entries) {
      if (entry.value is String && entry.value.toString().trim().isNotEmpty && validTitleKeys.contains(clean(entry.key))) {
        title = entry.value.toString().trim();
        break;
      }
    }

    // Check containers
    if (title.isEmpty) {
      for (final ck in entityContainerKeys) {
        final container = map[ck];
        if (container is Map) {
          final cMap = Map<String, dynamic>.from(container);
          for (final entry in cMap.entries) {
            if (entry.value is String && entry.value.toString().trim().isNotEmpty && validTitleKeys.contains(clean(entry.key))) {
              title = entry.value.toString().trim();
              matchedContainer = cMap;
              break;
            }
          }
          if (title.isNotEmpty) break;
        }
      }
    }

    // Deep search any nested map
    if (title.isEmpty) {
      for (final v in map.values) {
        if (v is Map) {
          final vMap = Map<String, dynamic>.from(v);
          for (final entry in vMap.entries) {
            if (entry.value is String && entry.value.toString().trim().isNotEmpty && validTitleKeys.contains(clean(entry.key))) {
              title = entry.value.toString().trim();
              matchedContainer = vMap;
              break;
            }
          }
          if (title.isNotEmpty) break;
        }
      }
    }

    if (title.isEmpty) return null;

    dynamic findValue(List<String> candidateKeys) {
      final cleaned = candidateKeys.map(clean).toList();
      for (final e in map.entries) {
        if (e.value != null && cleaned.contains(clean(e.key))) return e.value;
      }
      if (matchedContainer != null) {
        for (final e in matchedContainer.entries) {
          if (e.value != null && cleaned.contains(clean(e.key))) return e.value;
        }
      }
      for (final ck in entityContainerKeys) {
        final c = map[ck];
        if (c is Map) {
          for (final e in c.entries) {
            if (e.value != null && cleaned.contains(clean(e.key))) return e.value;
          }
        }
      }
      return null;
    }

    // 2. EXTRACT TMDB ID
    int? tmdbId;
    final rawTmdb = findValue(['tmdbid', 'tmdb', 'tmdb_id', 'id_tmdb']);
    if (rawTmdb != null) {
      tmdbId = int.tryParse(rawTmdb.toString());
    }
    if (tmdbId == null) {
      final ids = map['ids'] ?? matchedContainer?['ids'] ?? (map['movie'] is Map ? (map['movie'] as Map)['ids'] : null) ?? (map['show'] is Map ? (map['show'] as Map)['ids'] : null);
      if (ids is Map) {
        final idVal = ids['tmdb'] ?? ids['tmdb_id'] ?? ids['tmdbId'];
        if (idVal != null) tmdbId = int.tryParse(idVal.toString());
      }
    }

    // 3. EXTRACT IMDB ID
    String? imdbId;
    final rawImdb = findValue(['imdbid', 'imdb', 'imdb_id', 'id_imdb', 'const', 'imdb_const']);
    if (rawImdb != null) {
      final m = RegExp(r'(tt\d{7,10})', caseSensitive: false).firstMatch(rawImdb.toString());
      if (m != null) imdbId = m.group(1);
    }
    if (imdbId == null) {
      final ids = map['ids'] ?? matchedContainer?['ids'] ?? (map['movie'] is Map ? (map['movie'] as Map)['ids'] : null) ?? (map['show'] is Map ? (map['show'] as Map)['ids'] : null);
      if (ids is Map) {
        final idVal = ids['imdb'] ?? ids['imdb_id'] ?? ids['imdbId'];
        if (idVal != null) {
          final m = RegExp(r'(tt\d{7,10})', caseSensitive: false).firstMatch(idVal.toString());
          if (m != null) imdbId = m.group(1);
        }
      }
    }

    // 4. EXTRACT YEAR
    String? year;
    final rawYear = findValue(['year', 'releaseyear', 'release_year', 'released', 'releasedate', 'release_date', 'firstairdate', 'first_air_date', 'airdate']);
    if (rawYear != null) {
      final m = RegExp(r'\b(19\d\d|20\d\d)\b').firstMatch(rawYear.toString());
      if (m != null) year = m.group(1);
    }

    // 5. EXTRACT MEDIA TYPE
    final rawType = findValue(['type', 'mediatype', 'media_type', 'kind', 'content_type']);
    String type = 'MOVIE';
    if (rawType != null) {
      type = parseMediaType(rawType.toString());
    } else if (map['episode'] != null || matchedContainer == map['episode']) {
      type = 'EPISODE';
    } else if (map['show'] != null || map['tv'] != null || map['series'] != null || matchedContainer == map['show']) {
      type = 'TV_SHOW';
    } else if (map['movie'] != null || map['film'] != null || matchedContainer == map['movie']) {
      type = 'MOVIE';
    }

    // 6. EXTRACT WATCH DATE
    final rawDate = findValue([
      'watchedat', 'watched_at', 'watcheddate', 'watchdate', 'watch_date',
      'date', 'viewedat', 'viewed_at', 'lastwatchedat', 'last_watched_at',
      'listedat', 'listed_at', 'loggedat', 'logged_at', 'actiondate', 'action_date',
      'ratedat', 'rated_at', 'timestamp', 'createdat', 'created_at'
    ]);
    final rawTime = findValue(['time', 'watchtime', 'watch_time', 'watchedtime']);
    final dateInfo = rawDate != null ? parseDateString(rawDate.toString(), rawTime?.toString()) : null;

    // 7. EXTRACT RATING
    final rawRating = findValue([
      'myrating', 'my_rating', 'rating', 'userrating', 'user_rating',
      'score', 'userscore', 'user_score', 'rate', 'stars', 'grade'
    ]);
    final rating = rawRating != null ? parseRating(rawRating.toString()) : null;

    // 8. EXTRACT REVIEW
    final rawReview = findValue(['review', 'notes', 'comment', 'comments', 'note', 'body', 'text']);
    final review = rawReview != null && rawReview.toString().trim().isNotEmpty ? rawReview.toString().trim() : null;

    // 9. EXTRACT TAGS
    List<String> tags = [];
    final rawTags = findValue(['tags', 'genres', 'genre', 'labels', 'keywords']);
    if (rawTags is List) {
      tags = rawTags.map((t) => t.toString().trim()).where((t) => t.isNotEmpty).toList();
    } else if (rawTags is String && rawTags.trim().isNotEmpty) {
      tags = rawTags.split(RegExp(r'[,|;]')).map((t) => t.trim()).where((t) => t.isNotEmpty).toList();
    }

    // 10. REWATCH, WATCHING, LOCATION
    final rawRewatch = findValue(['isrewatch', 'is_rewatch', 'rewatch']);
    final isRewatch = rawRewatch == true || rawRewatch == 1 || rawRewatch?.toString().toLowerCase() == 'true' || rawRewatch?.toString().toLowerCase() == 'yes';

    final rawWatching = findValue(['iswatching', 'is_watching', 'watching', 'status']);
    final isWatching = rawWatching == true || rawWatching?.toString().toLowerCase() == 'watching' || rawWatching?.toString().toLowerCase() == 'in progress';

    final rawLoc = findValue(['watchlocation', 'watch_location', 'location', 'venue', 'cinema', 'platform', 'service']);
    final watchLocation = rawLoc != null && rawLoc.toString().trim().isNotEmpty ? rawLoc.toString().trim() : null;

    return {
      'title': title,
      'type': type,
      if (year != null) 'year': int.tryParse(year) ?? year,
      if (tmdbId != null && tmdbId > 0) 'tmdbId': tmdbId,
      if (imdbId != null) 'imdbId': imdbId,
      if (dateInfo != null && dateInfo['watchedAt'] != null) 'watchedAt': dateInfo['watchedAt'],
      if (dateInfo != null && dateInfo['startedAt'] != null) 'startedAt': dateInfo['startedAt'],
      if (dateInfo != null && dateInfo['completedAt'] != null) 'completedAt': dateInfo['completedAt'],
      if (rating != null) 'rating': rating,
      if (review != null) 'review': review,
      if (tags.isNotEmpty) 'tags': tags,
      if (watchLocation != null) 'watchLocation': watchLocation,
      'isRewatch': isRewatch,
      'isWatching': isWatching,
    };
  }

  static List<Map<String, dynamic>> _normalizeJsonEntries(dynamic rawList) {
    if (rawList is! List) return [];
    final res = <Map<String, dynamic>>[];

    for (final item in rawList) {
      final meta = extractEntryMetadata(item);
      if (meta != null) {
        res.add(meta);
      }
    }

    return res;
  }

  static Map<String, dynamic> _parseWatchHiveNativeCsv(String text) {
    final entries = <Map<String, dynamic>>[];
    final lists = <Map<String, dynamic>>[];

    String entriesPart = '';
    String listsPart = '';

    if (text.contains('# WATCH LISTS')) {
      final parts = text.split(RegExp(r'# WATCH LISTS', caseSensitive: false));
      entriesPart = parts[0].replaceAll(RegExp(r'# WATCH ENTRIES', caseSensitive: false), '').trim();
      listsPart = parts.length > 1 ? parts[1].trim() : '';
    } else {
      entriesPart = text.replaceAll(RegExp(r'# WATCH ENTRIES', caseSensitive: false), '').trim();
    }

    if (entriesPart.isNotEmpty) {
      final rows = parseCsvRows(entriesPart);
      if (rows.length > 1) {
        final headers = rows[0].map((h) => h.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '')).toList();
        for (int i = 1; i < rows.length; i++) {
          final row = rows[i];
          final obj = <String, String>{};
          for (int h = 0; h < headers.length; h++) {
            if (h < row.length) obj[headers[h]] = row[h];
          }
          final title = obj['title'];
          if (title != null && title.isNotEmpty) {
            entries.add({
              'title': title,
              'type': obj['type'] ?? 'MOVIE',
              if (obj['tmdbid'] != null) 'tmdbId': int.tryParse(obj['tmdbid']!),
              if (obj['rating'] != null) 'rating': obj['rating'],
              if (obj['watchedat'] != null) 'watchedAt': obj['watchedat'],
              if (obj['review'] != null) 'review': obj['review'],
              if (obj['tags'] != null) 'tags': obj['tags']!.split('|').where((t) => t.isNotEmpty).toList(),
              'isRewatch': obj['isrewatch'] == 'true' || obj['isrewatch'] == '1',
              'isWatching': obj['iswatching'] == 'true' || obj['iswatching'] == '1',
              if (obj['watchlocation'] != null) 'watchLocation': obj['watchlocation'],
              'inWatchlist': obj['inwatchlist'] == 'true' || obj['inwatchlist'] == '1',
            });
          }
        }
      }
    }

    if (listsPart.isNotEmpty) {
      final rows = parseCsvRows(listsPart);
      if (rows.length > 1) {
        final headers = rows[0].map((h) => h.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '')).toList();
        final listMap = <String, Map<String, dynamic>>{};
        for (int i = 1; i < rows.length; i++) {
          final row = rows[i];
          final obj = <String, String>{};
          for (int h = 0; h < headers.length; h++) {
            if (h < row.length) obj[headers[h]] = row[h];
          }
          final name = obj['listname'];
          if (name == null || name.isEmpty) continue;
          if (!listMap.containsKey(name)) {
            listMap[name] = {
              'name': name,
              'type': obj['listtype'] ?? 'WATCHLIST',
              'description': obj['listdescription'],
              'isPublic': obj['ispublic'] == 'true' || obj['ispublic'] == '1',
              'items': <Map<String, dynamic>>[],
            };
          }
          if (obj['tmdbid'] != null) {
            (listMap[name]!['items'] as List).add({
              'tmdbId': int.tryParse(obj['tmdbid']!),
              'mediaType': obj['mediatype'] ?? 'movie',
            });
          }
        }
        lists.addAll(listMap.values);
      }
    }

    return {
      if (entries.isNotEmpty) 'entries': entries,
      if (lists.isNotEmpty) 'lists': lists,
    };
  }
}
