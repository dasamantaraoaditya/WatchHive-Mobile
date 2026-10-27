import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/models/smart_suggest.dart';
import '../repositories/watchlist_repository.dart';
import '../screens/add_entry_sheet.dart';

class SmartSuggestGridCard extends ConsumerStatefulWidget {
  final SmartSuggestItem item;
  final VoidCallback? onLogged;

  const SmartSuggestGridCard({
    super.key,
    required this.item,
    this.onLogged,
  });

  @override
  ConsumerState<SmartSuggestGridCard> createState() => _SmartSuggestGridCardState();
}

class _SmartSuggestGridCardState extends ConsumerState<SmartSuggestGridCard> {
  bool _isSaved = false;

  IconData _getBadgeIcon(String type) {
    switch (type) {
      case 'friend_pick':
        return Icons.group;
      case 'network_buzz':
        return Icons.local_fire_department;
      case 'critical_acclaim':
        return Icons.verified;
      case 'palate_cleanser':
        return Icons.cached;
      case 'taste_match':
        return Icons.auto_awesome;
      default:
        return Icons.star;
    }
  }

  Future<void> _toggleWatchlist() async {
    HapticFeedback.lightImpact();
    final item = widget.item;
    final repo = ref.read(watchlistRepositoryProvider);

    try {
      if (_isSaved) {
        await repo.removeFromWatchlistByTmdbId(item.tmdbId);
        setState(() => _isSaved = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Removed "${item.title}" from watchlist'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        await repo.addToWatchlist(
          tmdbId: item.tmdbId,
          mediaType: item.mediaType == 'tv' ? 'tv' : 'movie',
          title: item.title,
          posterPath: item.posterPath,
        );
        setState(() => _isSaved = true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Saved "${item.title}" to watchlist!'),
              backgroundColor: AppColors.primary,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (_) {}
  }

  void _openLogWatch() {
    HapticFeedback.lightImpact();
    final item = widget.item;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AddEntrySheet(
        prefillTmdbId: item.tmdbId,
        prefillType: item.mediaType == 'tv' ? 'tv' : 'movie',
        prefillTitle: item.title,
        prefillPosterPath: item.posterPath,
        prefillSuggestor: item.suggestedBy,
        prefillSuggestedByUserId: item.suggestedBy?.id,
        onSuccess: widget.onLogged,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final year = item.releaseDate != null && item.releaseDate!.length >= 4
        ? item.releaseDate!.substring(0, 4)
        : null;

    return GestureDetector(
      onTap: () {
        context.push('/details/${item.mediaType}/${item.tmdbId}');
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Poster
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  item.posterPath != null
                      ? Image.network(
                          'https://image.tmdb.org/t/p/w342${item.posterPath}',
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: Colors.grey.shade900,
                            child: const Icon(Icons.movie, size: 30, color: Colors.white24),
                          ),
                        )
                      : Container(
                          color: Colors.grey.shade900,
                          child: const Icon(Icons.movie, size: 30, color: Colors.white24),
                        ),

                  // Match Pill (top left)
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.82),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.5), width: 0.8),
                      ),
                      child: Text(
                        '${item.score}% Match',
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),

                  // TMDb Rating Pill (top right)
                  if (item.voteAverage > 0)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('★', style: TextStyle(color: AppColors.primary, fontSize: 9)),
                            const SizedBox(width: 2),
                            Text(
                              item.voteAverage.toStringAsFixed(1),
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Info & Actions
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Badges snippet
                  if (item.badges.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(bottom: 3),
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_getBadgeIcon(item.badges.first.type), size: 10, color: AppColors.primary),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(
                              item.badges.first.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    year != null
                        ? '$year • ${item.genreNames.isNotEmpty ? item.genreNames.first : item.mediaType.toUpperCase()}'
                        : (item.genreNames.isNotEmpty ? item.genreNames.first : item.mediaType.toUpperCase()),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),

                  const SizedBox(height: 6),

                  // Action Buttons Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Watchlist Button
                      InkWell(
                        onTap: _toggleWatchlist,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: _isSaved ? AppColors.primary.withValues(alpha: 0.15) : AppColors.surface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _isSaved ? AppColors.primary : AppColors.border,
                            ),
                          ),
                          child: Icon(
                            _isSaved ? Icons.bookmark : Icons.bookmark_border,
                            size: 15,
                            color: _isSaved ? AppColors.primary : AppColors.textSecondary,
                          ),
                        ),
                      ),

                      // Log Button
                      InkWell(
                        onTap: _openLogWatch,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.edit_note, size: 13, color: AppColors.primaryDark),
                              SizedBox(width: 2),
                              Text(
                                'Log',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryDark,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
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
