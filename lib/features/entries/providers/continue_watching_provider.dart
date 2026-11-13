import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/models/episode_progress.dart';
import '../repositories/episode_repository.dart';

class ContinueWatchingState {
  final List<ContinueWatchingItem> items;
  final bool isLoading;
  final String? error;

  const ContinueWatchingState({
    this.items = const [],
    this.isLoading = false,
    this.error,
  });

  ContinueWatchingState copyWith({
    List<ContinueWatchingItem>? items,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) =>
      ContinueWatchingState(
        items: items ?? this.items,
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : (error ?? this.error),
      );
}

class ContinueWatchingNotifier extends StateNotifier<ContinueWatchingState> {
  final EpisodeRepository _repo;

  ContinueWatchingNotifier(this._repo) : super(const ContinueWatchingState(isLoading: true)) {
    load();
  }

  Future<void> load({int limit = 15}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final items = await _repo.getContinueWatching(limit: limit);
      state = state.copyWith(items: items, isLoading: false, clearError: true);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> refresh({int limit = 15}) async {
    try {
      final items = await _repo.getContinueWatching(limit: limit);
      state = state.copyWith(items: items, isLoading: false, clearError: true);
    } catch (_) {}
  }

  void updateProgress({
    required int tmdbId,
    required int nextSeasonNumber,
    required int nextEpisodeNumber,
    required int progressPercentage,
    NextEpisodeUp? nextEpisodeUp,
  }) {
    state = state.copyWith(
      items: state.items.map((it) {
        if (it.tmdbId == tmdbId) {
          return ContinueWatchingItem(
            entryId: it.entryId,
            tmdbId: it.tmdbId,
            title: it.title,
            posterPath: it.posterPath,
            backdropPath: it.backdropPath,
            currentSeason: nextSeasonNumber,
            currentEpisode: nextEpisodeNumber,
            totalEpisodesWatched: it.totalEpisodesWatched + 1,
            totalEpisodesCount: it.totalEpisodesCount,
            progressPercentage: progressPercentage,
            nextEpisodeUp: nextEpisodeUp,
            lastWatchedAt: DateTime.now(),
          );
        }
        return it;
      }).toList(),
    );
  }

  void removeItem(int tmdbId) {
    state = state.copyWith(
      items: state.items.where((it) => it.tmdbId != tmdbId).toList(),
    );
  }
}

final continueWatchingProvider =
    StateNotifierProvider<ContinueWatchingNotifier, ContinueWatchingState>((ref) {
  return ContinueWatchingNotifier(ref.read(episodeRepositoryProvider));
});
