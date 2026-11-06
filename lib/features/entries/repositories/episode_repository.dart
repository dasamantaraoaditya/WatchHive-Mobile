import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../shared/models/episode_progress.dart';

final episodeRepositoryProvider = Provider<EpisodeRepository>((ref) {
  return EpisodeRepository(ref.read(apiClientProvider));
});

class EpisodeRepository {
  final ApiClient _api;

  EpisodeRepository(this._api);

  /// Fetch full episode progress for a TV show
  Future<ShowProgress> getShowProgress(int tmdbId) async {
    final response = await _api.get('/shows/$tmdbId/progress');
    return ShowProgress.fromJson(response.data as Map<String, dynamic>);
  }

  /// Mark or unmark an episode as watched
  Future<ShowProgress> toggleEpisodeWatch({
    required int tmdbId,
    required int seasonNumber,
    required int episodeNumber,
    int? episodeId,
    String? episodeName,
    bool isWatched = true,
    double? rating,
    String? review,
    bool postToFeed = false,
  }) async {
    final response = await _api.post(
      '/shows/$tmdbId/episodes/watch',
      data: {
        'seasonNumber': seasonNumber,
        'episodeNumber': episodeNumber,
        if (episodeId != null) 'episodeId': episodeId,
        if (episodeName != null) 'episodeName': episodeName,
        'isWatched': isWatched,
        if (rating != null) 'rating': rating,
        if (review != null) 'review': review,
        'postToFeed': postToFeed,
      },
    );
    final data = response.data as Map<String, dynamic>;
    return ShowProgress.fromJson(data['progress'] as Map<String, dynamic>);
  }

  /// Catch up all episodes from S1E1 up to target
  Future<ShowProgress> batchCatchUp({
    required int tmdbId,
    required int upToSeason,
    required int upToEpisode,
  }) async {
    final response = await _api.post(
      '/shows/$tmdbId/episodes/batch-catch-up',
      data: {
        'upToSeason': upToSeason,
        'upToEpisode': upToEpisode,
      },
    );
    final data = response.data as Map<String, dynamic>;
    return ShowProgress.fromJson(data['progress'] as Map<String, dynamic>);
  }

  /// Fetch Continue Watching shows for the active user
  Future<List<ContinueWatchingItem>> getContinueWatching({int limit = 15}) async {
    try {
      final response = await _api.get('/users/me/continue-watching', queryParameters: {'limit': limit});
      final data = response.data as Map<String, dynamic>;
      final list = (data['items'] as List<dynamic>?) ?? [];
      return list.map((e) => ContinueWatchingItem.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Fetch friends watching this show
  Future<List<FriendShowProgress>> getFriendsProgress(int tmdbId) async {
    try {
      final response = await _api.get('/shows/$tmdbId/friends-progress');
      final data = response.data as Map<String, dynamic>;
      final list = (data['friends'] as List<dynamic>?) ?? [];
      return list.map((e) => FriendShowProgress.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }
}
