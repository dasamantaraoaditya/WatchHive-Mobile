import 'package:flutter_test/flutter_test.dart';
import 'package:watchhive_mobile/features/profile/services/honey_badge_service.dart';
import 'package:watchhive_mobile/features/profile/widgets/honey_badges_dialog.dart';
import 'package:watchhive_mobile/shared/models/entry.dart';
import 'package:watchhive_mobile/shared/models/user.dart';

void main() {
  group('HoneyBadgeService & Dynamic Badge Awarding Tests', () {
    final baseUser = User(
      id: 'test-user-1',
      username: 'honeytester',
      createdAt: DateTime.now().subtract(const Duration(days: 30)),
    );

    test('Awards pioneer (First Log) when entriesCount >= 1', () {
      final user = baseUser.copyWith(entriesCount: 3);
      final earned = HoneyBadgeService.computeEarnedBadgesMap(user);

      expect(earned.containsKey('pioneer'), isTrue);
      expect(earned.containsKey('century_watcher'), isFalse);
    });

    test('Awards century_watcher when entriesCount >= 100', () {
      final user = baseUser.copyWith(entriesCount: 120);
      final earned = HoneyBadgeService.computeEarnedBadgesMap(user);

      expect(earned.containsKey('pioneer'), isTrue);
      expect(earned.containsKey('century_watcher'), isTrue);
    });

    test('Awards streak badges based on watchStreak levels (10, 20, 30)', () {
      final user10 = baseUser.copyWith(watchStreak: 12);
      final earned10 = HoneyBadgeService.computeEarnedBadgesMap(user10);
      expect(earned10.containsKey('streak_10'), isTrue);
      expect(earned10.containsKey('streak_20'), isFalse);

      final user20 = baseUser.copyWith(watchStreak: 21);
      final earned20 = HoneyBadgeService.computeEarnedBadgesMap(user20);
      expect(earned20.containsKey('streak_10'), isTrue);
      expect(earned20.containsKey('streak_20'), isTrue);
      expect(earned20.containsKey('streak_30'), isFalse);

      final user30 = baseUser.copyWith(watchStreak: 35);
      final earned30 = HoneyBadgeService.computeEarnedBadgesMap(user30);
      expect(earned30.containsKey('streak_10'), isTrue);
      expect(earned30.containsKey('streak_20'), isTrue);
      expect(earned30.containsKey('streak_30'), isTrue);
    });

    test('Awards rewatcher when user has an entry with isRewatch = true', () {
      final rewatchEntry = Entry(
        id: 'entry-1',
        userId: baseUser.id,
        tmdbId: 101,
        title: 'Inception',
        type: 'MOVIE',
        isRewatch: true,
        watchedAt: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final earned = HoneyBadgeService.computeEarnedBadgesMap(
        baseUser.copyWith(entriesCount: 1),
        entries: [rewatchEntry],
      );

      expect(earned.containsKey('pioneer'), isTrue);
      expect(earned.containsKey('rewatcher'), isTrue);
    });

    test('Awards suggestion_starter when entry has suggestedByUserId', () {
      final suggestedEntry = Entry(
        id: 'entry-2',
        userId: baseUser.id,
        tmdbId: 102,
        title: 'Interstellar',
        type: 'MOVIE',
        suggestedByUserId: 'friend-456',
        watchedAt: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final earned = HoneyBadgeService.computeEarnedBadgesMap(
        baseUser.copyWith(entriesCount: 1),
        entries: [suggestedEntry],
      );

      expect(earned.containsKey('pioneer'), isTrue);
      expect(earned.containsKey('suggestion_starter'), isTrue);
    });

    test('Awards hive_suggester when in-memory or additional badge IDs present', () {
      final earned = HoneyBadgeService.computeEarnedBadgesMap(
        baseUser,
        additionalBadgeIds: {'hive_suggester'},
      );

      expect(earned.containsKey('hive_suggester'), isTrue);
    });

    test('HoneyBadgesDialog.getEarnedBadgesCount returns accurate total count', () {
      final user = baseUser.copyWith(
        entriesCount: 105, // pioneer + century_watcher
        watchStreak: 15,   // streak_10
      );

      final count = HoneyBadgesDialog.getEarnedBadgesCount(user);
      expect(count, equals(3));
    });
  });
}
