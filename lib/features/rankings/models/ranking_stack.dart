class RankedItem {
  final String id;
  final String listId;
  final int tmdbId;
  final String mediaType;
  final int orderIndex;
  final String? title;
  final String? posterPath;
  final String? releaseDate;
  final double? voteAverage;
  final double? localRating;
  final String? localReview;
  final List<String> tags;
  final DateTime? watchedAt;
  final DateTime? addedAt;
  final String? suggestedByUserId;

  const RankedItem({
    required this.id,
    required this.listId,
    required this.tmdbId,
    this.mediaType = 'movie',
    required this.orderIndex,
    this.title,
    this.posterPath,
    this.releaseDate,
    this.voteAverage,
    this.localRating,
    this.localReview,
    this.tags = const [],
    this.watchedAt,
    this.addedAt,
    this.suggestedByUserId,
  });

  String get year {
    if (releaseDate != null && releaseDate!.length >= 4) {
      return releaseDate!.substring(0, 4);
    }
    return '';
  }

  factory RankedItem.fromJson(Map<String, dynamic> json) {
    double? parseDouble(dynamic val) {
      if (val == null) return null;
      if (val is num) return val.toDouble();
      if (val is String) return double.tryParse(val);
      return null;
    }

    return RankedItem(
      id: json['id'] as String? ?? '',
      listId: json['listId'] as String? ?? '',
      tmdbId: (json['tmdbId'] as num?)?.toInt() ?? 0,
      mediaType: json['mediaType'] as String? ?? 'movie',
      orderIndex: (json['orderIndex'] as num?)?.toInt() ?? 0,
      title: json['title'] as String?,
      posterPath: json['posterPath'] as String?,
      releaseDate: json['releaseDate'] as String?,
      voteAverage: parseDouble(json['voteAverage']),
      localRating: parseDouble(json['localRating']),
      localReview: json['localReview'] as String?,
      tags: (json['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      watchedAt: json['watchedAt'] != null ? DateTime.tryParse(json['watchedAt'].toString()) : null,
      addedAt: json['addedAt'] != null ? DateTime.tryParse(json['addedAt'].toString()) : null,
      suggestedByUserId: json['suggestedByUserId'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'listId': listId,
        'tmdbId': tmdbId,
        'mediaType': mediaType,
        'orderIndex': orderIndex,
        'title': title,
        'posterPath': posterPath,
        'releaseDate': releaseDate,
        'voteAverage': voteAverage,
        'localRating': localRating,
        'localReview': localReview,
        'tags': tags,
        'watchedAt': watchedAt?.toIso8601String(),
        'addedAt': addedAt?.toIso8601String(),
        'suggestedByUserId': suggestedByUserId,
      };

  RankedItem copyWith({
    String? id,
    String? listId,
    int? tmdbId,
    String? mediaType,
    int? orderIndex,
    String? title,
    String? posterPath,
    String? releaseDate,
    double? voteAverage,
    double? localRating,
    String? localReview,
    List<String>? tags,
    DateTime? watchedAt,
    DateTime? addedAt,
    String? suggestedByUserId,
  }) =>
      RankedItem(
        id: id ?? this.id,
        listId: listId ?? this.listId,
        tmdbId: tmdbId ?? this.tmdbId,
        mediaType: mediaType ?? this.mediaType,
        orderIndex: orderIndex ?? this.orderIndex,
        title: title ?? this.title,
        posterPath: posterPath ?? this.posterPath,
        releaseDate: releaseDate ?? this.releaseDate,
        voteAverage: voteAverage ?? this.voteAverage,
        localRating: localRating ?? this.localRating,
        localReview: localReview ?? this.localReview,
        tags: tags ?? this.tags,
        watchedAt: watchedAt ?? this.watchedAt,
        addedAt: addedAt ?? this.addedAt,
        suggestedByUserId: suggestedByUserId ?? this.suggestedByUserId,
      );
}

class RankingStack {
  final String id;
  final String userId;
  final String name;
  final String? description;
  final String type;
  final bool isPublic;
  final List<RankedItem> items;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const RankingStack({
    required this.id,
    required this.userId,
    required this.name,
    this.description,
    this.type = 'RANKING_STACK',
    this.isPublic = true,
    this.items = const [],
    this.createdAt,
    this.updatedAt,
  });

  factory RankingStack.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? [];
    final parsedItems = rawItems
        .map((e) => RankedItem.fromJson(e as Map<String, dynamic>))
        .toList();

    return RankingStack(
      id: json['id'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      name: json['name'] as String? ?? 'Untitled Stack',
      description: json['description'] as String?,
      type: json['type'] as String? ?? 'RANKING_STACK',
      isPublic: json['isPublic'] as bool? ?? true,
      items: parsedItems,
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'name': name,
        'description': description,
        'type': type,
        'isPublic': isPublic,
        'items': items.map((e) => e.toJson()).toList(),
        'createdAt': createdAt?.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
      };

  RankingStack copyWith({
    String? id,
    String? userId,
    String? name,
    String? description,
    String? type,
    bool? isPublic,
    List<RankedItem>? items,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      RankingStack(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        name: name ?? this.name,
        description: description ?? this.description,
        type: type ?? this.type,
        isPublic: isPublic ?? this.isPublic,
        items: items ?? this.items,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}
