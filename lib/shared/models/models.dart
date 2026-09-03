class Notification {
  final String id;
  final String userId;
  final String type;
  final Map<String, dynamic> content;
  final bool isRead;
  final DateTime createdAt;

  const Notification({
    required this.id,
    required this.userId,
    required this.type,
    required this.content,
    this.isRead = false,
    required this.createdAt,
  });

  factory Notification.fromJson(Map<String, dynamic> json) => Notification(
        id: json['id'] as String,
        userId: json['userId'] as String,
        type: json['type'] as String,
        content: json['content'] as Map<String, dynamic>,
        isRead: json['isRead'] as bool? ?? false,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}

class MediaResult {
  final int id;
  final String title;
  final String? posterPath;
  final String? releaseDate;
  final String? overview;
  final String mediaType; // movie | tv
  final double? voteAverage;

  const MediaResult({
    required this.id,
    required this.title,
    this.posterPath,
    this.releaseDate,
    this.overview,
    required this.mediaType,
    this.voteAverage,
  });

  factory MediaResult.fromJson(Map<String, dynamic> json) => MediaResult(
        id: (json['id'] as num?)?.toInt() ?? 0,
        title: (json['title'] ??
                json['name'] ??
                json['original_title'] ??
                json['original_name'] ??
                'Untitled')
            .toString(),
        posterPath: (json['poster_path'] as String?) ??
            (json['backdrop_path'] as String?),
        releaseDate:
            (json['release_date'] ?? json['first_air_date']) as String?,
        overview: json['overview'] as String?,
        mediaType: json['media_type'] as String? ?? 'movie',
        voteAverage: (json['vote_average'] as num?)?.toDouble(),
      );


  String get year {
    if (releaseDate == null || releaseDate!.isEmpty) return '';
    return releaseDate!.substring(0, 4);
  }
}

class Pagination {
  final int total;
  final int limit;
  final int offset;
  final bool hasMore;

  const Pagination({
    required this.total,
    required this.limit,
    required this.offset,
    required this.hasMore,
  });

  factory Pagination.fromJson(Map<String, dynamic> json) => Pagination(
        total: json['total'] as int,
        limit: json['limit'] as int,
        offset: json['offset'] as int,
        hasMore: json['hasMore'] as bool,
      );
}
