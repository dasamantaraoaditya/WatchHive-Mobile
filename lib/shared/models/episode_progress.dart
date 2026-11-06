import 'user.dart';

class WatchedEpisodeRecord {
  final String id;
  final int seasonNumber;
  final int episodeNumber;
  final String? episodeName;
  final DateTime watchedAt;
  final double? rating;
  final String? review;

  const WatchedEpisodeRecord({
    required this.id,
    required this.seasonNumber,
    required this.episodeNumber,
    this.episodeName,
    required this.watchedAt,
    this.rating,
    this.review,
  });

  factory WatchedEpisodeRecord.fromJson(Map<String, dynamic> json) {
    return WatchedEpisodeRecord(
      id: json['id']?.toString() ?? '',
      seasonNumber: (json['seasonNumber'] as num?)?.toInt() ?? (json['season_number'] as num?)?.toInt() ?? 1,
      episodeNumber: (json['episodeNumber'] as num?)?.toInt() ?? (json['episode_number'] as num?)?.toInt() ?? 1,
      episodeName: json['episodeName'] as String? ?? json['episode_name'] as String?,
      watchedAt: json['watchedAt'] != null
          ? (DateTime.tryParse(json['watchedAt'].toString())?.toLocal() ?? DateTime.now())
          : (json['watched_at'] != null ? (DateTime.tryParse(json['watched_at'].toString())?.toLocal() ?? DateTime.now()) : DateTime.now()),
      rating: (json['rating'] as num?)?.toDouble() ?? double.tryParse(json['rating']?.toString() ?? ''),
      review: json['review'] as String?,
    );
  }
}

class NextEpisodeUp {
  final int seasonNumber;
  final int episodeNumber;
  final String? name;
  final String? stillPath;
  final String? airDate;

  const NextEpisodeUp({
    required this.seasonNumber,
    required this.episodeNumber,
    this.name,
    this.stillPath,
    this.airDate,
  });

  factory NextEpisodeUp.fromJson(Map<String, dynamic> json) {
    return NextEpisodeUp(
      seasonNumber: (json['seasonNumber'] as num?)?.toInt() ?? (json['season_number'] as num?)?.toInt() ?? 1,
      episodeNumber: (json['episodeNumber'] as num?)?.toInt() ?? (json['episode_number'] as num?)?.toInt() ?? 1,
      name: json['name'] as String?,
      stillPath: json['stillPath'] as String? ?? json['still_path'] as String?,
      airDate: json['airDate'] as String? ?? json['air_date'] as String?,
    );
  }
}

class ShowProgress {
  final int tmdbId;
  final String title;
  final String? posterPath;
  final int? currentSeason;
  final int? currentEpisode;
  final int totalEpisodesWatched;
  final int? totalEpisodesCount;
  final int progressPercentage;
  final List<WatchedEpisodeRecord> watchedEpisodes;
  final NextEpisodeUp? nextEpisodeUp;

  const ShowProgress({
    required this.tmdbId,
    required this.title,
    this.posterPath,
    this.currentSeason,
    this.currentEpisode,
    required this.totalEpisodesWatched,
    this.totalEpisodesCount,
    required this.progressPercentage,
    required this.watchedEpisodes,
    this.nextEpisodeUp,
  });

  factory ShowProgress.fromJson(Map<String, dynamic> json) {
    final list = (json['watchedEpisodes'] as List<dynamic>?) ?? (json['watched_episodes'] as List<dynamic>?) ?? [];
    return ShowProgress(
      tmdbId: (json['tmdbId'] as num?)?.toInt() ?? (json['tmdb_id'] as num?)?.toInt() ?? 0,
      title: json['title'] as String? ?? 'TV Series',
      posterPath: json['posterPath'] as String? ?? json['poster_path'] as String?,
      currentSeason: (json['currentSeason'] as num?)?.toInt() ?? (json['current_season'] as num?)?.toInt(),
      currentEpisode: (json['currentEpisode'] as num?)?.toInt() ?? (json['current_episode'] as num?)?.toInt(),
      totalEpisodesWatched: (json['totalEpisodesWatched'] as num?)?.toInt() ?? (json['total_episodes_watched'] as num?)?.toInt() ?? 0,
      totalEpisodesCount: (json['totalEpisodesCount'] as num?)?.toInt() ?? (json['total_episodes_count'] as num?)?.toInt(),
      progressPercentage: (json['progressPercentage'] as num?)?.toInt() ?? (json['progress_percentage'] as num?)?.toInt() ?? 0,
      watchedEpisodes: list.map((e) => WatchedEpisodeRecord.fromJson(e as Map<String, dynamic>)).toList(),
      nextEpisodeUp: json['nextEpisodeUp'] != null
          ? NextEpisodeUp.fromJson(json['nextEpisodeUp'] as Map<String, dynamic>)
          : (json['next_episode_up'] != null ? NextEpisodeUp.fromJson(json['next_episode_up'] as Map<String, dynamic>) : null),
    );
  }
}

