// User Model
class User {
  final String id;
  final String username;
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
  final DateTime createdAt;

  const User({
    required this.id,
    required this.username,
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
    required this.createdAt,
  });

  String get name => displayName ?? username;

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] as String,
        username: json['username'] as String,
        displayName: json['displayName'] as String?,
        profilePictureUrl: json['profilePictureUrl'] as String?,
        bio: json['bio'] as String?,
        location: json['location'] as String?,
        isPrivate: json['isPrivate'] as bool? ?? false,
        privacyLevel: json['privacyLevel'] as String? ?? 'PUBLIC',
        showWatchEntries: json['showWatchEntries'] as bool? ?? true,
        showCurrentlyWatching: json['showCurrentlyWatching'] as bool? ?? true,
        showWatchlist: json['showWatchlist'] as bool? ?? true,
        showRankings: json['showRankings'] as bool? ?? true,
        xp: json['xp'] as int? ?? 0,
        level: json['level'] as int? ?? 1,
        badges: json['badges'] as List<dynamic>? ?? [],
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
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
        'createdAt': createdAt.toIso8601String(),
      };
}
