import 'package:flutter_test/flutter_test.dart';
import 'package:watchhive_mobile/shared/models/entry.dart';
import 'package:watchhive_mobile/shared/models/models.dart';
import 'package:watchhive_mobile/features/feed/providers/feed_provider.dart';
import 'package:watchhive_mobile/features/feed/repositories/feed_repository.dart';

class _FakeFeedRepository implements FeedRepository {
  List<Entry> stubEntries = [];

  @override
  Future<List<Entry>> getCachedFeed() async => [];

  @override
  Future<({List<Entry> entries, Pagination pagination})> getFeed({
    int limit = 20,
    int offset = 0,
  }) async {
    return (
      entries: stubEntries,
      pagination: Pagination(
        offset: offset,
        limit: limit,
        total: stubEntries.length,
        hasMore: false,
      ),
    );
  }

  @override
  Future<void> likeEntry(String entryId) async {}

  @override
  Future<void> unlikeEntry(String entryId) async {}
}

void main() {
  group('Entry Model & Activity Date Tests', () {
    test('computes activityDate correctly for watching, completed, reviewed, and logged', () {
      final now = DateTime.now();
      final startedTime = now.subtract(const Duration(hours: 3));
      final completedTime = now.subtract(const Duration(minutes: 30));
      final updatedTime = now.subtract(const Duration(minutes: 10));
      final watchedTime = now.subtract(const Duration(days: 2));

      // 1. Currently watching uses startedAt
      final watchingEntry = Entry(
        id: '1',
        userId: 'u1',
        tmdbId: 101,
        title: 'Movie A',
        type: 'MOVIE',
        watchedAt: watchedTime,
        isWatching: true,
        startedAt: startedTime,
        createdAt: now.subtract(const Duration(hours: 4)),
      );
      expect(watchingEntry.activityDate, startedTime);

      // 2. Completed watching uses completedAt
      final completedEntry = Entry(
        id: '2',
        userId: 'u1',
        tmdbId: 102,
        title: 'Movie B',
        type: 'MOVIE',
        watchedAt: watchedTime,
        completedAt: completedTime,
        createdAt: now.subtract(const Duration(hours: 5)),
      );
      expect(completedEntry.activityDate, completedTime);

      // 3. Reviewed entry uses createdAt (or completedAt if watching completed)
      final reviewedEntry = Entry(
        id: '3',
        userId: 'u1',
        tmdbId: 103,
        title: 'Movie C',
        type: 'MOVIE',
        watchedAt: watchedTime,
        updatedAt: updatedTime,
        review: 'Incredible film',
        createdAt: now.subtract(const Duration(hours: 5)),
      );
      expect(reviewedEntry.activityDate, reviewedEntry.createdAt);

      // 4. Fallback to watchedAt
      final standardEntry = Entry(
        id: '4',
        userId: 'u1',
        tmdbId: 104,
        title: 'Movie D',
        type: 'MOVIE',
        watchedAt: watchedTime,
        createdAt: watchedTime,
      );
      expect(standardEntry.activityDate, watchedTime);
    });

    test('Entry.fromJson correctly parses isImported and updatedAt', () {
      final jsonWithImport = {
        'id': 'imp-1',
        'userId': 'u1',
        'tmdbId': 99,
        'title': 'Old Classic',
        'type': 'MOVIE',
        'watchedAt': '2023-01-01T00:00:00.000Z',
        'isImported': true,
        'updatedAt': '2026-10-12T10:00:00.000Z',
      };
      final entry = Entry.fromJson(jsonWithImport);
      expect(entry.isImported, isTrue);
      expect(entry.updatedAt, isNotNull);

      final jsonWithImportTag = {
        'id': 'imp-2',
        'userId': 'u1',
        'tmdbId': 100,
        'title': 'Imported Film',
        'type': 'MOVIE',
        'watchedAt': '2023-01-01T00:00:00.000Z',
        'tags': ['imported', 'classic'],
      };
      final entryFromTag = Entry.fromJson(jsonWithImportTag);
      expect(entryFromTag.isImported, isTrue);
    });
  });

  group('Feed Notifier Ordering & Imported Filtering Tests', () {
    late _FakeFeedRepository fakeRepo;

    setUp(() {
      fakeRepo = _FakeFeedRepository();
    });

    test('FeedNotifier filters out imported entries and sorts by activityDate descending', () async {
      final now = DateTime.now();

      final normalNewEntry = Entry(
        id: 'e-new',
        userId: 'u1',
        tmdbId: 201,
        title: 'Latest Watch',
        type: 'MOVIE',
        watchedAt: now.subtract(const Duration(minutes: 5)),
        createdAt: now.subtract(const Duration(minutes: 5)),
      );

      final normalOlderEntry = Entry(
        id: 'e-older',
        userId: 'u2',
        tmdbId: 202,
        title: 'Earlier Watch',
        type: 'MOVIE',
        watchedAt: now.subtract(const Duration(hours: 2)),
        createdAt: now.subtract(const Duration(hours: 2)),
      );

      final importedEntry1 = Entry(
        id: 'imp-1',
        userId: 'u1',
        tmdbId: 901,
        title: 'Imported CSV Movie 1',
        type: 'MOVIE',
        watchedAt: now.subtract(const Duration(days: 30)),
        isImported: true,
        createdAt: now,
      );

      final importedEntry2 = Entry(
        id: 'imp-2',
        userId: 'u2',
        tmdbId: 902,
        title: 'Imported CSV Movie 2',
        type: 'MOVIE',
        watchedAt: now.subtract(const Duration(days: 60)),
        tags: const ['imported'],
        createdAt: now,
      );

      fakeRepo.stubEntries = [
        importedEntry1,
        normalOlderEntry,
        importedEntry2,
        normalNewEntry,
      ];

      final notifier = FeedNotifier(fakeRepo);
      await notifier.loadFeed();

      final state = notifier.state;

      // Ensure imported entries are excluded completely from community feed
      expect(state.entries.any((e) => e.id == 'imp-1'), isFalse);
      expect(state.entries.any((e) => e.id == 'imp-2'), isFalse);
      expect(state.entries.length, equals(2));

      // Ensure chronological ordering: e-new first, then e-older
      expect(state.entries[0].id, equals('e-new'));
      expect(state.entries[1].id, equals('e-older'));
    });

    test('prependEntry rejects imported entries and keeps feed sorted by activity date', () async {
      final now = DateTime.now();
      fakeRepo.stubEntries = [];

      final notifier = FeedNotifier(fakeRepo);
      await notifier.loadFeed();

      final imported = Entry(
        id: 'imp-new',
        userId: 'u1',
        tmdbId: 301,
        title: 'Imported Film',
        type: 'MOVIE',
        watchedAt: now,
        isImported: true,
        createdAt: now,
      );

      notifier.prependEntry(imported);
      expect(notifier.state.entries.isEmpty, isTrue);

      final validOlder = Entry(
        id: 'v-older',
        userId: 'u1',
        tmdbId: 302,
        title: 'Watched Earlier',
        type: 'MOVIE',
        watchedAt: now.subtract(const Duration(hours: 1)),
        createdAt: now.subtract(const Duration(hours: 1)),
      );
      notifier.prependEntry(validOlder);

      final validNewer = Entry(
        id: 'v-newer',
        userId: 'u1',
        tmdbId: 303,
        title: 'Watched Just Now',
        type: 'MOVIE',
        watchedAt: now,
        createdAt: now,
      );
      notifier.prependEntry(validNewer);

      expect(notifier.state.entries.length, equals(2));
      expect(notifier.state.entries[0].id, equals('v-newer'));
      expect(notifier.state.entries[1].id, equals('v-older'));
    });
  });
}
