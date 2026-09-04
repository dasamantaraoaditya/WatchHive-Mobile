// User Model
class User {
  final String id;
  final String username;
  final String? email;
  final String? displayName;
  final String? profilePictureUrl;
  final String? bio;
  final String? location;
  final bool isPrivate;
  final String privacyLevel;
  final int xp;
  final int level;
  final bool showWatchEntries;
  final bool showCurrentlyWatching;
  final bool showWatchlist;
  final bool showRankings;
  final List<dynamic> badges;
  final int entriesCount;
  final int followersCount;
  final int followingCount;
  final bool isFollowing;
  final bool isRequested;
  final bool isIncomingRequest;
  final String? incomingRequestId;
  final bool hasGoogleLinked;
  final bool hasPassword;
  final DateTime createdAt;

  const User({
    required this.id,
    required this.username,
    this.email,
    this.displayName,
    this.profilePictureUrl,
    this.bio,
    this.location,
    this.isPrivate = false,
    this.privacyLevel = 'PUBLIC',
    this.showWatchEntries = true,
    this.showCurrentlyWatching = true,
    this.showWatchlist = true,
    this.showRankings = true,
    this.xp = 0,
    this.level = 1,
    this.badges = const [],
    this.entriesCount = 0,
    this.followersCount = 0,
    this.followingCount = 0,
    this.isFollowing = false,
    this.isRequested = false,
    this.isIncomingRequest = false,
    this.incomingRequestId,
    this.hasGoogleLinked = false,
    this.hasPassword = true,
    required this.createdAt,
  });

  String get name => (displayName != null && displayName!.trim().isNotEmpty) ? displayName! : username;
  String? get displayLocation => (location != null && location!.trim().isNotEmpty) ? location!.trim() : null;

  static int _parseInt(dynamic val) {
    if (val == null) return 0;
    if (val is num) return val.toInt();
    if (val is String) {
      return int.tryParse(val) ?? (double.tryParse(val)?.toInt() ?? 0);
    }
    return 0;
  }

  factory User.fromJson(Map<String, dynamic> json) {
    final countData = json['_count'] is Map ? json['_count'] as Map : null;

    final rawLocation = json['location'] ?? (json['profile'] is Map ? json['profile']['location'] : null);
    final parsedLocation = rawLocation is String
        ? (rawLocation.trim().isNotEmpty ? rawLocation.trim() : null)
        : (rawLocation is Map
            ? (rawLocation['name'] ?? rawLocation['city'] ?? rawLocation.values.firstOrNull)?.toString().trim()
            : (rawLocation != null && rawLocation.toString().trim().isNotEmpty ? rawLocation.toString().trim() : null));

    return User(
      id: json['id']?.toString() ?? '',
      username: json['username'] as String? ?? '',
      email: json['email'] as String?,
      displayName: json['displayName'] as String?,
      profilePictureUrl: json['profilePictureUrl'] as String?,
      bio: json['bio'] as String?,
      location: parsedLocation,
      isPrivate: json['isPrivate'] as bool? ?? false,
      privacyLevel: json['privacyLevel'] as String? ?? 'PUBLIC',
      showWatchEntries: json['showWatchEntries'] as bool? ?? true,
      showCurrentlyWatching: json['showCurrentlyWatching'] as bool? ?? true,
      showWatchlist: json['showWatchlist'] as bool? ?? true,
      showRankings: json['showRankings'] as bool? ?? true,
      xp: _parseInt(json['xp']),
      level: _parseInt(json['level']) > 0 ? _parseInt(json['level']) : 1,
      badges: json['badges'] as List<dynamic>? ?? [],
      entriesCount: _parseInt(
        countData?['entries'] ?? countData?['entriesCount'] ?? json['entriesCount'] ?? json['entries'],
      ),
      followersCount: _parseInt(
        countData?['followers'] ?? countData?['followersCount'] ?? json['followersCount'] ?? json['followers'],
      ),
      followingCount: _parseInt(
        countData?['following'] ?? countData?['followingCount'] ?? json['followingCount'] ?? json['following'],
      ),
      isFollowing: json['isFollowing'] as bool? ?? false,
      isRequested: json['isRequested'] as bool? ?? false,
      isIncomingRequest: json['isIncomingRequest'] as bool? ?? false,
      incomingRequestId: json['incomingRequestId']?.toString(),
      hasGoogleLinked: json['hasGoogleLinked'] as bool? ?? false,
      hasPassword: json['hasPassword'] as bool? ?? true,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        if (email != null) 'email': email,
        'displayName': displayName,
        'profilePictureUrl': profilePictureUrl,
        'bio': bio,
        'location': location,
        'isPrivate': isPrivate,
        'privacyLevel': privacyLevel,
        'showWatchEntries': showWatchEntries,
        'showCurrentlyWatching': showCurrentlyWatching,
        'showWatchlist': showWatchlist,
        'showRankings': showRankings,
        'xp': xp,
        'level': level,
        'badges': badges,
        'entriesCount': entriesCount,
        'followersCount': followersCount,
        'followingCount': followingCount,
        'createdAt': createdAt.toIso8601String(),
      };

  User copyWith({
    String? id,
    String? username,
    String? email,
    String? displayName,
    String? profilePictureUrl,
    bool clearProfilePicture = false,
    String? bio,
    String? location,
    bool? isPrivate,
    String? privacyLevel,
    int? xp,
    int? level,
    bool? showWatchEntries,
    bool? showCurrentlyWatching,
    bool? showWatchlist,
    bool? showRankings,
    List<dynamic>? badges,
    int? entriesCount,
    int? followersCount,
    int? followingCount,
    bool? isFollowing,
    bool? isRequested,
    bool? isIncomingRequest,
    String? incomingRequestId,
    bool? hasGoogleLinked,
    bool? hasPassword,
    DateTime? createdAt,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      profilePictureUrl: clearProfilePicture ? null : (profilePictureUrl ?? this.profilePictureUrl),
      bio: bio ?? this.bio,
      location: location ?? this.location,
      isPrivate: isPrivate ?? this.isPrivate,
      privacyLevel: privacyLevel ?? this.privacyLevel,
      xp: xp ?? this.xp,
      level: level ?? this.level,
      showWatchEntries: showWatchEntries ?? this.showWatchEntries,
      showCurrentlyWatching: showCurrentlyWatching ?? this.showCurrentlyWatching,
      showWatchlist: showWatchlist ?? this.showWatchlist,
      showRankings: showRankings ?? this.showRankings,
      badges: badges ?? this.badges,
      entriesCount: entriesCount ?? this.entriesCount,
      followersCount: followersCount ?? this.followersCount,
      followingCount: followingCount ?? this.followingCount,
      isFollowing: isFollowing ?? this.isFollowing,
      isRequested: isRequested ?? this.isRequested,
      isIncomingRequest: isIncomingRequest ?? this.isIncomingRequest,
      incomingRequestId: incomingRequestId ?? this.incomingRequestId,
      hasGoogleLinked: hasGoogleLinked ?? this.hasGoogleLinked,
      hasPassword: hasPassword ?? this.hasPassword,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
