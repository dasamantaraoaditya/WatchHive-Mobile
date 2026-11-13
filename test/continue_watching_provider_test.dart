import 'package:flutter_test/flutter_test.dart';
import 'package:watchhive_mobile/core/api/api_client.dart';
import 'package:watchhive_mobile/core/auth/auth_manager.dart';
import 'package:watchhive_mobile/features/entries/providers/continue_watching_provider.dart';
import 'package:watchhive_mobile/features/entries/repositories/episode_repository.dart';
import 'package:watchhive_mobile/shared/models/episode_progress.dart';

class _FakeAuthManager extends AuthManager {}

class _MockEpisodeRepository extends EpisodeRepository {
  List<ContinueWatchingItem> dummyItems;

  _MockEpisodeRepository(this.dummyItems) : super(ApiClient(_FakeAuthManager()));

  @override
  Future<List<ContinueWatchingItem>> getContinueWatching({int limit = 15}) async {
    return dummyItems;
  }
}

void main() {
  const dummyItem = ContinueWatchingItem(
    entryId: 'entry-1',
    tmdbId: 1399,
    title: 'Game of Thrones',
    posterPath: '/got.jpg',
    currentSeason: 1,
    currentEpisode: 1,
    totalEpisodesWatched: 1,
    totalEpisodesCount: 73,
    progressPercentage: 1.37,
    nextEpisodeUp: NextEpisodeUp(
      seasonNumber: 1,
      episodeNumber: 2,
      name: 'The Kingsroad',
    ),
  );

  group('ContinueWatchingNotifier Tests', () {
    test('loads continue watching items on initialization', () async {
      final mockRepo = _MockEpisodeRepository([dummyItem]);
      final notifier = ContinueWatchingNotifier(mockRepo);

      // Await initial load
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(notifier.state.isLoading, isFalse);
      expect(notifier.state.items.length, 1);
      expect(notifier.state.items.first.title, 'Game of Thrones');
    });

    test('updateProgress updates matching item season, episode, and next episode', () async {
      final mockRepo = _MockEpisodeRepository([dummyItem]);
      final notifier = ContinueWatchingNotifier(mockRepo);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      notifier.updateProgress(
        tmdbId: 1399,
        nextSeasonNumber: 1,
        nextEpisodeNumber: 2,
        progressPercentage: 2.74,
        nextEpisodeUp: const NextEpisodeUp(
          seasonNumber: 1,
          episodeNumber: 3,
          name: 'Lord Snow',
        ),
      );

      final updated = notifier.state.items.first;
      expect(updated.currentSeason, 1);
      expect(updated.currentEpisode, 2);
      expect(updated.totalEpisodesWatched, 2);
      expect(updated.nextEpisodeUp?.episodeNumber, 3);
    });

    test('removeItem removes completed or deleted item from state immediately', () async {
      final mockRepo = _MockEpisodeRepository([dummyItem]);
      final notifier = ContinueWatchingNotifier(mockRepo);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      notifier.removeItem(1399);

      expect(notifier.state.items, isEmpty);
    });
  });
}
