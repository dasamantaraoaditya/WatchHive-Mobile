import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/models/comment.dart';
import '../../../shared/widgets/shared_widgets.dart';
import '../../auth/providers/auth_provider.dart';
import '../repositories/comments_repository.dart';

class CommentsSheet extends ConsumerStatefulWidget {
  final String entryId;
  final String? entryTitle;
  final String? entryAuthorId;
  final Function(int count)? onCommentCountChanged;

  const CommentsSheet({
    super.key,
    required this.entryId,
    this.entryTitle,
    this.entryAuthorId,
    this.onCommentCountChanged,
  });

  static Future<void> show(
    BuildContext context, {
    required String entryId,
    String? entryTitle,
    String? entryAuthorId,
    Function(int count)? onCommentCountChanged,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CommentsSheet(
        entryId: entryId,
        entryTitle: entryTitle,
        entryAuthorId: entryAuthorId,
        onCommentCountChanged: onCommentCountChanged,
      ),
    );
  }

  @override
  ConsumerState<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends ConsumerState<CommentsSheet> {
  final _textController = TextEditingController();
  final _focusNode = FocusNode();
  List<Comment> _comments = [];
  bool _isLoading = true;
  bool _isSubmitting = false;
  Comment? _replyingToComment;

  @override
  void initState() {
    super.initState();
    _fetchComments();
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _fetchComments() async {
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(commentsRepositoryProvider);
      final items = await repo.getComments(widget.entryId);
      if (mounted) {
        setState(() {
          _comments = items;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleSubmit() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _isSubmitting) return;

    setState(() => _isSubmitting = true);
    try {
      final repo = ref.read(commentsRepositoryProvider);
      final result = await repo.addComment(
        widget.entryId,
        text,
        parentCommentId: _replyingToComment?.id,
      );

      _textController.clear();
      _focusNode.unfocus();

      if (mounted) {
        setState(() {
          if (_replyingToComment != null) {
            // Append reply to the targeted parent comment
            final parentId = _replyingToComment!.id;
            _comments = _comments.map((c) {
              if (c.id == parentId) {
                return Comment(
                  id: c.id,
                  content: c.content,
                  userId: c.userId,
                  entryId: c.entryId,
                  parentCommentId: c.parentCommentId,
                  createdAt: c.createdAt,
                  user: c.user,
                  replies: [...c.replies, result.comment],
                );
              }
              return c;
            }).toList();
            _replyingToComment = null;
          } else {
            _comments = [result.comment, ..._comments];
          }
          _isSubmitting = false;
        });

        widget.onCommentCountChanged?.call(result.commentCount);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        WHAlert.showError(context, 'Failed to post comment: $e');
      }
    }
  }

  Future<void> _handleDeleteComment(Comment comment, {bool isReply = false, String? parentId}) async {
    final confirm = await WHAlert.confirm(
      context,
      title: isReply ? 'Delete Reply' : 'Delete Comment',
      message: 'Are you sure you want to delete this comment? This action cannot be undone.',
      confirmText: 'Delete',
      severity: WHAlertSeverity.danger,
      icon: Icons.delete_outline_rounded,
    );

    if (!confirm) return;

    try {
      final repo = ref.read(commentsRepositoryProvider);
      final newCount = await repo.deleteComment(comment.id);

      if (mounted) {
        setState(() {
          if (isReply && parentId != null) {
            _comments = _comments.map((c) {
              if (c.id == parentId) {
                return Comment(
                  id: c.id,
                  content: c.content,
                  userId: c.userId,
                  entryId: c.entryId,
                  parentCommentId: c.parentCommentId,
                  createdAt: c.createdAt,
                  user: c.user,
                  replies: c.replies.where((r) => r.id != comment.id).toList(),
                );
              }
              return c;
            }).toList();
          } else {
            _comments = _comments.where((c) => c.id != comment.id).toList();
          }
        });

        widget.onCommentCountChanged?.call(newCount);
        WHAlert.showSuccess(context, 'Comment deleted');
      }
    } catch (e) {
      if (mounted) {
        WHAlert.showError(context, 'Failed to delete comment: $e');
      }
    }
  }


  void _startReply(Comment comment) {
    setState(() => _replyingToComment = comment);
    _focusNode.requestFocus();
  }

  String _formatRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return DateFormat.MMMd().format(dateTime);
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = ref.watch(authStateProvider).value?.user?.id;
    final totalComments = _comments.fold<int>(
      _comments.length,
      (sum, c) => sum + c.replies.length,
    );

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.chat_bubble_rounded, color: AppColors.primaryDark, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Discussion',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceHighest,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$totalComments',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (widget.entryTitle != null)
                        Text(
                          widget.entryTitle!,
                          style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: AppColors.textMuted),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),

          // Discussion List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _comments.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.forum_outlined, color: AppColors.primary, size: 28),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'No comments yet',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Start the conversation by sharing your thoughts on this watch! 🐝',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _comments.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 16),
                        itemBuilder: (ctx, index) {
                          final comment = _comments[index];
                          final canDelete = comment.userId == currentUserId || widget.entryAuthorId == currentUserId;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildCommentItem(
                                comment: comment,
                                currentUserId: currentUserId,
                                canDelete: canDelete,
                                onReply: () => _startReply(comment),
                                onDelete: () => _handleDeleteComment(comment),
                              ),

                              // Threaded Replies
                              if (comment.replies.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Padding(
                                  padding: const EdgeInsets.only(left: 36),
                                  child: Column(
                                    children: comment.replies.map((reply) {
                                      final canDeleteReply = reply.userId == currentUserId || widget.entryAuthorId == currentUserId;
                                      return Padding(
                                        padding: const EdgeInsets.only(bottom: 8),
                                        child: _buildCommentItem(
                                          comment: reply,
                                          currentUserId: currentUserId,
                                          canDelete: canDeleteReply,
                                          isReply: true,
                                          onDelete: () => _handleDeleteComment(reply, isReply: true, parentId: comment.id),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ],
                            ],
                          );
                        },
                      ),
          ),

          // Replying to banner
          if (_replyingToComment != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              color: AppColors.surfaceHighest,
              child: Row(
                children: [
                  const Icon(Icons.reply_rounded, size: 16, color: AppColors.primaryDark),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Replying to @${_replyingToComment!.user?.username ?? 'user'}',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _replyingToComment = null),
                    child: const Icon(Icons.close_rounded, size: 16, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),

          // Input Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: const Border(top: BorderSide(color: AppColors.border)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      focusNode: _focusNode,
                      minLines: 1,
                      maxLines: 4,
                      style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        hintText: _replyingToComment != null
                            ? 'Write a reply...'
                            : 'Share your thoughts on this watch...',
                        hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                        filled: true,
                        fillColor: AppColors.background,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.black,
                      shape: const CircleBorder(),
                    ),
                    onPressed: _isSubmitting ? null : _handleSubmit,
                    icon: _isSubmitting
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                        : const Icon(Icons.arrow_upward_rounded, size: 20),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentItem({
    required Comment comment,
    required String? currentUserId,
    required bool canDelete,
    bool isReply = false,
    VoidCallback? onReply,
    VoidCallback? onDelete,
  }) {
    final userName = comment.user?.displayName ?? comment.user?.username ?? 'Hive Member';
    final userHandle = comment.user?.username;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WHAvatar(
          imageUrl: comment.user?.profilePictureUrl,
          name: userName,
          radius: isReply ? 13 : 16,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Username + Timestamp
              Row(
                children: [
                  Text(
                    userName,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: isReply ? 12 : 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (userHandle != null) ...[
                    const SizedBox(width: 4),
                    Text(
                      '@$userHandle',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: isReply ? 10 : 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                  const SizedBox(width: 6),
                  Text(
                    '· ${_formatRelativeTime(comment.createdAt)}',
                    style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                  ),
                  const Spacer(),
                  if (canDelete)
                    GestureDetector(
                      onTap: onDelete,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4),
                        child: Icon(Icons.delete_outline_rounded, size: 14, color: AppColors.textMuted),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 3),

              // Comment Body
              Text(
                comment.content,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: isReply ? 12 : 13,
                  color: AppColors.textPrimary,
                  height: 1.35,
                ),
              ),

              // Reply button (only for top-level comments)
              if (!isReply && onReply != null) ...[
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: onReply,
                  child: const Text(
                    'Reply',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
