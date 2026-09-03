import '../../../shared/models/user.dart';

class CompareUserSummary {
  final String id;
  final String username;
  final String displayName;
  final String? profilePictureUrl;

  const CompareUserSummary({
    required this.id,
    required this.username,
    required this.displayName,
    this.profilePictureUrl,
  });

  factory CompareUserSummary.fromJson(Map<String, dynamic> json) {
    return CompareUserSummary(
      id: json['id']?.toString() ?? '',
      username: json['username']?.toString() ?? 'user',
      displayName: json['displayName']?.toString() ?? json['name']?.toString() ?? json['username']?.toString() ?? 'User',
      profilePictureUrl: json['profilePictureUrl']?.toString() ?? json['avatarUrl']?.toString(),
    );
  }

  User toUser() {
    return User(
      id: id,
      username: username,
      displayName: displayName,
      profilePictureUrl: profilePictureUrl,
      email: '',
      createdAt: DateTime.now(),
    );
  }
}

class CompareStats {
  final int matchPercentage;
  final int totalCommon;
  final int totalUserAOnly;
  final int totalUserBOnly;
  final int totalUnique;

  const CompareStats({
    this.matchPercentage = 0,
    this.totalCommon = 0,
    this.totalUserAOnly = 0,
    this.totalUserBOnly = 0,
    this.totalUnique = 0,
  });

  factory CompareStats.fromJson(Map<String, dynamic> json) {
    return CompareStats(
      matchPercentage: (json['matchPercentage'] as num?)?.toInt() ??
          (json['overlapScore'] as num?)?.toInt() ??
          (json['overlapPercentage'] as num?)?.toInt() ??
          0,
      totalCommon: (json['totalCommon'] as num?)?.toInt() ??
          (json['sharedCount'] as num?)?.toInt() ??
          0,
      totalUserAOnly: (json['totalUserAOnly'] as num?)?.toInt() ?? 0,
      totalUserBOnly: (json['totalUserBOnly'] as num?)?.toInt() ?? 0,
      totalUnique: (json['totalUnique'] as num?)?.toInt() ?? 0,
    );
  }
}

class CompareEntryDetails {
  final String? id;
  final double? rating;
  final String? review;
  final String? watchedAt;

  const CompareEntryDetails({
    this.id,
    this.rating,
    this.review,
    this.watchedAt,
  });

  factory CompareEntryDetails.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const CompareEntryDetails();
    return CompareEntryDetails(
      id: json['id']?.toString(),
      rating: json['rating'] is num
          ? (json['rating'] as num).toDouble()
          : (json['rating'] is String ? double.tryParse(json['rating'] as String) : null),
      review: json['review']?.toString(),
      watchedAt: json['watchedAt']?.toString(),
    );
  }
}

class CommonItem {
  final int tmdbId;
  final String title;
  final String type;
  final CompareEntryDetails entryA;
  final CompareEntryDetails entryB;
  final String? posterPath;

  const CommonItem({
    required this.tmdbId,
    required this.title,
    required this.type,
    required this.entryA,
    required this.entryB,
    this.posterPath,
  });

  factory CommonItem.fromJson(Map<String, dynamic> json) {
    return CommonItem(
      tmdbId: (json['tmdbId'] as num?)?.toInt() ?? 0,
      title: json['title']?.toString() ?? 'Media #${json['tmdbId']}',
      type: (json['type']?.toString() ?? json['mediaType']?.toString() ?? 'MOVIE').toUpperCase(),
      entryA: CompareEntryDetails.fromJson(json['entryA'] as Map<String, dynamic>?),
      entryB: CompareEntryDetails.fromJson(json['entryB'] as Map<String, dynamic>?),
      posterPath: json['posterPath']?.toString() ?? json['poster_path']?.toString(),
    );
  }

  CommonItem copyWith({String? posterPath, String? title}) {
    return CommonItem(
      tmdbId: tmdbId,
      title: title ?? this.title,
      type: type,
      entryA: entryA,
      entryB: entryB,
      posterPath: posterPath ?? this.posterPath,
    );
  }
}

class SingleItem {
  final int tmdbId;
  final String title;
  final String type;
  final double? rating;
  final String? watchedAt;
  final String? posterPath;

  const SingleItem({
    required this.tmdbId,
    required this.title,
    required this.type,
    this.rating,
    this.watchedAt,
    this.posterPath,
  });

  factory SingleItem.fromJson(Map<String, dynamic> json) {
    return SingleItem(
      tmdbId: (json['tmdbId'] as num?)?.toInt() ?? 0,
      title: json['title']?.toString() ?? 'Media #${json['tmdbId']}',
      type: (json['type']?.toString() ?? json['mediaType']?.toString() ?? 'MOVIE').toUpperCase(),
      rating: json['rating'] is num
          ? (json['rating'] as num).toDouble()
          : (json['rating'] is String ? double.tryParse(json['rating'] as String) : null),
      watchedAt: json['watchedAt']?.toString(),
      posterPath: json['posterPath']?.toString() ?? json['poster_path']?.toString(),
    );
  }

  SingleItem copyWith({String? posterPath, String? title}) {
    return SingleItem(
      tmdbId: tmdbId,
      title: title ?? this.title,
      type: type,
      rating: rating,
      watchedAt: watchedAt,
      posterPath: posterPath ?? this.posterPath,
    );
  }
}

class CompareResult {
  final CompareUserSummary userA;
  final CompareUserSummary userB;
  final CompareStats stats;
  final List<CommonItem> commonItems;
  final List<SingleItem> userAOnlyItems;
  final List<SingleItem> userBOnlyItems;

  const CompareResult({
    required this.userA,
    required this.userB,
    required this.stats,
    required this.commonItems,
    required this.userAOnlyItems,
    required this.userBOnlyItems,
  });

  factory CompareResult.fromJson(Map<String, dynamic> json) {
    final userAJson = json['userA'] as Map<String, dynamic>? ??
        json['currentUser'] as Map<String, dynamic>? ??
        <String, dynamic>{};
    final userBJson = json['userB'] as Map<String, dynamic>? ??
        json['user2'] as Map<String, dynamic>? ??
        json['targetUser'] as Map<String, dynamic>? ??
        json['otherUser'] as Map<String, dynamic>? ??
        <String, dynamic>{};

    final statsJson = json['stats'] as Map<String, dynamic>? ?? <String, dynamic>{};

    final rawCommon = (json['commonItems'] ?? json['sharedEntries'] ?? json['commonEntries'] ?? json['shared']) as List<dynamic>? ?? [];
    final rawUserA = (json['userAOnlyItems'] ?? json['userAOnly']) as List<dynamic>? ?? [];
    final rawUserB = (json['userBOnlyItems'] ?? json['userBOnly']) as List<dynamic>? ?? [];

    return CompareResult(
      userA: CompareUserSummary.fromJson(userAJson),
      userB: CompareUserSummary.fromJson(userBJson),
      stats: CompareStats.fromJson(statsJson),
      commonItems: rawCommon.map((e) => CommonItem.fromJson(e as Map<String, dynamic>)).toList(),
      userAOnlyItems: rawUserA.map((e) => SingleItem.fromJson(e as Map<String, dynamic>)).toList(),
      userBOnlyItems: rawUserB.map((e) => SingleItem.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}