class ContinueWatchingItem {
  final String? entryId;
  final int tmdbId;
  final String title;
  final String? posterPath;
  final String? backdropPath;
  final int currentSeason;
  final int currentEpisode;
  final int totalEpisodesWatched;
  final int? totalEpisodesCount;
  final int progressPercentage;
  final NextEpisodeUp? nextEpisodeUp;
  final DateTime lastWatchedAt;

  const ContinueWatchingItem({
    this.entryId,
    required this.tmdbId,
    required this.title,
    this.posterPath,
    this.backdropPath,
    required this.currentSeason,
    required this.currentEpisode,
    required this.totalEpisodesWatched,
    this.totalEpisodesCount,
    required this.progressPercentage,
    this.nextEpisodeUp,
    required this.lastWatchedAt,
  });

  factory ContinueWatchingItem.fromJson(Map<String, dynamic> json) {
    return ContinueWatchingItem(
      entryId: json['entryId']?.toString() ?? json['entry_id']?.toString(),
      tmdbId: (json['tmdbId'] as num?)?.toInt() ?? (json['tmdb_id'] as num?)?.toInt() ?? 0,
      title: json['title'] as String? ?? 'TV Show',
      posterPath: json['posterPath'] as String? ?? json['poster_path'] as String?,
      backdropPath: json['backdropPath'] as String? ?? json['backdrop_path'] as String?,
      currentSeason: (json['currentSeason'] as num?)?.toInt() ?? (json['current_season'] as num?)?.toInt() ?? 1,
      currentEpisode: (json['currentEpisode'] as num?)?.toInt() ?? (json['current_episode'] as num?)?.toInt() ?? 1,
      totalEpisodesWatched: (json['totalEpisodesWatched'] as num?)?.toInt() ?? (json['total_episodes_watched'] as num?)?.toInt() ?? 0,
      totalEpisodesCount: (json['totalEpisodesCount'] as num?)?.toInt() ?? (json['total_episodes_count'] as num?)?.toInt(),
      progressPercentage: (json['progressPercentage'] as num?)?.toInt() ?? (json['progress_percentage'] as num?)?.toInt() ?? 0,
      nextEpisodeUp: json['nextEpisodeUp'] != null
          ? NextEpisodeUp.fromJson(json['nextEpisodeUp'] as Map<String, dynamic>)
          : (json['next_episode_up'] != null ? NextEpisodeUp.fromJson(json['next_episode_up'] as Map<String, dynamic>) : null),
      lastWatchedAt: json['lastWatchedAt'] != null
          ? (DateTime.tryParse(json['lastWatchedAt'].toString())?.toLocal() ?? DateTime.now())
          : (json['last_watched_at'] != null ? (DateTime.tryParse(json['last_watched_at'].toString())?.toLocal() ?? DateTime.now()) : DateTime.now()),
    );
  }
}

class FriendShowProgress {
  final User user;
  final int? currentSeason;
  final int? currentEpisode;
  final int totalEpisodesWatched;
  final int? totalEpisodesCount;
  final bool isWatching;

  const FriendShowProgress({
    required this.user,
    this.currentSeason,
    this.currentEpisode,
    required this.totalEpisodesWatched,
    this.totalEpisodesCount,
    required this.isWatching,
  });

  factory FriendShowProgress.fromJson(Map<String, dynamic> json) {
    return FriendShowProgress(
      user: User.fromJson(json['user'] as Map<String, dynamic>),
      currentSeason: (json['currentSeason'] as num?)?.toInt() ?? (json['current_season'] as num?)?.toInt(),
      currentEpisode: (json['currentEpisode'] as num?)?.toInt() ?? (json['current_episode'] as num?)?.toInt(),
      totalEpisodesWatched: (json['totalEpisodesWatched'] as num?)?.toInt() ?? (json['total_episodes_watched'] as num?)?.toInt() ?? 0,
      totalEpisodesCount: (json['totalEpisodesCount'] as num?)?.toInt() ?? (json['total_episodes_count'] as num?)?.toInt(),
      isWatching: json['isWatching'] == true || json['is_watching'] == true,
    );
  }
}
