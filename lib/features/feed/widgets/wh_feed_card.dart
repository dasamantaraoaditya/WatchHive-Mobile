import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/utils/error_handler.dart';
import '../../../shared/models/entry.dart';
import '../../../shared/widgets/shared_widgets.dart';
import '../../entries/repositories/watchlist_repository.dart';
import '../../entries/screens/add_entry_sheet.dart';
import '../../entries/widgets/suggest_movie_modal.dart';
import '../../search/repositories/search_repository.dart';
import '../../entries/widgets/platform_logo_badge.dart';
import '../providers/feed_provider.dart';


class WHFeedCard extends ConsumerStatefulWidget {
  final Entry entry;
  final bool isLiked;
  final bool isOwnEntry;
  final VoidCallback onLike;
  final VoidCallback? onCommentTap;
  final VoidCallback onUserTap;
  final VoidCallback onMediaTap;

  const WHFeedCard({
    super.key,
    required this.entry,
    required this.isLiked,
    required this.isOwnEntry,
    required this.onLike,
    this.onCommentTap,
    required this.onUserTap,
    required this.onMediaTap,
  });

  @override
  ConsumerState<WHFeedCard> createState() => _WHFeedCardState();
}

class _WHFeedCardState extends ConsumerState<WHFeedCard> {
  bool? _inWatchlistLocal;
  bool _isWatchlistLoading = false;

  Future<void> _handleWatchlistToggle(bool currentStatus) async {
    if (_isWatchlistLoading || widget.entry.tmdbId <= 0) return;
    HapticFeedback.lightImpact();
    setState(() {
      _isWatchlistLoading = true;
      _inWatchlistLocal = !currentStatus;
    });

    final title = widget.entry.title.trim().isNotEmpty ? widget.entry.title.trim() : 'Title';
    final repo = ref.read(watchlistRepositoryProvider);

    try {
      if (currentStatus) {
        await repo.removeFromWatchlistByTmdbId(widget.entry.tmdbId);
        ref.invalidate(isInWatchlistProvider(widget.entry.tmdbId));
        if (mounted) {
          WHAlert.showSuccess(context, 'Removed "$title" from Watchlist');
        }
      } else {
        final prefilledSuggestorId = widget.isOwnEntry
            ? null
            : (widget.entry.suggestedByUserId ?? widget.entry.user?.id);
        await repo.addToWatchlist(
          tmdbId: widget.entry.tmdbId,
          title: title,
          mediaType: widget.entry.type == 'TV_SHOW' || widget.entry.type == 'tv' ? 'tv' : 'movie',
          posterPath: widget.entry.posterPath,
          overview: widget.entry.review,
          suggestedByUserId: prefilledSuggestorId,
        );
        ref.invalidate(isInWatchlistProvider(widget.entry.tmdbId));
        if (mounted) {
          WHAlert.showSuccess(context, 'Added "$title" to Watchlist.');
        }
      }
    } catch (e) {
      ref.invalidate(isInWatchlistProvider(widget.entry.tmdbId));
      if (mounted) {
        setState(() {
          _inWatchlistLocal = currentStatus;
        });
        WHAlert.showError(
          context,
          AppErrorHandler.toUserFriendlyMessage(e, action: 'Failed to update Watchlist'),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isWatchlistLoading = false);
      }
    }
  }

