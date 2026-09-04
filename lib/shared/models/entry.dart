import 'user.dart';

class Entry {
  final String id;
  final String userId;
  final String? suggestedByUserId;
  final User? suggestedByUser;
  final int tmdbId;
  final String title;
  final String type; // MOVIE | TV_SHOW | EPISODE
  final DateTime watchedAt;
  final double? rating;
  final String? review;
  final List<String> tags;
  final bool isRewatch;
  final bool isWatching;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final String? watchLocation;
  final DateTime createdAt;
  final User? user;
  final int likesCount;
  final int commentsCount;
  final bool isLiked;
  final bool isCommented;
  final String? posterPath;
  final String? backdropPath;
  final bool isSuggestion;
  final String? suggestionReason;
  final DateTime? updatedAt;

  const Entry({
    required this.id,
    required this.userId,
    this.suggestedByUserId,
    this.suggestedByUser,
    required this.tmdbId,
    required this.title,
    required this.type,
    required this.watchedAt,
    this.rating,
    this.review,
    this.tags = const [],
    this.isRewatch = false,
    this.isWatching = false,
    this.startedAt,
    this.completedAt,
    this.watchLocation,
    required this.createdAt,
    this.updatedAt,
    this.user,
    this.likesCount = 0,
    this.commentsCount = 0,
    this.isLiked = false,
    this.isCommented = false,
    this.posterPath,
    this.backdropPath,
    this.isSuggestion = false,
    this.suggestionReason,
  });

  String get typeLabel => switch (type) {
        'MOVIE' => '🎬 Movie',
        'TV_SHOW' => '📺 TV Show',
        'EPISODE' => '📺 Episode',
        _ => type,
      };

