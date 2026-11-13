import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:watchhive_mobile/features/entries/providers/watchlist_provider.dart';
import 'package:watchhive_mobile/features/entries/repositories/watchlist_repository.dart';

class MockWatchlistRepository implements WatchlistRepository {
  List<Map<String, dynamic>> items = [
    {
      'id': 'item-1',
      'tmdbId': 100,
      'title': 'Test Movie',
      'mediaType': 'movie',
      'addedAt': '2026-11-13T10:00:00Z',
    },
  ];

  @override
  Future<Map<String, dynamic>> getWatchlist() async {
    return {
      'id': 'wl-1',
      'items': items,
    };
  }

  @override
  Future<void> addToWatchlist({
    required int tmdbId,
    required String title,
    required String mediaType,
    String? posterPath,
    String? overview,
    String? suggestedByUserId,
  }) async {
    items.insert(0, {
      'id': 'item-$tmdbId',
      'tmdbId': tmdbId,
      'title': title,
      'mediaType': mediaType,
      'posterPath': posterPath,
    });
  }

  @override
  Future<void> removeFromWatchlist(dynamic target, {String? listId}) async {
    final int? tmdb = target is int ? target : int.tryParse(target?.toString() ?? '');
    final String? str = target?.toString();
    items.removeWhere((i) {
      if (tmdb != null && i['tmdbId'] == tmdb) return true;
      if (str != null && i['id'] == str) return true;
      return false;
    });
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('WatchlistNotifier and reactiveIsInWatchlistProvider Tests', () {
    late MockWatchlistRepository mockRepo;
    late ProviderContainer container;

    setUp(() {
      mockRepo = MockWatchlistRepository();
      container = ProviderContainer(
        overrides: [
          watchlistRepositoryProvider.overrideWithValue(mockRepo),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('initializes and loads watchlist items', () async {
      await container.read(watchlistProvider.notifier).loadWatchlist();
      final state = container.read(watchlistProvider);

      expect(state.items.length, 1);
      expect(state.items.first['tmdbId'], 100);
      expect(container.read(reactiveIsInWatchlistProvider(100)), isTrue);
      expect(container.read(reactiveIsInWatchlistProvider(200)), isFalse);
    });

    test('addToWatchlist optimistically adds item and updates isInWatchlist', () async {
      final notifier = container.read(watchlistProvider.notifier);
      await notifier.loadWatchlist();

      final addFuture = notifier.addToWatchlist(
        tmdbId: 200,
        title: 'New Movie',
        mediaType: 'movie',
      );

      // Immediately present optimistically
      expect(container.read(reactiveIsInWatchlistProvider(200)), isTrue);
      await addFuture;

      final state = container.read(watchlistProvider);
      expect(state.items.any((it) => it['tmdbId'] == 200), isTrue);
    });

    test('removeFromWatchlist optimistically removes item and updates isInWatchlist', () async {
      final notifier = container.read(watchlistProvider.notifier);
      await notifier.loadWatchlist();

      expect(container.read(reactiveIsInWatchlistProvider(100)), isTrue);

      final removeFuture = notifier.removeFromWatchlist(100);

      // Immediately removed optimistically
      expect(container.read(reactiveIsInWatchlistProvider(100)), isFalse);
      await removeFuture;

      final state = container.read(watchlistProvider);
      expect(state.items.any((it) => it['tmdbId'] == 100), isFalse);
    });
  });
}
