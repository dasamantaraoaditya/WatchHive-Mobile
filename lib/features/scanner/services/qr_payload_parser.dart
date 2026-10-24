import 'dart:convert';

/// Represents the strongly-typed parsed result of a scanned QR code.
sealed class ParsedQrResult {
  const ParsedQrResult();
}

/// A scanned WatchersHive user profile QR code.
class UserQrResult extends ParsedQrResult {
  final String userId;
  final String? username;
  final String? displayName;

  const UserQrResult({
    required this.userId,
    this.username,
    this.displayName,
  });

  @override
  String toString() => 'UserQrResult(userId: $userId, username: $username)';
}

/// A scanned WatchersHive movie or series details QR code.
class MovieQrResult extends ParsedQrResult {
  final int tmdbId;
  final String mediaType; // 'movie' or 'tv'
  final String? title;

  const MovieQrResult({
    required this.tmdbId,
    this.mediaType = 'movie',
    this.title,
  });

  @override
  String toString() => 'MovieQrResult(tmdbId: $tmdbId, mediaType: $mediaType, title: $title)';
}

/// An unknown or unparseable scanned payload.
class UnknownQrResult extends ParsedQrResult {
  final String rawData;

  const UnknownQrResult(this.rawData);

  @override
  String toString() => 'UnknownQrResult($rawData)';
}

/// High-performance parser that resolves WatchersHive URLs, deep links,
/// JSON payloads, and direct identifiers into [ParsedQrResult].
class QrPayloadParser {
  QrPayloadParser._();

  static final RegExp _uuidRegex = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  /// Parse any scanned string into a [ParsedQrResult].
  static ParsedQrResult parse(String? raw) {
    if (raw == null) return const UnknownQrResult('');
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return const UnknownQrResult('');

    // 1. Try JSON payload format
    if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
      final jsonResult = _tryParseJson(trimmed);
      if (jsonResult != null) return jsonResult;
    }

    // 2. Try URI / URL format (http, https, watchershive://, watchhive://)
    final uri = Uri.tryParse(trimmed);
    if (uri != null) {
      final uriResult = _tryParseUri(uri, trimmed);
      if (uriResult != null) return uriResult;
    }

    // 3. Fallback: If it's a raw UUID, treat as user ID
    if (_uuidRegex.hasMatch(trimmed)) {
      return UserQrResult(userId: trimmed);
    }

    return UnknownQrResult(trimmed);
  }

  static ParsedQrResult? _tryParseJson(String raw) {
    try {
      final map = jsonDecode(raw);
      if (map is Map<String, dynamic>) {
        final type = map['type']?.toString().toLowerCase();

        if (type == 'user' || type == 'profile') {
          final id = map['id']?.toString() ?? map['userId']?.toString();
          if (id != null && id.isNotEmpty) {
            return UserQrResult(
              userId: id,
              username: map['username']?.toString(),
              displayName: map['displayName']?.toString() ?? map['name']?.toString(),
            );
          }
        }

        if (type == 'movie' || type == 'tv' || type == 'media') {
          final rawId = map['tmdbId'] ?? map['id'];
          final id = rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '');
          if (id != null) {
            final mediaType = (map['mediaType']?.toString().toLowerCase() == 'tv' || type == 'tv')
                ? 'tv'
                : 'movie';
            return MovieQrResult(
              tmdbId: id,
              mediaType: mediaType,
              title: map['title']?.toString() ?? map['name']?.toString(),
            );
          }
        }
      }
    } catch (_) {}
    return null;
  }

  static ParsedQrResult? _tryParseUri(Uri uri, String raw) {
    final scheme = uri.scheme.toLowerCase();
    final host = uri.host.toLowerCase();
    final segments = uri.pathSegments;

    // A. Custom Deep Link: watchershive://user/{id} or watchhive://user/{id}
    if (scheme == 'watchershive' || scheme == 'watchhive') {
      // watchershive://user/:id or watchershive://profile/:id
      if (host == 'user' || host == 'profile') {
        if (segments.isNotEmpty && segments.first.isNotEmpty) {
          return UserQrResult(userId: segments.first);
        }
      }

      // watchershive://movie/:tmdbId or watchershive://tv/:tmdbId
      if (host == 'movie' || host == 'tv') {
        final rawId = segments.isNotEmpty ? int.tryParse(segments.first) : null;
        if (rawId != null) {
          return MovieQrResult(tmdbId: rawId, mediaType: host == 'tv' ? 'tv' : 'movie');
        }
      }

      // watchershive://details/:mediaType/:tmdbId
      if (host == 'details' && segments.length >= 2) {
        final mediaType = segments[0].toLowerCase() == 'tv' ? 'tv' : 'movie';
        final rawId = int.tryParse(segments[1]);
        if (rawId != null) {
          return MovieQrResult(tmdbId: rawId, mediaType: mediaType);
        }
      }
    }

    // B. Web URLs: watchershive.com, watchhive-web.vercel.app, localhost, etc.
    final isHiveDomain = host.contains('watchershive.com') ||
        host.contains('watchhive') ||
        host.contains('vercel.app') ||
        host == 'localhost';

    if (isHiveDomain || scheme == 'http' || scheme == 'https') {
      // Find where path starts (some URLs have /watch-hive prefix)
      final normSegments = segments.where((s) => s.isNotEmpty && s != 'watch-hive').toList();

      // Profile: /profile/:userId or /user/:userId
      if (normSegments.length >= 2 && (normSegments[0] == 'profile' || normSegments[0] == 'user')) {
        return UserQrResult(userId: normSegments[1]);
      }

      // Details: /details/:mediaType/:tmdbId
      if (normSegments.length >= 3 && normSegments[0] == 'details') {
        final mediaType = normSegments[1].toLowerCase() == 'tv' ? 'tv' : 'movie';
        final rawId = int.tryParse(normSegments[2]);
        if (rawId != null) {
          return MovieQrResult(tmdbId: rawId, mediaType: mediaType);
        }
      }

      // Short details: /movie/:tmdbId or /tv/:tmdbId
      if (normSegments.length >= 2 && (normSegments[0] == 'movie' || normSegments[0] == 'tv')) {
        final mediaType = normSegments[0] == 'tv' ? 'tv' : 'movie';
        final rawId = int.tryParse(normSegments[1]);
        if (rawId != null) {
          return MovieQrResult(tmdbId: rawId, mediaType: mediaType);
        }
      }
    }

    return null;
  }
}
