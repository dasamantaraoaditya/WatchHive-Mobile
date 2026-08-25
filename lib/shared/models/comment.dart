import 'user.dart';

class Comment {
  final String id;
  final String content;
  final String userId;
  final String entryId;
  final String? parentCommentId;
  final DateTime createdAt;
  final User? user;
  final List<Comment> replies;

  const Comment({
    required this.id,
    required this.content,
    required this.userId,
    required this.entryId,
    this.parentCommentId,
    required this.createdAt,
    this.user,
    this.replies = const [],
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    final rawUser = json['user'] as Map<String, dynamic>?;
    final rawReplies = json['replies'] as List<dynamic>? ?? [];

    return Comment(
      id: json['id']?.toString() ?? '',
      content: json['content'] as String? ?? '',
      userId: json['userId']?.toString() ?? rawUser?['id']?.toString() ?? '',
      entryId: json['entryId']?.toString() ?? '',
      parentCommentId: json['parentCommentId']?.toString(),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      user: rawUser != null ? User.fromJson(rawUser) : null,
      replies: rawReplies
          .whereType<Map<String, dynamic>>()
          .map((r) => Comment.fromJson(r))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'content': content,
        'userId': userId,
        'entryId': entryId,
        if (parentCommentId != null) 'parentCommentId': parentCommentId,
        'createdAt': createdAt.toIso8601String(),
        if (user != null) 'user': user!.toJson(),
      };
}
