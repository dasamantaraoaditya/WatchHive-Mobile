import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/share_helper.dart';
import '../../rankings/widgets/add_to_stack_sheet.dart';
import '../../share/widgets/instagram_story_card.dart';
import 'suggest_movie_modal.dart';

class PostLogSuccessDialog extends StatelessWidget {
  final String title;
  final int? tmdbId;
  final String mediaType; // 'movie' or 'tv'
  final String? posterPath;
  final String? backdropPath;
  final String? releaseYear;
  final double? rating;
  final String? review;
  final bool isWatching;
  final bool isEditing;
  final String? userDisplayName;
  final String? username;
  final String? userAvatarUrl;

  const PostLogSuccessDialog({
    super.key,
    required this.title,
    this.tmdbId,
    this.mediaType = 'movie',
    this.posterPath,
    this.backdropPath,
    this.releaseYear,
    this.rating,
    this.review,
    required this.isWatching,
    this.isEditing = false,
    this.userDisplayName,
    this.username,
    this.userAvatarUrl,
  });

  static Future<void> show(
    BuildContext context, {
    required String title,
    int? tmdbId,
    String mediaType = 'movie',
    String? posterPath,
    String? backdropPath,
    String? releaseYear,
    double? rating,
    String? review,
    required bool isWatching,
    bool isEditing = false,
    String? userDisplayName,
    String? username,
    String? userAvatarUrl,
  }) {
    final safeContext = context.mounted ? context : rootNavigatorKey.currentContext;
    if (safeContext == null || !safeContext.mounted) {
      return Future.value();
    }
    return showDialog<void>(
      context: safeContext,
      useRootNavigator: true,
      barrierDismissible: true,
      builder: (ctx) => PostLogSuccessDialog(
        title: title,
        tmdbId: tmdbId,
        mediaType: mediaType,
        posterPath: posterPath,
        backdropPath: backdropPath,
        releaseYear: releaseYear,
        rating: rating,
        review: review,
        isWatching: isWatching,
        isEditing: isEditing,
        userDisplayName: userDisplayName,
        username: username,
        userAvatarUrl: userAvatarUrl,
      ),
    );
  }

  String get _displayTitle {
    final clean = title.trim();
    return (clean.isNotEmpty && clean != 'undefined') ? clean : 'Movie';
  }

  void _handleShareStory(BuildContext dialogContext) {
    HapticFeedback.mediumImpact();
    final targetCtx = rootNavigatorKey.currentContext;
    Navigator.of(dialogContext).pop();
    final effectiveCtx = (targetCtx != null && targetCtx.mounted) ? targetCtx : null;
    ShareHelper.shareCompletedWatch(
      context: effectiveCtx,
      title: _displayTitle,
      posterPath: posterPath,
      backdropPath: backdropPath,
      rating: isWatching ? null : rating,
      review: isWatching ? null : review,
      tmdbId: tmdbId,
      mediaType: mediaType,
      releaseYear: releaseYear,
      userDisplayName: userDisplayName,
      username: username,
      userAvatarUrl: userAvatarUrl,
      isCompleted: !isWatching,
      shareMode: isWatching ? StoryShareMode.watching : StoryShareMode.logged,
    );
  }

  void _handleSuggestFriend(BuildContext dialogContext) {
    HapticFeedback.lightImpact();
    final targetCtx = rootNavigatorKey.currentContext;
    Navigator.of(dialogContext).pop();
    if (targetCtx != null && targetCtx.mounted) {
      SuggestMovieModal.show(
        targetCtx,
        tmdbId: (tmdbId != null && tmdbId! > 0) ? tmdbId : null,
        title: _displayTitle,
        mediaType: mediaType == 'tv' ? 'TV_SHOW' : 'MOVIE',
      );
    }
  }