  void _handleQuickLog() {
    HapticFeedback.lightImpact();
    final prefilledSuggestor = widget.isOwnEntry ? null : (widget.entry.suggestedByUser ?? widget.entry.user);
    final prefilledSuggestorId = widget.isOwnEntry ? null : (widget.entry.suggestedByUserId ?? widget.entry.user?.id);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AddEntrySheet(
        prefillTmdbId: widget.entry.tmdbId > 0 ? widget.entry.tmdbId : null,
        prefillType: widget.entry.type,
        prefillTitle: widget.entry.title,
        prefillPosterPath: widget.entry.posterPath,
        prefillSuggestor: prefilledSuggestor,
        prefillSuggestedByUserId: prefilledSuggestorId,
      ),
    );
  }

  void _handleQuickSuggest() {
    HapticFeedback.lightImpact();
    SuggestMovieModal.show(
      context,
      tmdbId: widget.entry.tmdbId > 0 ? widget.entry.tmdbId : null,
      title: widget.entry.title,
      mediaType: widget.entry.type == 'TV_SHOW' || widget.entry.type == 'tv' ? 'tv' : 'movie',
    );
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final isLiked = widget.isLiked;
    final onLike = widget.onLike;
    final onCommentTap = widget.onCommentTap;
    final onUserTap = widget.onUserTap;
    final onMediaTap = widget.onMediaTap;

    final hasValidTmdb = entry.tmdbId > 0;
    final inWatchlistAsync = hasValidTmdb ? ref.watch(isInWatchlistProvider(entry.tmdbId)) : null;
    final inWatchlist = _inWatchlistLocal ?? inWatchlistAsync?.valueOrNull ?? false;

    final isSuggestion = entry.isSuggestion || entry.user == null;
    final displayName = () {
      if (isSuggestion) return 'WatchersHive';
      final dn = entry.user?.displayName?.trim();
      if (dn != null && dn.isNotEmpty) return dn;
      final un = entry.user?.username.trim();
      if (un != null && un.isNotEmpty) {
        return un.startsWith('@') ? un.substring(1) : un;
      }
      return 'User';
    }();

    final actionText = () {
      if (isSuggestion) return 'recommends';
      if (entry.isWatching) return 'started watching';
      if (entry.completedAt != null || entry.startedAt != null) return 'completed watching';
      if (entry.review != null && entry.review!.isNotEmpty) return 'reviewed';
      return 'logged';
    }();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSuggestion ? AppColors.primary.withValues(alpha: 0.4) : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Avatar + Action Sentence + Suggested By + Compact Header Date
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: isSuggestion ? null : onUserTap,
                  child: isSuggestion
                      ? Container(
                          width: 38,
                          height: 38,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.auto_awesome, color: Colors.black, size: 20),
                        )
                      : WHAvatar(
                          imageUrl: entry.user?.profilePictureUrl,
                          name: displayName,
                          radius: 19,
                        ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // User Name + Action Sentence (Tappable with profile redirect, ellipsis for long names)
                      GestureDetector(
                        onTap: isSuggestion ? null : onUserTap,
                        behavior: HitTestBehavior.opaque,
                        child: Text.rich(
                          TextSpan(
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 13,
                              color: AppColors.textPrimary,
                            ),
                            children: [
                              TextSpan(
                                text: displayName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              TextSpan(
                                text: ' $actionText',
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w400,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),

                      // Recommendation reason for suggestions (no @user_id shown)
                      if (isSuggestion) ...[
                        const SizedBox(height: 2),
                        Text(
                          entry.suggestionReason ?? '✨ Recommended for You',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ],

                      // Suggested By Row (If applicable) - Clean name with profile redirect and overflow protection
                      if (entry.suggestedByUser != null) ...[
                        const SizedBox(height: 4),
                        GestureDetector(
                          onTap: () {
                            final suggId = entry.suggestedByUser!.id;
                            if (suggId.isNotEmpty) {
                              context.push('/profile/$suggId');
                            }
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'Suggested by ',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textMuted,
                                ),
                              ),
                              WHAvatar(
                                imageUrl: entry.suggestedByUser!.profilePictureUrl,
                                name: entry.suggestedByUser!.displayName ?? entry.suggestedByUser!.username,
                                radius: 8,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  () {
                                    final sdn = entry.suggestedByUser!.displayName?.trim();
                                    if (sdn != null && sdn.isNotEmpty) return sdn;
                                    final sun = entry.suggestedByUser!.username.trim();
                                    if (sun.isNotEmpty) {
                                      final rawSun = sun.startsWith('@') ? sun.substring(1) : sun;
                                      return rawSun.length > 10 ? '${rawSun.substring(0, 10)}...' : rawSun;
                                    }
                                    return 'Friend';
                                  }(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(width: 8),
                if (entry.isPendingSync) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFF59E0B)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.sync_rounded, size: 10, color: Color(0xFFB45309)),
                        SizedBox(width: 3),
                        Text(
                          'Pending Sync',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFB45309),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                // Where did you watch platform badge (e.g., Netflix, Prime, Cinema) to the right of the card in the same line
                if (entry.watchLocation != null && entry.watchLocation!.trim().isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        PlatformBrandLogo(
                          platform: entry.watchLocation!.trim(),
                          size: 13,
                        ),
                        const SizedBox(width: 4),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 88),
                          child: Text(
                            entry.watchLocation!.trim(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
                if (!widget.isOwnEntry && !isSuggestion && entry.user != null) ...[
                  const SizedBox(width: 2),
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert_rounded, size: 18, color: AppColors.textMuted),
                      padding: EdgeInsets.zero,
                      color: AppColors.surfaceElevated,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      onSelected: (value) {
                        if (value == 'report') {
                          UgcModerationDialog.showReportDialog(
                            context,
                            ref,
                            targetType: 'ENTRY',
                            targetId: entry.id,
                            targetTitle: entry.title.isNotEmpty ? entry.title : null,
                            onReported: () {
                              ref.read(feedProvider.notifier).removeEntry(entry.id);
                            },
                          );
                        } else if (value == 'block') {
                          UgcModerationDialog.confirmBlockUser(
                            context,
                            ref,
                            userId: entry.user!.id,
                            username: displayName,
                            onBlocked: () {
                              ref.read(feedProvider.notifier).removeEntriesByUser(entry.user!.id);
                            },
                          );
                        }
                      },
                      itemBuilder: (ctx) => [
                        const PopupMenuItem<String>(
                          value: 'report',
                          height: 38,
                          child: Row(
                            children: [
                              Icon(Icons.flag_outlined, size: 16, color: AppColors.error),
                              SizedBox(width: 8),
                              Text('Report Post', style: TextStyle(fontSize: 13, color: AppColors.textPrimary)),
                            ],
                          ),
                        ),
                        const PopupMenuItem<String>(
                          value: 'block',
                          height: 38,
                          child: Row(
                            children: [
                              Icon(Icons.block_rounded, size: 16, color: AppColors.error),
                              SizedBox(width: 8),
                              Text('Block User', style: TextStyle(fontSize: 13, color: AppColors.textPrimary)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Hero Media Banner (Full Width Movie/Show Poster Image + Badges & Tags)
          FeedMediaHeroBanner(
            entry: entry,
            onTap: onMediaTap,
          ),

          // Status & Full Precise Timestamp Footer with Overflow Protection
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Row(
              children: [
                Icon(
                  isSuggestion
                      ? Icons.auto_awesome_rounded
                      : (entry.isWatching
                          ? Icons.play_circle_outline_rounded
                          : (entry.completedAt != null || entry.startedAt != null ? Icons.check_circle_outline_rounded : Icons.schedule_rounded)),
                  size: 14,
                  color: isSuggestion ? AppColors.primary : AppColors.textMuted,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: isSuggestion
                              ? (entry.suggestionReason ?? 'Recommended for You')
                              : (entry.isWatching
                                  ? 'Started watching • '
                                  : (entry.completedAt != null || entry.startedAt != null
                                      ? 'Completed watching • '
                                      : (entry.review != null && entry.review!.isNotEmpty ? 'Reviewed • ' : 'Logged • '))),
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            fontWeight: isSuggestion ? FontWeight.w600 : FontWeight.w500,
                            color: isSuggestion ? AppColors.primary : AppColors.textMuted,
                          ),
                        ),
                        if (!isSuggestion)
                          TextSpan(
                            text: _formatFullTimestamp(entry.activityDate),
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          // Review / MindLens Insight Quote Box
          if (entry.review != null && entry.review!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.psychology_outlined, color: AppColors.primary, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isSuggestion ? 'Why you might like this' : 'Review & Insight',
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '“${entry.review!.trim()}”',
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'Georgia',
                              fontFamilyFallback: ['serif'],
                              fontSize: 14,
                              fontStyle: FontStyle.italic,
                              color: AppColors.textPrimary,
                              height: 1.5,
                              letterSpacing: 0.15,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // Action bar
          const SizedBox(height: 10),
          const Divider(height: 1, color: AppColors.border),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                if (!isSuggestion) ...[
                  WHFeedActionButton(
                    icon: isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    label: '${entry.likesCount}',
                    color: isLiked ? AppColors.error : AppColors.textMuted,
                    onTap: onLike,
                  ),
                  const SizedBox(width: 4),
                  WHFeedActionButton(
                    icon: (entry.isCommented || entry.commentsCount > 0)
                        ? Icons.chat_bubble_rounded
                        : Icons.chat_bubble_outline_rounded,
                    label: '${entry.commentsCount}',
                    color: (entry.isCommented || entry.commentsCount > 0)
                        ? AppColors.primaryDark
                        : AppColors.textMuted,
                    onTap: onCommentTap ?? () {},
                  ),
                ],
                const Spacer(),
                // Quick Actions: Watchlist, Log Watch, Suggest
                if (hasValidTmdb)
                  IconButton(
                    tooltip: inWatchlist ? 'In Watchlist' : 'Add to Watchlist',
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    splashRadius: 18,
                    icon: _isWatchlistLoading
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                            ),
                          )
                        : Icon(
                            inWatchlist ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                            size: 19,
                            color: inWatchlist ? AppColors.primaryDark : AppColors.textMuted,
                          ),
                    onPressed: () => _handleWatchlistToggle(inWatchlist),
                  ),
                IconButton(
                  tooltip: 'Log Watch',
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  splashRadius: 18,
                  icon: const Icon(
                    Icons.add_task_rounded,
                    size: 19,
                    color: AppColors.textMuted,
                  ),
                  onPressed: _handleQuickLog,
                ),
                if (hasValidTmdb)
                  IconButton(
                    tooltip: 'Suggest to Friend',
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    splashRadius: 18,
                    icon: const Icon(
                      Icons.send_rounded,
                      size: 18,
                      color: AppColors.textMuted,
                    ),
                    onPressed: _handleQuickSuggest,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatFullTimestamp(DateTime date) {
    final now = DateTime.now();
    final effectiveDate = date.isAfter(now) ? now : date;
    final localDate = effectiveDate.toLocal();
    final dateStr = DateFormat('MMM d, yyyy').format(localDate);
    final timeStr = DateFormat('h:mm a').format(localDate);
    return '$dateStr at $timeStr';
  }
}

class WHFeedActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const WHFeedActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 17, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FeedMediaHeroBanner extends ConsumerWidget {
  final Entry entry;
  final VoidCallback onTap;

  const FeedMediaHeroBanner({
    super.key,
    required this.entry,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mediaType = (entry.type == 'TV_SHOW' || entry.type == 'EPISODE') ? 'tv' : 'movie';
    final isGenericTitle = entry.title.trim().isEmpty ||
        entry.title.toLowerCase() == 'this title' ||
        entry.title.toLowerCase() == 'untitled' ||
        entry.title.startsWith('Movie #') ||
        entry.title.startsWith('Media #');

    final shouldFetch = (((entry.posterPath == null || entry.posterPath!.isEmpty) &&
        (entry.backdropPath == null || entry.backdropPath!.isEmpty)) ||
        isGenericTitle) &&
        entry.tmdbId > 0;

    final detailsAsync = shouldFetch
        ? ref.watch(tmdbMediaDetailsProvider((tmdbId: entry.tmdbId, mediaType: mediaType)))
        : null;

    final tmdbTitle = (detailsAsync?.value?['title'] as String?) ??
        (detailsAsync?.value?['name'] as String?) ??
        (detailsAsync?.value?['original_title'] as String?) ??
        (detailsAsync?.value?['original_name'] as String?);

    final displayTitle = (isGenericTitle && tmdbTitle != null && tmdbTitle.trim().isNotEmpty)
        ? tmdbTitle
        : (entry.title.isNotEmpty ? entry.title : (tmdbTitle ?? 'Untitled'));

    final posterPath = entry.posterPath ?? detailsAsync?.value?['poster_path'] as String?;
    final backdropPath = entry.backdropPath ?? detailsAsync?.value?['backdrop_path'] as String?;
    final imagePath = backdropPath ?? posterPath;
    final imageUrl = ApiEndpoints.tmdbBackdrop(imagePath);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 210,
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Stack(
          children: [
            // Background Image
            if (imageUrl.isNotEmpty)
              Positioned.fill(
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Shimmer.fromColors(
                    baseColor: AppColors.surfaceElevated,
                    highlightColor: AppColors.surfaceHighest,
                    child: Container(color: AppColors.surfaceElevated),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: AppColors.surfaceElevated,
                    child: const Center(
                      child: Icon(Icons.movie_outlined, color: AppColors.textMuted, size: 40),
                    ),
                  ),
                ),
              )
            else
              Positioned.fill(
                child: Container(
                  color: AppColors.surfaceElevated,
                  child: const Center(
                    child: Icon(Icons.movie_outlined, color: AppColors.textMuted, size: 40),
                  ),
                ),
              ),

            // Subtle dark gradient overlay for text readability
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.2),
                      Colors.black.withValues(alpha: 0.8),
                    ],
                  ),
                ),
              ),
            ),

            // Top-Left Badges: Type & Rewatch
            Positioned(
              top: 10,
              left: 10,
              right: 80,
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      entry.type == 'MOVIE' ? 'Movie' : 'TV Series',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  if (entry.isRewatch)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.info.withValues(alpha: 0.4)),
                      ),
                      child: const Text(
                        'Rewatch',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.info,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Top-Right Badge: Rating
            if (entry.rating != null && entry.rating! > 0)
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star_rounded, color: AppColors.primary, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        entry.rating!.toStringAsFixed(1),
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Bottom-Left Overlay: Movie Title & Tags
            Positioned(
              bottom: 12,
              left: 12,
              right: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      shadows: [
                        Shadow(offset: Offset(0, 1), blurRadius: 4, color: Colors.black),
                      ],
                    ),
                  ),
                  if (entry.tags.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: entry.tags.take(3).map((tag) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
                        ),
                        child: Text(
                          '#$tag',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      )).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
