import 'user.dart';

class SmartSuggestBadge {
  final String type;
  final String label;
  final String? avatarUrl;
  final String? meta;

  const SmartSuggestBadge({
    required this.type,
    required this.label,
    this.avatarUrl,
    this.meta,
  });

  factory SmartSuggestBadge.fromJson(Map<String, dynamic> json) {
    return SmartSuggestBadge(
      type: json['type']?.toString() ?? 'taste_match',
      label: json['label']?.toString() ?? '',
      avatarUrl: json['avatarUrl']?.toString(),
      meta: json['meta']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'type': type,
    'label': label,
    if (avatarUrl != null) 'avatarUrl': avatarUrl,
    if (meta != null) 'meta': meta,
  };
}

class SmartSuggestItem {
  final int tmdbId;
  final String title;
  final String mediaType;
  final String? posterPath;
  final String? backdropPath;
  final String? overview;
  final String? releaseDate;
  final double voteAverage;
  final int voteCount;
  final int score;
  final List<SmartSuggestBadge> badges;
  final List<String> genreNames;
  final User? suggestedBy;

  const SmartSuggestItem({
    required this.tmdbId,
    required this.title,
    required this.mediaType,
    this.posterPath,
    this.backdropPath,
    this.overview,
    this.releaseDate,
    required this.voteAverage,
    required this.voteCount,
    required this.score,
    required this.badges,
    required this.genreNames,
    this.suggestedBy,
  });

  factory SmartSuggestItem.fromJson(Map<String, dynamic> json) {
    return SmartSuggestItem(
      tmdbId: (json['tmdbId'] as num?)?.toInt() ?? 0,
      title: json['title']?.toString() ?? '',
      mediaType: json['mediaType']?.toString() ?? 'movie',
      posterPath: json['posterPath']?.toString(),
      backdropPath: json['backdropPath']?.toString(),
      overview: json['overview']?.toString(),
      releaseDate: json['releaseDate']?.toString(),
      voteAverage: (json['voteAverage'] as num?)?.toDouble() ?? 0.0,
      voteCount: (json['voteCount'] as num?)?.toInt() ?? 0,
      score: (json['score'] as num?)?.toInt() ?? 0,
      badges: (json['badges'] as List<dynamic>?)
              ?.map((b) => SmartSuggestBadge.fromJson(b as Map<String, dynamic>))
              .toList() ??
          const [],
      genreNames: (json['genreNames'] as List<dynamic>?)
              ?.map((g) => g.toString())
              .toList() ??
          const [],
      suggestedBy: json['suggestedBy'] != null
          ? User.fromJson(json['suggestedBy'] as Map<String, dynamic>)
          : null,
    );
  }
}

class SmartSuggestResponse {
  final String mode;
  final List<SmartSuggestItem> items;
  final String? lastWatchedTitle;
  final String? lastWatchedGenre;

  const SmartSuggestResponse({
    required this.mode,
    required this.items,
    this.lastWatchedTitle,
    this.lastWatchedGenre,
  });

  factory SmartSuggestResponse.fromJson(Map<String, dynamic> json) {
    return SmartSuggestResponse(
      mode: json['mode']?.toString() ?? 'social',
      items: (json['items'] as List<dynamic>?)
              ?.map((it) => SmartSuggestItem.fromJson(it as Map<String, dynamic>))
              .toList() ??
          const [],
      lastWatchedTitle: json['lastWatchedTitle']?.toString(),
      lastWatchedGenre: json['lastWatchedGenre']?.toString(),
    );
  }
}
