import 'user.dart';

class Suggestion {
  final String id;
  final String fromUserId;
  final String toUserId;
  final int tmdbId;
  final String mediaType;
  final String? message;
  final String status;
  final String createdAt;

  Suggestion({
    required this.id,
    required this.fromUserId,
    required this.toUserId,
    required this.tmdbId,
    required this.mediaType,
    this.message,
    required this.status,
    required this.createdAt,
  });

  factory Suggestion.fromJson(Map<String, dynamic> json) {
    return Suggestion(
      id: json['id']?.toString() ?? '',
      fromUserId: json['fromUserId']?.toString() ?? '',
      toUserId: json['toUserId']?.toString() ?? '',
      tmdbId: (json['tmdbId'] as num?)?.toInt() ?? 0,
      mediaType: json['mediaType']?.toString() ?? 'movie',
      message: json['message']?.toString(),
      status: json['status']?.toString() ?? 'pending',
      createdAt: json['createdAt']?.toString() ?? '',
    );
  }
}

class GroupedSuggestion {
  final int tmdbId;
  final String mediaType;
  final List<Suggestion> suggestions;
  final List<User> suggestors;

  GroupedSuggestion({
    required this.tmdbId,
    required this.mediaType,
    required this.suggestions,
    required this.suggestors,
  });

  factory GroupedSuggestion.fromJson(Map<String, dynamic> json) {
    return GroupedSuggestion(
      tmdbId: (json['tmdbId'] as num?)?.toInt() ?? 0,
      mediaType: json['mediaType']?.toString() ?? 'movie',
      suggestions: (json['suggestions'] as List<dynamic>?)
              ?.map((s) => Suggestion.fromJson(s as Map<String, dynamic>))
              .toList() ??
          [],
      suggestors: (json['suggestors'] as List<dynamic>?)
              ?.map((u) => User.fromJson(u as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}
