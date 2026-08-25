import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watchhive_mobile/core/api/api_client.dart';
import 'package:watchhive_mobile/core/auth/auth_manager.dart';
import 'package:watchhive_mobile/features/entries/repositories/entries_repository.dart';
import 'package:watchhive_mobile/features/entries/screens/entries_screen.dart';
import 'package:watchhive_mobile/shared/models/entry.dart';
import 'package:watchhive_mobile/shared/models/models.dart';

class FakeAuthManager extends AuthManager {}

class FakeEntriesRepository extends EntriesRepository {
  FakeEntriesRepository() : super(ApiClient(FakeAuthManager()));

  final List<Entry> mockDatabase = [
    Entry(
      id: '1',
      userId: 'u1',
      tmdbId: 101,
      title: 'Currently Watching Movie',
      type: 'MOVIE',
      isWatching: true,
      isRewatch: false,
      watchedAt: DateTime.now(),
      tags: const [],
      createdAt: DateTime.now(),
    ),
    Entry(
      id: '2',
      userId: 'u1',
      tmdbId: 102,
      title: 'Watched Movie in History',
      type: 'MOVIE',
      isWatching: false,
      isRewatch: false,
      rating: 4.5,
      watchedAt: DateTime.now(),
      tags: const [],
      createdAt: DateTime.now(),
    ),
  ];

  @override
  Future<({List<Entry> entries, Pagination pagination})> getEntries({
    String? type,
    String? search,
    bool? isWatching,
    String sortBy = 'watchedAt',
    String order = 'desc',
    int limit = 20,
    int offset = 0,
    String? userId,
  }) async {
    var items = mockDatabase.where((e) {
      if (isWatching != null && e.isWatching != isWatching) return false;
      if (type != null && e.type != type) return false;
      return true;
    }).toList();

    return (
      entries: items,
      pagination: const Pagination(limit: 20, total: 2, offset: 0, hasMore: false),
    );
  }

  @override
  Future<void> deleteEntry(String id) async {
    mockDatabase.removeWhere((e) => e.id == id);
  }
}

void main() {
  setUpAll(() {
    dotenv.testLoad(fileInput: 'API_BASE_URL=http://localhost:3000/api');
  });

  group('EntriesNotifier and entriesProvider Tests', () {
    late FakeEntriesRepository fakeRepo;

    setUp(() {
      fakeRepo = FakeEntriesRepository();
    });

    test('Currently Watching notifier loads only isWatching=true entries on init', () async {
      final notifier = EntriesNotifier(fakeRepo, isWatching: true);
      // Wait for async loadEntries triggered in constructor
      await Future.delayed(const Duration(milliseconds: 50));

      expect(notifier.state.isLoading, false);
      expect(notifier.state.entries.length, 1);
      expect(notifier.state.entries.first.title, 'Currently Watching Movie');
      expect(notifier.state.entries.first.isWatching, true);
    });

    test('Watch History notifier loads only isWatching=false entries on init', () async {
      final notifier = EntriesNotifier(fakeRepo, isWatching: false);
      // Wait for async loadEntries triggered in constructor
      await Future.delayed(const Duration(milliseconds: 50));

      expect(notifier.state.isLoading, false);
      expect(notifier.state.entries.length, 1);
      expect(notifier.state.entries.first.title, 'Watched Movie in History');
      expect(notifier.state.entries.first.isWatching, false);
    });

    test('addEntry adds to matching isWatching notifier and removes from non-matching', () async {
      final watchingNotifier = EntriesNotifier(fakeRepo, isWatching: true);
      final historyNotifier = EntriesNotifier(fakeRepo, isWatching: false);
      await Future.delayed(const Duration(milliseconds: 50));

      final newWatching = Entry(
        id: '3',
        userId: 'u1',
        tmdbId: 103,
        title: 'New Active Show',
        type: 'TV_SHOW',
        isWatching: true,
        isRewatch: false,
        watchedAt: DateTime.now(),
        tags: const [],
        createdAt: DateTime.now(),
      );

      watchingNotifier.addEntry(newWatching);
      historyNotifier.addEntry(newWatching);

      expect(watchingNotifier.state.entries.any((e) => e.id == '3'), true);
      expect(historyNotifier.state.entries.any((e) => e.id == '3'), false);
    });

    test('updateEntry transitions movie from watching to history correctly', () async {
      final watchingNotifier = EntriesNotifier(fakeRepo, isWatching: true);
      final historyNotifier = EntriesNotifier(fakeRepo, isWatching: false);
      await Future.delayed(const Duration(milliseconds: 50));

      // Movie 1 was watching = true. Now user finishes it (isWatching = false)
      final finishedEntry = Entry(
        id: '1',
        userId: 'u1',
        tmdbId: 101,
        title: 'Currently Watching Movie',
        type: 'MOVIE',
        isWatching: false,
        isRewatch: false,
        rating: 5.0,
        watchedAt: DateTime.now(),
        tags: const [],
        createdAt: DateTime.now(),
      );

      watchingNotifier.updateEntry(finishedEntry);
      historyNotifier.updateEntry(finishedEntry);

      // Removed from watching tab
      expect(watchingNotifier.state.entries.any((e) => e.id == '1'), false);
      // Added to history tab
      expect(historyNotifier.state.entries.any((e) => e.id == '1'), true);
    });

    test('deleteEntry removes entry from state', () async {
      final watchingNotifier = EntriesNotifier(fakeRepo, isWatching: true);
      await Future.delayed(const Duration(milliseconds: 50));

      expect(watchingNotifier.state.entries.length, 1);
      await watchingNotifier.deleteEntry('1');
      expect(watchingNotifier.state.entries.isEmpty, true);
    });
  });
}
