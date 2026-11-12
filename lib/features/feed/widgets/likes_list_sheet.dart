import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/error_handler.dart';
import '../../../shared/models/user.dart';
import '../../../shared/widgets/shared_widgets.dart';
import '../repositories/feed_repository.dart';

class LikesListSheet extends ConsumerStatefulWidget {
  final String entryId;
  final String? entryTitle;
  final int initialLikeCount;

  const LikesListSheet({
    super.key,
    required this.entryId,
    this.entryTitle,
    this.initialLikeCount = 0,
  });

  static Future<void> show(
    BuildContext context, {
    required String entryId,
    String? entryTitle,
    int initialLikeCount = 0,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => LikesListSheet(
        entryId: entryId,
        entryTitle: entryTitle,
        initialLikeCount: initialLikeCount,
      ),
    );
  }

  @override
  ConsumerState<LikesListSheet> createState() => _LikesListSheetState();
}

class _LikesListSheetState extends ConsumerState<LikesListSheet> {
  static const int _initialLimit = 3;
  static const int _loadMoreBatchSize = 10;

  final List<User> _users = [];
  int _total = 0;
  bool _hasMore = false;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _total = widget.initialLikeCount;
    _fetchLikes(limit: _initialLimit, offset: 0, append: false);
  }

  Future<void> _fetchLikes({
    required int limit,
    required int offset,
    required bool append,
  }) async {
    if (append) {
      setState(() => _isLoadingMore = true);
    } else {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final res = await ref.read(feedRepositoryProvider).getEntryLikes(
            widget.entryId,
            limit: limit,
            offset: offset,
          );
      if (!mounted) return;
      setState(() {
        if (append) {
          final existingIds = _users.map((u) => u.id).toSet();
          for (final u in res.users) {
            if (!existingIds.contains(u.id)) {
              _users.add(u);
              existingIds.add(u.id);
            }
          }
        } else {
          _users
            ..clear()
            ..addAll(res.users);
        }
        _total = res.total;
        _hasMore = res.hasMore;
        _isLoading = false;
        _isLoadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = AppErrorHandler.toUserFriendlyMessage(
          e,
          defaultMessage: 'Could not load likes. Please try again.',
        );
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  void _handleLoadMore() {
    if (_isLoadingMore || !_hasMore) return;
    HapticFeedback.lightImpact();
    _fetchLikes(
      limit: _loadMoreBatchSize,
      offset: _users.length,
      append: true,
    );
  }

  void _openProfile(User user) {
    HapticFeedback.selectionClick();
    Navigator.of(context).pop();
    context.push('/profile/${user.id}');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.72,
      ),
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Icon(
                    Icons.favorite_rounded,
                    color: AppColors.error,
                    size: 19,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Liked by',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '$_total',
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF262626),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (widget.entryTitle != null && widget.entryTitle!.trim().isNotEmpty)
                        Text(
                          widget.entryTitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: AppColors.textMuted),
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: 'Close',
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),

          // Body
          Flexible(
            child: _buildBody(),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const SingleChildScrollView(
        physics: NeverScrollableScrollPhysics(),
        child: WHSkeletonUserList(count: _initialLimit),
      );
    }

    if (_error != null && _users.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 36),
              const SizedBox(height: 10),
              Text(
                _error!,
                style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),
              ElevatedButton(
                onPressed: () => _fetchLikes(
                  limit: _initialLimit,
                  offset: 0,
                  append: false,
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: const Color(0xFF262626),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text(
                  'Retry',
                  style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_users.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.favorite_border_rounded,
                size: 28,
                color: Color(0xFF2D2926),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'No likes yet',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Be the first to show some love for this post!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12.5,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      );
    }

    final remainingCount = (_total - _users.length).clamp(0, _total);
    final showSeeMoreButton = _hasMore && !_isLoadingMore;
    final footerCount = (_isLoadingMore || showSeeMoreButton) ? 1 : 0;

    return SafeArea(
      top: false,
      child: ListView.separated(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        itemCount: _users.length + footerCount,
        separatorBuilder: (ctx, index) {
          if (index >= _users.length - 1) return const SizedBox(height: 10);
          return const SizedBox(height: 8);
        },
        itemBuilder: (ctx, index) {
          if (index == _users.length) {
            if (_isLoadingMore) {
              return const WHSkeletonUserList(count: 2);
            }
            return SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _handleLoadMore,
                icon: const Icon(
                  Icons.expand_more_rounded,
                  size: 18,
                  color: Color(0xFF262626),
                ),
                label: Text(
                  remainingCount > _loadMoreBatchSize
                      ? 'See more (next $_loadMoreBatchSize of $remainingCount)'
                      : 'See more ($remainingCount)',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF262626),
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: const Color(0xFF262626),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            );
          }

          final user = _users[index];
          return Material(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              onTap: () => _openProfile(user),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    WHAvatar(
                      imageUrl: user.profilePictureUrl,
                      name: user.name,
                      radius: 21,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.name,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 1),
                          Text(
                            '@${user.username}',
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textMuted,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.45)),
                      ),
                      child: const Text(
                        'View',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF262626),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