  factory Entry.fromJson(Map<String, dynamic> json) {
    final isWrapper = json.containsKey('data') && json['data'] is Map<String, dynamic>;
    final itemType = json['type']?.toString();
    final isSuggestion = itemType == 'SUGGESTION' || json.containsKey('reason');
    final reason = json['reason']?.toString() ?? (isSuggestion ? '✨ Recommended for You' : null);

    final Map<String, dynamic> dataMap = isWrapper
        ? json['data'] as Map<String, dynamic>
        : json;

    final countData = dataMap['_count'] as Map<String, dynamic>?;
    final mediaData = dataMap['media'] is Map<String, dynamic> ? dataMap['media'] as Map<String, dynamic> : null;

    final rawTmdbId = dataMap['tmdbId'] ??
        dataMap['tmdb_id'] ??
        dataMap['mediaId'] ??
        dataMap['media_id'] ??
        mediaData?['tmdbId'] ??
        mediaData?['tmdb_id'] ??
        mediaData?['id'] ??
        (dataMap['id'] is int ? dataMap['id'] : null);
    final parsedTmdbId = rawTmdbId is int
        ? rawTmdbId
        : int.tryParse(rawTmdbId?.toString() ?? '0') ?? 0;

    final titleStr = (dataMap['title'] as String?) ??
        (dataMap['name'] as String?) ??
        (dataMap['media_title'] as String?) ??
        (mediaData?['title'] as String?) ??
        (mediaData?['name'] as String?) ??
        (mediaData?['original_title'] as String?) ??
        (mediaData?['original_name'] as String?) ??
        (dataMap['movieTitle'] as String?) ??
        'Untitled';

    final isLiked = dataMap['isLiked'] == true || json['isLiked'] == true;
    final isCommented = dataMap['isCommented'] == true || json['isCommented'] == true;

    final likes = (dataMap['likesCount'] as num?)?.toInt() ??
        (countData?['likes'] as num?)?.toInt() ??
        0;

    final comments = (dataMap['commentsCount'] as num?)?.toInt() ??
        (countData?['comments'] as num?)?.toInt() ??
        0;

    return Entry(
      id: json['id']?.toString() ?? dataMap['id']?.toString() ?? '',
      userId: dataMap['userId']?.toString() ?? '',
      suggestedByUserId: dataMap['suggestedByUserId']?.toString(),
      suggestedByUser: dataMap['suggestedByUser'] != null
          ? User.fromJson(dataMap['suggestedByUser'] as Map<String, dynamic>)
          : null,
      tmdbId: parsedTmdbId,
      title: titleStr,
      type: dataMap['type'] as String? ?? (dataMap['media_type']?.toString().toUpperCase() == 'TV' ? 'TV_SHOW' : 'MOVIE'),
      watchedAt: dataMap['watchedAt'] != null
          ? (DateTime.tryParse(dataMap['watchedAt'].toString())?.toLocal() ?? DateTime.now())
          : (json['timestamp'] != null ? (DateTime.tryParse(json['timestamp'].toString())?.toLocal() ?? DateTime.now()) : DateTime.now()),
      rating: dataMap['rating'] != null
          ? double.tryParse(dataMap['rating'].toString())
          : (dataMap['vote_average'] != null ? double.tryParse(dataMap['vote_average'].toString()) : null),
      review: dataMap['review'] as String? ?? (isSuggestion && dataMap['overview'] != null ? dataMap['overview'].toString() : null),
      tags: (dataMap['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      isRewatch: dataMap['isRewatch'] as bool? ?? false,
      isWatching: dataMap['isWatching'] as bool? ?? false,
      startedAt: dataMap['startedAt'] != null
          ? DateTime.tryParse(dataMap['startedAt'].toString())?.toLocal()
          : null,
      completedAt: dataMap['completedAt'] != null
          ? DateTime.tryParse(dataMap['completedAt'].toString())?.toLocal()
          : null,
      watchLocation: dataMap['watchLocation'] as String?,
      createdAt: dataMap['createdAt'] != null
          ? (DateTime.tryParse(dataMap['createdAt'].toString())?.toLocal() ?? DateTime.now())
          : DateTime.now(),
      user: dataMap['user'] != null
          ? User.fromJson(dataMap['user'] as Map<String, dynamic>)
          : null,
      likesCount: likes,
      commentsCount: comments,
      isLiked: isLiked,
      isCommented: isCommented,
      posterPath: (dataMap['posterPath'] as String?) ??
          (dataMap['poster_path'] as String?) ??
          (dataMap['poster'] as String?) ??
          (mediaData?['poster_path'] as String?) ??
          (mediaData?['posterPath'] as String?) ??
          (dataMap['backdropPath'] as String?) ??
          (dataMap['backdrop_path'] as String?) ??
          (mediaData?['backdrop_path'] as String?),
      backdropPath: (dataMap['backdropPath'] as String?) ??
          (dataMap['backdrop_path'] as String?) ??
          (mediaData?['backdrop_path'] as String?) ??
          (mediaData?['backdropPath'] as String?) ??
          (dataMap['posterPath'] as String?) ??
          (dataMap['poster_path'] as String?),
      isSuggestion: isSuggestion,
      suggestionReason: reason,
    );
  }

  Entry copyWith({
    String? id,
    String? userId,
    String? suggestedByUserId,
    User? suggestedByUser,
    int? tmdbId,
    String? title,
    String? type,
    DateTime? watchedAt,
    double? rating,
    String? review,
    List<String>? tags,
    bool? isRewatch,
    bool? isWatching,
    DateTime? startedAt,
    DateTime? completedAt,
    String? watchLocation,
    DateTime? createdAt,
    DateTime? updatedAt,
    User? user,
    int? likesCount,
    int? commentsCount,
    bool? isLiked,
    bool? isCommented,
    String? posterPath,
    String? backdropPath,
    bool? isSuggestion,
    String? suggestionReason,
  }) {
    return Entry(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      suggestedByUserId: suggestedByUserId ?? this.suggestedByUserId,
      suggestedByUser: suggestedByUser ?? this.suggestedByUser,
      tmdbId: tmdbId ?? this.tmdbId,
      title: title ?? this.title,
      type: type ?? this.type,
      watchedAt: watchedAt ?? this.watchedAt,
      rating: rating ?? this.rating,
      review: review ?? this.review,
      tags: tags ?? this.tags,
      isRewatch: isRewatch ?? this.isRewatch,
      isWatching: isWatching ?? this.isWatching,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      watchLocation: watchLocation ?? this.watchLocation,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      user: user ?? this.user,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      isLiked: isLiked ?? this.isLiked,
      isCommented: isCommented ?? this.isCommented,
      posterPath: posterPath ?? this.posterPath,
      backdropPath: backdropPath ?? this.backdropPath,
      isSuggestion: isSuggestion ?? this.isSuggestion,
      suggestionReason: suggestionReason ?? this.suggestionReason,
    );
  }

  Map<String, dynamic> toJson() => {
        'tmdbId': tmdbId,
        'title': title,
        'type': type,
        'watchedAt': watchedAt.toIso8601String(),
        if (rating != null) 'rating': rating,
        if (review != null) 'review': review,
        'tags': tags,
        'isRewatch': isRewatch,
        'isWatching': isWatching,
        if (startedAt != null) 'startedAt': startedAt!.toIso8601String(),
        if (completedAt != null) 'completedAt': completedAt!.toIso8601String(),
        if (watchLocation != null) 'watchLocation': watchLocation,
        if (suggestedByUserId != null) 'suggestedByUserId': suggestedByUserId,
      };
}
