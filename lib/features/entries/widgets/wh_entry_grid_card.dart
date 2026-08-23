import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../search/repositories/search_repository.dart';

enum WHEntryCardMode {
  watching,
  history,
  watchlist,
  suggestion,
}

class WHEntryGridCard extends ConsumerWidget {
  final int tmdbId;
  final String title;
  final String? initialPosterPath;
  final String mediaType; // 'movie' or 'tv'
  final WHEntryCardMode mode;
  final double? rating; // User rating or TMDB vote_average
  final DateTime? watchedAt;
  final String? suggestedByUsername;
  final String? suggestedByAvatarUrl;
  final List<String> tags;
  final VoidCallback onTap;
  final VoidCallback? onMoveToWatching;
  final VoidCallback? onMarkWatched;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const WHEntryGridCard({
    super.key,
    required this.tmdbId,
    required this.title,
    this.initialPosterPath,
    required this.mediaType,
    required this.mode,
    this.rating,
    this.watchedAt,
    this.suggestedByUsername,
    this.suggestedByAvatarUrl,
    this.tags = const [],
    required this.onTap,
    this.onMoveToWatching,
    this.onMarkWatched,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final normalizedType = (mediaType.toLowerCase() == 'tv' || mediaType == 'TV_SHOW') ? 'tv' : 'movie';
    final shouldFetch = (initialPosterPath == null || initialPosterPath!.isEmpty) && tmdbId > 0;

    final detailsAsync = shouldFetch
        ? ref.watch(tmdbMediaDetailsProvider((tmdbId: tmdbId, mediaType: normalizedType)))
        : null;

    final posterPath = initialPosterPath ?? detailsAsync?.value?['poster_path'] as String?;
    final voteAvg = (detailsAsync?.value?['vote_average'] as num?)?.toDouble() ?? rating;
    final releaseDate = detailsAsync?.value?['release_date'] as String? ?? detailsAsync?.value?['first_air_date'] as String?;
    final year = releaseDate != null && releaseDate.length >= 4 ? releaseDate.substring(0, 4) : null;
    final displayTitle = (detailsAsync?.value?['title'] as String?) ?? (detailsAsync?.value?['name'] as String?) ?? title;
    final posterUrl = ApiEndpoints.tmdbPoster(posterPath);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Poster Banner Container (Top ~75%) ──────────────────────────
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: posterUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: posterUrl,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Shimmer.fromColors(
                              baseColor: AppColors.surfaceElevated,
                              highlightColor: AppColors.surfaceHighest,
                              child: Container(color: AppColors.surfaceElevated),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: AppColors.surfaceElevated,
                              child: const Center(
                                child: Icon(Icons.movie_outlined, color: AppColors.textMuted, size: 36),
                              ),
                            ),
                          )
                        : Container(
                            color: AppColors.surfaceElevated,
                            child: const Center(
                              child: Icon(Icons.movie_outlined, color: AppColors.textMuted, size: 36),
                            ),
                          ),
                  ),

                  // Dark gradient overlay for text readability
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: const [0.4, 1.0],
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.88),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Top-Left Category Badge (🎬 Movie / 📺 TV)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        normalizedType == 'tv' ? '📺 TV' : '🎬 Movie',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),

                  // Top-Right Badge: Mode-Dependent (Watching, Rating, or Suggested By)
                  if (mode == WHEntryCardMode.watching)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.info.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.visibility, color: Colors.white, size: 11),
                            SizedBox(width: 3),
                            Text(
                              'Watching',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (suggestedByUsername != null && suggestedByUsername!.isNotEmpty)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('💡 ', style: TextStyle(fontSize: 8)),
                            Text(
                              '@$suggestedByUsername',
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: Colors.amber,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (voteAvg != null)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star_rounded, color: AppColors.primary, size: 12),
                            const SizedBox(width: 3),
                            Text(
                              voteAvg.toStringAsFixed(1),
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Bottom Title & Tags / Year Overlay
                  Positioned(
                    bottom: 8,
                    left: 8,
                    right: 8,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayTitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            shadows: [
                              Shadow(offset: Offset(0, 1), blurRadius: 4, color: Colors.black),
                            ],
                          ),
                        ),
                        if (tags.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            tags.take(2).map((t) => '#$t').join(' '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ] else if (year != null) ...[
                          const SizedBox(height: 3),
                          Text(
                            year,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Action & Metadata Footer (Bottom ~25%) ──────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Row(
                children: [
                  // Left info (Date or Action Label)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Text(
                        mode == WHEntryCardMode.watching
                            ? 'Active Session'
                            : watchedAt != null
                                ? DateFormat('MMM d, yyyy').format(watchedAt!)
                                : year ?? 'Saved',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  ),

                  // Right Action Toolbar Icons
                  if (onMoveToWatching != null)
                    IconButton(
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(4),
                      icon: const Icon(Icons.play_arrow_rounded, color: AppColors.info, size: 20),
                      tooltip: 'Log as Currently Watching',
                      onPressed: onMoveToWatching,
                    ),

                  if (onMarkWatched != null)
                    IconButton(
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(4),
                      icon: const Icon(Icons.check_circle_outline_rounded, color: Colors.greenAccent, size: 19),
                      tooltip: 'Mark as Watched',
                      onPressed: onMarkWatched,
                    ),

                  if (onEdit != null)
                    IconButton(
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(4),
                      icon: const Icon(Icons.edit_outlined, color: AppColors.textSecondary, size: 18),
                      tooltip: 'Edit Entry',
                      onPressed: onEdit,
                    ),

                  if (onDelete != null)
                    IconButton(
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(4),
                      icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 18),
                      tooltip: 'Delete',
                      onPressed: onDelete,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
