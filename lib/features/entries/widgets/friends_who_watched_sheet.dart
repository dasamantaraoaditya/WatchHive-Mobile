import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/models/entry.dart';
import '../../../shared/widgets/shared_widgets.dart';
import '../../feed/providers/feed_provider.dart';
import '../../feed/repositories/feed_repository.dart';
import '../../feed/widgets/comments_sheet.dart';
import '../../feed/widgets/likes_list_sheet.dart';

/// Bottom sheet modal displaying all friends who have watched/reviewed
/// a specific movie or show, with full ratings, moods, written reviews,
/// and social interactions (likes, comments, profile links).
class FriendsWhoWatchedSheet extends ConsumerStatefulWidget {
  final String movieTitle;
  final List<Entry> friendsEntries;
  final Entry? myEntry;

  const FriendsWhoWatchedSheet({
    super.key,
    required this.movieTitle,
    required this.friendsEntries,
    this.myEntry,
  });

  static Future<void> show(
    BuildContext context, {
    required String movieTitle,
    required List<Entry> friendsEntries,
    Entry? myEntry,
  }) {
    HapticFeedback.lightImpact();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => FriendsWhoWatchedSheet(
        movieTitle: movieTitle,
        friendsEntries: friendsEntries,
        myEntry: myEntry,
      ),
    );
  }

  @override
  ConsumerState<FriendsWhoWatchedSheet> createState() => _FriendsWhoWatchedSheetState();
}

class _FriendsWhoWatchedSheetState extends ConsumerState<FriendsWhoWatchedSheet> {
  final Map<String, bool> _likedMap = {};
  final Map<String, int> _likesCountMap = {};
  final Map<String, int> _commentsCountMap = {};
  final Set<String> _expandedReviews = {};

  @override
  void initState() {
    super.initState();
    for (final e in widget.friendsEntries) {
      _likedMap[e.id] = e.isLiked;
      _likesCountMap[e.id] = e.likesCount;
      _commentsCountMap[e.id] = e.commentsCount;
    }
  }

  Future<void> _toggleLike(Entry entry) async {
    final isLiked = _likedMap[entry.id] ?? false;
    final prevCount = _likesCountMap[entry.id] ?? entry.likesCount;

    HapticFeedback.lightImpact();
    setState(() {
      _likedMap[entry.id] = !isLiked;
      _likesCountMap[entry.id] = isLiked ? (prevCount > 0 ? prevCount - 1 : 0) : prevCount + 1;
    });

    try {
      if (isLiked) {
        await ref.read(feedRepositoryProvider).unlikeEntry(entry.id);
      } else {
        await ref.read(feedRepositoryProvider).likeEntry(entry.id);
      }
      try {
        ref.read(feedProvider.notifier).toggleLike(entry.id);
      } catch (_) {}
    } catch (_) {
      if (mounted) {
        setState(() {
          _likedMap[entry.id] = isLiked;
          _likesCountMap[entry.id] = prevCount;
        });
      }
    }
  }

  void _showComments(Entry entry) {
    CommentsSheet.show(
      context,
      entryId: entry.id,
      entryTitle: entry.title,
      entryAuthorId: entry.userId,
      onCommentCountChanged: (count) {
        if (mounted) {
          setState(() {
            _commentsCountMap[entry.id] = count;
          });
        }
      },
    );
  }

  void _openUserProfile(String userId) {
    if (userId.trim().isEmpty) return;
    HapticFeedback.lightImpact();
    context.push('/profile/$userId');
  }

