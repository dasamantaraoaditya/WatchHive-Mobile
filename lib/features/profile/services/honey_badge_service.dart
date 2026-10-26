import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../shared/models/entry.dart';
import '../../../shared/models/user.dart';

class HoneyBadgeService {
  static const _storage = FlutterSecureStorage();
  static final Map<String, Set<String>> inMemoryBadges = {};

  static String _storageKey(String userId) => 'wh_earned_badges_$userId';

  /// Prewarm local badges into memory for fast synchronous access
  static Future<Set<String>> loadLocalBadges(String userId) async {
    if (userId.isEmpty) return {};
    try {
      final raw = await _storage.read(key: _storageKey(userId));
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as List<dynamic>;
        final set = decoded.map((e) => e.toString()).toSet();
        inMemoryBadges[userId] = set;
        return set;
      }
    } catch (_) {}
    return inMemoryBadges[userId] ?? {};
  }

  /// Award a badge ID locally
  static Future<void> awardBadgeLocally(String userId, String badgeId) async {
    if (userId.isEmpty || badgeId.isEmpty) return;
    try {
      final current = inMemoryBadges.putIfAbsent(userId, () => <String>{});
      current.add(badgeId);
      final raw = await _storage.read(key: _storageKey(userId));
      Set<String> set = {};
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as List<dynamic>;
        set = decoded.map((e) => e.toString()).toSet();
      }
      set.add(badgeId);
      await _storage.write(key: _storageKey(userId), value: jsonEncode(set.toList()));
    } catch (_) {}
  }

  /// Computes a comprehensive map of earned badge data for a user
  static Map<String, dynamic> computeEarnedBadgesMap(
    User user, {
    List<Entry>? entries,
    Set<String>? additionalBadgeIds,
  }) {
    final earned = <String, dynamic>{};

    // 1. From backend user.badges array
    for (final b in user.badges) {
      if (b is Map) {
        final id = b['id']?.toString() ?? '';
        if (id.isNotEmpty) {
          earned[id] = b;
          if (id == 'first_log') earned['pioneer'] = b;
          if (id == 'rewatch') earned['rewatcher'] = b;
          if (id == 'suggest') earned['hive_suggester'] = b;
        }
      } else if (b is String && b.isNotEmpty) {
        earned[b] = {'id': b};
        if (b == 'first_log') earned['pioneer'] = {'id': b};
        if (b == 'rewatch') earned['rewatcher'] = {'id': b};
        if (b == 'suggest') earned['hive_suggester'] = {'id': b};
      }
    }

    // 2. From in-memory local storage cache
    final localSet = inMemoryBadges[user.id] ?? <String>{};
    for (final id in localSet) {
      earned[id] ??= {'id': id, 'isLocal': true};
      if (id == 'first_log') earned['pioneer'] ??= {'id': id, 'isLocal': true};
      if (id == 'rewatch') earned['rewatcher'] ??= {'id': id, 'isLocal': true};
      if (id == 'suggest') earned['hive_suggester'] ??= {'id': id, 'isLocal': true};
    }

    // 3. From additional passed-in badge IDs
    if (additionalBadgeIds != null) {
      for (final id in additionalBadgeIds) {
        earned[id] ??= {'id': id};
      }
    }

    // 4. Dynamic evaluation based on User statistics
    // 4a. First Log: entriesCount >= 1
    if (user.entriesCount >= 1) {
      earned['pioneer'] ??= {
        'id': 'pioneer',
        'name': 'First Log',
        'unlockedAt': user.createdAt.toIso8601String(),
      };
    }

    // 4b. Century Watcher: entriesCount >= 100
    if (user.entriesCount >= 100) {
      earned['century_watcher'] ??= {
        'id': 'century_watcher',
        'name': 'Century Watcher',
      };
    }

    // 4c. Streak badges
    if (user.watchStreak >= 10) {
      earned['streak_10'] ??= {
        'id': 'streak_10',
        'name': 'Serious Watcher',
      };
    }
    if (user.watchStreak >= 20) {
      earned['streak_20'] ??= {
        'id': 'streak_20',
        'name': 'Jobless',
      };
    }
    if (user.watchStreak >= 30) {
      earned['streak_30'] ??= {
        'id': 'streak_30',
        'name': 'Maniac',
      };
    }

    // 5. Evaluate from entries list if present
    if (entries != null && entries.isNotEmpty) {
      if (entries.any((e) => e.isRewatch)) {
        earned['rewatcher'] ??= {
          'id': 'rewatcher',
          'name': 'Rewatch Master',
        };
      }
      if (entries.any((e) => e.suggestedByUserId != null && e.suggestedByUserId!.trim().isNotEmpty)) {
        earned['suggestion_starter'] ??= {
          'id': 'suggestion_starter',
          'name': 'Suggestion Starter',
        };
      }
    }

    return earned;
  }
}
