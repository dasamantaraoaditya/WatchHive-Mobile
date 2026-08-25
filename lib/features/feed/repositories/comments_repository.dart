import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../shared/models/comment.dart';

final commentsRepositoryProvider = Provider<CommentsRepository>((ref) {
  return CommentsRepository(ref.read(apiClientProvider));
});

class CommentsRepository {
  final ApiClient _api;

  CommentsRepository(this._api);

  Future<List<Comment>> getComments(String entryId) async {
    final response = await _api.get(ApiEndpoints.comments(entryId));
    final data = response.data as Map<String, dynamic>;
    final rawList = data['comments'] as List<dynamic>? ?? [];

    return rawList
        .whereType<Map<String, dynamic>>()
        .map((json) => Comment.fromJson(json))
        .toList();
  }

  Future<({Comment comment, int commentCount})> addComment(
    String entryId,
    String content, {
    String? parentCommentId,
  }) async {
    final response = await _api.post(
      ApiEndpoints.comments(entryId),
      data: {
        'content': content.trim(),
        if (parentCommentId != null) 'parentCommentId': parentCommentId,
      },
    );

    final data = response.data as Map<String, dynamic>;
    final commentJson = data['comment'] as Map<String, dynamic>;
    final comment = Comment.fromJson(commentJson);
    final count = (data['commentCount'] as num?)?.toInt() ?? 0;

    return (comment: comment, commentCount: count);
  }

  Future<int> deleteComment(String commentId) async {
    final response = await _api.delete(ApiEndpoints.comment(commentId));
    final data = response.data as Map<String, dynamic>;
    return (data['commentCount'] as num?)?.toInt() ?? 0;
  }
}