  @override
  Widget build(BuildContext context) {
    final totalFriends = widget.friendsEntries.length;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
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

          // Header Row
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 12, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.groups_rounded,
                            color: AppColors.primary,
                            size: 22,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Friends Who Watched ($totalFriends)',
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 16.5,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                                letterSpacing: -0.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.movieTitle,
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
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, color: AppColors.textMuted, size: 20),
                  splashRadius: 20,
                  tooltip: 'Close',
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: AppColors.border),

          // Scrollable List of Friend Reviews
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              itemCount: widget.friendsEntries.length,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                final entry = widget.friendsEntries[index];
                return _buildFriendReviewCard(entry);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFriendReviewCard(Entry entry) {
    final user = entry.user;
    final displayName = user?.displayName ?? user?.username ?? 'Friend';
    final username = user?.username ?? '';
    final avatarUrl = user?.profilePictureUrl;
    final rating = entry.rating;
    final moodInfo = rating != null && rating > 0 ? WHRatingPicker.getMoodInfo(rating) : null;
    final hasReview = entry.review != null && entry.review!.trim().isNotEmpty;
    final reviewText = entry.review?.trim() ?? '';
    final isExpanded = _expandedReviews.contains(entry.id);
    const int charLimit = 180;
    final bool isLongReview = reviewText.length > charLimit;

    final isLiked = _likedMap[entry.id] ?? entry.isLiked;
    final likesCount = _likesCountMap[entry.id] ?? entry.likesCount;
    final commentsCount = _commentsCountMap[entry.id] ?? entry.commentsCount;

    final watchedDate = entry.watchedAt;
    final dateLabel = entry.isWatching
        ? 'Currently Watching'
        : 'Watched on ${DateFormat('MMM d, yyyy').format(watchedDate)}';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.border,
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User Info & Rating Header Row
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () => _openUserProfile(entry.userId),
                  child: WHAvatar(
                    imageUrl: avatarUrl,
                    name: displayName,
                    radius: 19,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _openUserProfile(entry.userId),
                    behavior: HitTestBehavior.opaque,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 1),
                        Text(
                          username.isNotEmpty ? '@$username • $dateLabel' : dateLabel,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textMuted,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),

                // Rating Badge
                if (rating != null && rating > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star_rounded, size: 14, color: AppColors.primaryDark),
                        const SizedBox(width: 3),
                        Text(
                          rating.toStringAsFixed(1),
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: AppColors.primaryDark,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // Mood Tag (if logged)
          if (moodInfo != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: moodInfo.bgColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: moodInfo.color.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(moodInfo.icon, size: 12, color: moodInfo.color),
                    const SizedBox(width: 4),
                    Text(
                      moodInfo.text,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: moodInfo.color,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Review Text with Smart Truncation
          if (hasReview)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isLongReview && !isExpanded
                          ? '${reviewText.substring(0, charLimit)}...'
                          : reviewText,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                        height: 1.45,
                      ),
                    ),
                    if (isLongReview) ...[
                      const SizedBox(height: 6),
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() {
                            if (isExpanded) {
                              _expandedReviews.remove(entry.id);
                            } else {
                              _expandedReviews.add(entry.id);
                            }
                          });
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              isExpanded ? 'Show less' : 'Read more',
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primaryDark,
                              ),
                            ),
                            Icon(
                              isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                              size: 15,
                              color: AppColors.primaryDark,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

          // Comparison Banner (If viewing a friend's review and you also logged it)
          if (widget.myEntry != null && widget.myEntry!.rating != null && rating != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.compare_arrows_rounded, size: 14, color: AppColors.primaryDark),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'You rated this ⭐ ${widget.myEntry!.rating!.toStringAsFixed(1)} (Difference: ${(rating - widget.myEntry!.rating!).toStringAsFixed(1)})',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryDark,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          const Divider(height: 1, color: AppColors.border),

          // Actions Footer (Likes + Comments)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: () => _toggleLike(entry),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.only(left: 8, right: 3, top: 6, bottom: 6),
                        child: Icon(
                          isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                          size: 16,
                          color: isLiked ? AppColors.error : AppColors.textMuted,
                        ),
                      ),
                    ),
                    if (likesCount > 0)
                      InkWell(
                        onTap: () => LikesListSheet.show(
                          context,
                          entryId: entry.id,
                          entryTitle: entry.title,
                          initialLikeCount: likesCount,
                        ),
                        borderRadius: BorderRadius.circular(6),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                          child: Text(
                            '$likesCount ${likesCount == 1 ? 'like' : 'likes'}',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isLiked ? AppColors.error : AppColors.textPrimary,
                              decoration: TextDecoration.underline,
                              decorationColor: (isLiked ? AppColors.error : AppColors.primaryDark).withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                      )
                    else
                      InkWell(
                        onTap: () => _toggleLike(entry),
                        borderRadius: BorderRadius.circular(6),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                          child: Text(
                            '0',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () => _showComments(entry),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          commentsCount > 0 ? Icons.chat_bubble_rounded : Icons.chat_bubble_outline_rounded,
                          size: 15,
                          color: commentsCount > 0 ? AppColors.primaryDark : AppColors.textMuted,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$commentsCount',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: commentsCount > 0 ? AppColors.primaryDark : AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
