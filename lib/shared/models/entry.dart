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
    this.user,
    this.likesCount = 0,
    this.commentsCount = 0,
  });

  String get typeLabel => switch (type) {
        'MOVIE' => '🎬 Movie',
        'TV_SHOW' => '📺 TV Show',
        'EPISODE' => '📺 Episode',
        _ => type,
      };

  factory Entry.fromJson(Map<String, dynamic> json) {
    final countData = json['_count'] as Map<String, dynamic>?;
    return Entry(
      id: json['id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      suggestedByUserId: json['suggestedByUserId']?.toString(),
      suggestedByUser: json['suggestedByUser'] != null
          ? User.fromJson(json['suggestedByUser'] as Map<String, dynamic>)
          : null,
      tmdbId: json['tmdbId'] is int ? json['tmdbId'] as int : int.tryParse(json['tmdbId']?.toString() ?? '0') ?? 0,
      title: json['title'] as String? ?? 'Untitled',
      type: json['type'] as String? ?? 'MOVIE',
      watchedAt: json['watchedAt'] != null
          ? DateTime.tryParse(json['watchedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      rating: json['rating'] != null
          ? double.tryParse(json['rating'].toString())
          : null,
      review: json['review'] as String?,
      tags: (json['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      isRewatch: json['isRewatch'] as bool? ?? false,
      isWatching: json['isWatching'] as bool? ?? false,
      startedAt: json['startedAt'] != null
          ? DateTime.tryParse(json['startedAt'].toString())
          : null,
      completedAt: json['completedAt'] != null
          ? DateTime.tryParse(json['completedAt'].toString())
          : null,
      watchLocation: json['watchLocation'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      user: json['user'] != null
          ? User.fromJson(json['user'] as Map<String, dynamic>)
          : null,
      likesCount: json['likesCount'] as int? ?? countData?['likes'] as int? ?? 0,
      commentsCount: json['commentsCount'] as int? ?? countData?['comments'] as int? ?? 0,
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
