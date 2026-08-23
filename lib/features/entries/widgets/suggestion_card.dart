import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/models/suggestion.dart';
import '../repositories/entries_repository.dart';
import '../repositories/suggestions_repository.dart';
import '../../search/repositories/search_repository.dart';
import '../screens/add_entry_sheet.dart';

class SuggestionCard extends ConsumerStatefulWidget {
  final GroupedSuggestion group;
  final VoidCallback onRefresh;
  final Function(int tmdbId, String mediaType)? onTapMedia;

  const SuggestionCard({
    super.key,
    required this.group,
    required this.onRefresh,
    this.onTapMedia,
  });

  @override
  ConsumerState<SuggestionCard> createState() => _SuggestionCardState();
}

class _SuggestionCardState extends ConsumerState<SuggestionCard> {
  bool _isProcessing = false;

  Future<void> _handleAddToWatching() async {
    final firstSuggestor = widget.group.suggestors.isNotEmpty ? widget.group.suggestors.first : null;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        title: const Text('Log as Currently Watching'),
        content: const Text('Move this title to your Currently Watching log?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Add', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _isProcessing = true);
    try {
      final repo = ref.read(entriesRepositoryProvider);
      final suggRepo = ref.read(suggestionsRepositoryProvider);
      await repo.createEntry({
        'tmdbId': widget.group.tmdbId,
        'title': 'TMDB Title #${widget.group.tmdbId}',
        'type': widget.group.mediaType == 'tv' ? 'TV_SHOW' : 'MOVIE',
        'isWatching': true,
        'startedAt': DateTime.now().toIso8601String(),
        if (firstSuggestor != null) 'suggestedByUserId': firstSuggestor.id,
      });

      await Future.wait(widget.group.suggestions.map((s) => suggRepo.deleteSuggestion(s.id)));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Added to Currently Watching!')),
        );
        widget.onRefresh();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add to currently watching: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleMarkAsWatched() async {
    final firstSuggestor = widget.group.suggestors.isNotEmpty ? widget.group.suggestors.first : null;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AddEntrySheet(
        prefillTmdbId: widget.group.tmdbId,
        prefillType: widget.group.mediaType == 'tv' ? 'TV_SHOW' : 'MOVIE',
        prefillSuggestor: firstSuggestor,
        onSuccess: () {
          final suggRepo = ref.read(suggestionsRepositoryProvider);
          Future.wait(widget.group.suggestions.map((s) => suggRepo.deleteSuggestion(s.id)))
              .then((_) => widget.onRefresh())
              .catchError((_) => widget.onRefresh());
        },
      ),
    );
  }

  Future<void> _handleDelete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        title: const Text('Delete Suggestion'),
        content: const Text('Delete this suggestion from your list?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _isProcessing = true);
    try {
      final suggRepo = ref.read(suggestionsRepositoryProvider);
      await Future.wait(widget.group.suggestions.map((s) => suggRepo.deleteSuggestion(s.id)));
      if (mounted) widget.onRefresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete suggestion: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final firstSuggestor = widget.group.suggestors.isNotEmpty ? widget.group.suggestors.first : null;
    final mediaType = widget.group.mediaType == 'tv' ? 'tv' : 'movie';
    final tmdbId = widget.group.tmdbId;

    final detailsAsync = tmdbId > 0
        ? ref.watch(tmdbMediaDetailsProvider((tmdbId: tmdbId, mediaType: mediaType)))
        : null;

    final posterPath = detailsAsync?.value?['poster_path'] as String?;
    final title = detailsAsync?.value?['title'] as String? ??
        detailsAsync?.value?['name'] as String? ??
        'Title #$tmdbId';
    final posterUrl = ApiEndpoints.tmdbPoster(posterPath);

    return GestureDetector(
      onTap: () => widget.onTapMedia?.call(tmdbId, mediaType),
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
            // Poster Image Banner with Gradient & Badges
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

                  // Dark gradient overlay
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

                  // Top-Left Category Badge
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        mediaType == 'tv' ? '📺 TV' : '🎬 Movie',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),

                  // Top-Right Suggested By Avatar Pill
                  if (firstSuggestor != null)
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
                            CircleAvatar(
                              radius: 7,
                              backgroundColor: AppColors.primary,
                              backgroundImage: firstSuggestor.profilePictureUrl != null &&
                                      firstSuggestor.profilePictureUrl!.isNotEmpty
                                  ? NetworkImage(firstSuggestor.profilePictureUrl!)
                                  : null,
                              child: firstSuggestor.profilePictureUrl == null ||
                                      firstSuggestor.profilePictureUrl!.isEmpty
                                  ? Text(
                                      (firstSuggestor.displayName ?? firstSuggestor.username)[0].toUpperCase(),
                                      style: const TextStyle(fontSize: 7, color: Colors.white, fontWeight: FontWeight.bold),
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '@${firstSuggestor.username}',
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Bottom Title Overlay
                  Positioned(
                    bottom: 8,
                    left: 8,
                    right: 8,
                    child: Text(
                      title,
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
                  ),
                ],
              ),
            ),

            // Card Footer: Quick Action Buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: _isProcessing
                  ? const Center(child: SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2)))
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        IconButton(
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.all(4),
                          icon: const Icon(Icons.play_arrow_rounded, color: AppColors.info, size: 20),
                          tooltip: 'Log as Currently Watching',
                          onPressed: _handleAddToWatching,
                        ),
                        IconButton(
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.all(4),
                          icon: const Icon(Icons.check_circle_outline_rounded, color: Colors.greenAccent, size: 19),
                          tooltip: 'Mark as Watched',
                          onPressed: _handleMarkAsWatched,
                        ),
                        IconButton(
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.all(4),
                          icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 19),
                          tooltip: 'Delete Suggestion',
                          onPressed: _handleDelete,
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
