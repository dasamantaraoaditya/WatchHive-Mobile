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
  final User? recipient;

  Suggestion({
    required this.id,
    required this.fromUserId,
    required this.toUserId,
    required this.tmdbId,
    required this.mediaType,
    this.message,
    required this.status,
    required this.createdAt,
    this.recipient,
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
      recipient: json['recipient'] != null
          ? User.fromJson(json['recipient'] as Map<String, dynamic>)
          : null,
    );
  }
}

class GroupedSuggestion {
  final int tmdbId;
  final String mediaType;
  final List<Suggestion> suggestions;
  final List<User> suggestors;
  final List<User> recipients;

  GroupedSuggestion({
    required this.tmdbId,
    required this.mediaType,
    required this.suggestions,
    required this.suggestors,
    this.recipients = const [],
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
      recipients: (json['recipients'] as List<dynamic>?)
              ?.map((u) => User.fromJson(u as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}