  void _handleAddToStack(BuildContext dialogContext) {
    HapticFeedback.lightImpact();
    final targetCtx = rootNavigatorKey.currentContext;
    Navigator.of(dialogContext).pop();
    if (targetCtx != null && targetCtx.mounted && tmdbId != null && tmdbId! > 0) {
      AddToStackSheet.show(
        targetCtx,
        tmdbId: tmdbId!,
        title: _displayTitle,
        posterPath: posterPath,
        mediaType: mediaType,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayTitle = _displayTitle;
    final badgeText = isWatching ? 'NOW WATCHING 🍿' : 'WATCH LOGGED 🏆';
    final heading = isWatching
        ? (isEditing ? 'Updated Watching!' : 'Started Watching!')
        : (isEditing ? 'Watch Completed!' : 'Watch Logged!');
    final subtitle = isWatching
        ? 'Share what you\'re watching to your Instagram Story or invite a friend to watch along.'
        : 'Share your review to Instagram Stories or recommend "$displayTitle" to a friend.';
    final shareLabel = isWatching ? 'Share to Story' : 'Share Review to Story';

    final hasValidTmdb = tmdbId != null && tmdbId! > 0;
    final hasRating = !isWatching && rating != null && rating! > 0;
    final hasReview = !isWatching && review != null && review!.trim().isNotEmpty;

    return Dialog(
      backgroundColor: AppColors.background,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(26),
        side: BorderSide(color: AppColors.primary.withValues(alpha: 0.35), width: 1.5),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 400,
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top badge + close button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      badgeText,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF262626),
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.close_rounded, size: 20, color: AppColors.textMuted),
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: 'Close',
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Movie poster + title + optional rating/review
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (posterPath != null && posterPath!.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: CachedNetworkImage(
                          imageUrl: 'https://image.tmdb.org/t/p/w185$posterPath',
                          width: 50,
                          height: 74,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => _posterFallback(),
                        ),
                      )
                    else
                      _posterFallback(),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            heading,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryDark,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            displayTitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textPrimary,
                              height: 1.2,
                            ),
                          ),
                          if (hasRating) ...[
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '⭐ ${rating!.toStringAsFixed(1)} / 10',
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF262626),
                                ),
                              ),
                            ),
                          ],
                          if (hasReview) ...[
                            const SizedBox(height: 6),
                            Text(
                              '“${review!.trim()}”',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 11.5,
                                fontStyle: FontStyle.italic,
                                color: AppColors.textSecondary,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Cinematic Sharing Poster Preview
              Center(
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 220),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.4), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: SizedBox(
                      width: 320,
                      height: 568.8,
                      child: InstagramStoryCard(
                        title: displayTitle,
                        posterPath: posterPath,
                        backdropPath: backdropPath,
                        rating: isWatching ? null : rating,
                        review: isWatching ? null : review,
                        tmdbId: tmdbId,
                        mediaType: mediaType,
                        releaseYear: releaseYear,
                        userDisplayName: userDisplayName,
                        username: username,
                        userAvatarUrl: userAvatarUrl,
                        isCompleted: !isWatching,
                        shareMode: isWatching ? StoryShareMode.watching : StoryShareMode.logged,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12.5,
                  color: AppColors.textSecondary,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 16),

              // Primary CTA: Share to Story / Share Review to Story
              ElevatedButton.icon(
                onPressed: () => _handleShareStory(context),
                icon: const Icon(Icons.auto_awesome_rounded, size: 18, color: Color(0xFF262626)),
                label: Text(
                  shareLabel,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF262626),
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: const Color(0xFF262626),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 10),

              // Secondary CTA: Suggest to a Friend
              OutlinedButton.icon(
                onPressed: () => _handleSuggestFriend(context),
                icon: const Icon(Icons.send_rounded, size: 17, color: AppColors.textPrimary),
                label: const Text(
                  'Suggest to a Friend',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  backgroundColor: AppColors.surface,
                  foregroundColor: AppColors.textPrimary,
                  side: BorderSide(color: AppColors.primary.withValues(alpha: 0.65), width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),

              // Bonus CTA for Completed Watches: Add to Cinematic Stack
              if (!isWatching && hasValidTmdb) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => _handleAddToStack(context),
                  icon: const Icon(Icons.layers_rounded, size: 17, color: AppColors.textSecondary),
                  label: const Text(
                    'Add to Cinematic Stack',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: AppColors.surfaceElevated,
                    foregroundColor: AppColors.textSecondary,
                    side: const BorderSide(color: AppColors.border),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ],

              const SizedBox(height: 6),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textMuted,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
                child: const Text(
                  'Done',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _posterFallback() {
    return Container(
      width: 50,
      height: 74,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(
        mediaType == 'tv' ? Icons.tv_rounded : Icons.movie_rounded,
        color: const Color(0xFF2D2926),
        size: 24,
      ),
    );
  }
}
