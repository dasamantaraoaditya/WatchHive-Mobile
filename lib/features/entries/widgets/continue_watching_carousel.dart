import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/models/episode_progress.dart';
import '../../../shared/widgets/shared_widgets.dart';
import '../../search/repositories/search_repository.dart';
import '../repositories/episode_repository.dart';

class ContinueWatchingCarousel extends ConsumerStatefulWidget {
  final VoidCallback? onProgressUpdated;

  const ContinueWatchingCarousel({
    super.key,
    this.onProgressUpdated,
  });

  @override
  ConsumerState<ContinueWatchingCarousel> createState() => _ContinueWatchingCarouselState();
}

class _ContinueWatchingCarouselState extends ConsumerState<ContinueWatchingCarousel> {
  List<ContinueWatchingItem> _items = [];
  bool _isLoading = true;
  int? _updatingTmdbId;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    try {
      final data = await ref.read(episodeRepositoryProvider).getContinueWatching(limit: 10);
      if (mounted) {
        setState(() {
          _items = data;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _quickMarkNext(ContinueWatchingItem item) async {
    if (item.nextEpisodeUp == null || _updatingTmdbId == item.tmdbId) return;

    final next = item.nextEpisodeUp!;
    HapticFeedback.lightImpact();

    setState(() => _updatingTmdbId = item.tmdbId);

    try {
      final res = await ref.read(episodeRepositoryProvider).toggleEpisodeWatch(
            tmdbId: item.tmdbId,
            seasonNumber: next.seasonNumber,
            episodeNumber: next.episodeNumber,
            isWatched: true,
          );

      if (mounted) {
        setState(() {
          _items = _items.map((it) {
            if (it.tmdbId == item.tmdbId) {
              return ContinueWatchingItem(
                entryId: it.entryId,
                tmdbId: it.tmdbId,
                title: it.title,
                posterPath: it.posterPath,
                backdropPath: it.backdropPath,
                currentSeason: next.seasonNumber,
                currentEpisode: next.episodeNumber,
                totalEpisodesWatched: it.totalEpisodesWatched + 1,
                totalEpisodesCount: it.totalEpisodesCount,
                progressPercentage: res.progressPercentage,
                nextEpisodeUp: res.nextEpisodeUp,
                lastWatchedAt: DateTime.now(),
              );
            }
            return it;
          }).toList();
        });

        widget.onProgressUpdated?.call();

        // Check if finished season
        if (res.nextEpisodeUp == null || res.nextEpisodeUp!.seasonNumber > next.seasonNumber) {
          WHAlert.showSuccess(
            context,
            'You completed Season ${next.seasonNumber} of ${item.title}! 🐝',
          );
        }
      }
    } catch (_) {
      if (mounted) {
        WHAlert.showError(context, 'Failed to update episode watch state.');
      }
    } finally {
      if (mounted) {
        setState(() => _updatingTmdbId = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  WHSkeletonBox(width: 20, height: 20, shape: BoxShape.circle),
                  SizedBox(width: 8),
                  WHSkeletonBox(width: 140, height: 16, borderRadius: 4),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 154,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: 3,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (_, __) => const WHSkeletonBox(
                  width: 260,
                  height: 154,
                  borderRadius: 18,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_items.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                const Icon(Icons.play_circle_rounded, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Continue Watching',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    '${_items.length} in progress',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 135,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: _items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final item = _items[index];
                final isUpdating = _updatingTmdbId == item.tmdbId;
                final next = item.nextEpisodeUp;

                return GestureDetector(
                  onTap: () => context.push('/details/tv/${item.tmdbId}'),
                  child: Container(
                    width: 275,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.border),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            // Poster Thumbnail
                            _ContinueWatchingPoster(item: item),
                            const SizedBox(width: 10),
                            // Title & Progress Bar
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _ContinueWatchingTitle(item: item),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary.withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          'S${item.currentSeason} • E${item.currentEpisode}',
                                          style: const TextStyle(
                                            fontFamily: 'Inter',
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                      ),
                                      if (item.totalEpisodesCount != null) ...[
                                        const SizedBox(width: 6),
                                        Text(
                                          '${item.totalEpisodesWatched}/${item.totalEpisodesCount} eps',
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
                                  const SizedBox(height: 6),
                                  // Honey progress bar
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: (item.progressPercentage.clamp(5, 100)) / 100.0,
                                      backgroundColor: AppColors.border,
                                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                                      minHeight: 4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        // Bottom Action Footer
                        Container(
                          padding: const EdgeInsets.only(top: 8),
                          decoration: const BoxDecoration(
                            border: Border(top: BorderSide(color: AppColors.border, width: 0.5)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  next != null
                                      ? 'Up Next: S${next.seasonNumber} E${next.episodeNumber}${next.name != null ? ' • ${next.name}' : ''}'
                                      : '🎉 All caught up!',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 11,
                                    fontWeight: next != null ? FontWeight.w700 : FontWeight.w800,
                                    color: next != null ? AppColors.textSecondary : AppColors.primary,
                                  ),
                                ),
                              ),
                              if (next != null)
                                GestureDetector(
                                  onTap: isUpdating ? null : () => _quickMarkNext(item),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: isUpdating
                                        ? const WHBeeSpinner(size: 12)
                                        : const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.check_rounded, size: 14, color: Colors.black),
                                              SizedBox(width: 4),
                                              Text(
                                                'Watched',
                                                style: TextStyle(
                                                  fontFamily: 'Inter',
                                                  fontSize: 10.5,
                                                  fontWeight: FontWeight.w800,
                                                  color: Colors.black,
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
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ContinueWatchingPoster extends ConsumerWidget {
  final ContinueWatchingItem item;

  const _ContinueWatchingPoster({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    String? posterPath = item.posterPath;

    // If posterPath was not supplied in the item, fall back to cached TMDb details
    if (posterPath == null || posterPath.isEmpty) {
      final detailsAsync = ref.watch(tmdbMediaDetailsProvider((tmdbId: item.tmdbId, mediaType: 'tv')));
      final tmdbPoster = (detailsAsync.value?['poster_path'] as String?) ??
          (detailsAsync.value?['backdrop_path'] as String?);
      if (tmdbPoster != null && tmdbPoster.isNotEmpty) {
        posterPath = tmdbPoster;
      }
    }

    final posterUrl = ApiEndpoints.tmdbPoster(posterPath);

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 44,
        height: 60,
        child: posterUrl.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: posterUrl,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  color: AppColors.surfaceElevated,
                  child: const Center(
                    child: WHBeeSpinner(size: 14),
                  ),
                ),
                errorWidget: (_, __, ___) => Container(
                  color: AppColors.surfaceElevated,
                  child: const Center(
                    child: Icon(Icons.tv_rounded, size: 20, color: AppColors.textMuted),
                  ),
                ),
              )
            : Container(
                color: AppColors.surfaceElevated,
                child: const Center(
                  child: Icon(Icons.tv_rounded, size: 20, color: AppColors.textMuted),
                ),
              ),
      ),
    );
  }
}

class _ContinueWatchingTitle extends ConsumerWidget {
  final ContinueWatchingItem item;

  const _ContinueWatchingTitle({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    String title = item.title;
    final isGeneric = title.isEmpty ||
        title == 'Untitled' ||
        title == 'this TV show' ||
        title.toLowerCase() == 'this title';

    if (isGeneric) {
      final detailsAsync = ref.watch(tmdbMediaDetailsProvider((tmdbId: item.tmdbId, mediaType: 'tv')));
      final tmdbTitle = (detailsAsync.value?['name'] as String?) ??
          (detailsAsync.value?['original_name'] as String?);
      if (tmdbTitle != null && tmdbTitle.isNotEmpty) {
        title = tmdbTitle;
      }
    }

    return Text(
      title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 13,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
      ),
    );
  }
}
