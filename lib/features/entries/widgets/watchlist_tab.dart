import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../repositories/watchlist_repository.dart';
import '../repositories/entries_repository.dart';
import '../../search/repositories/search_repository.dart';
import '../screens/add_entry_sheet.dart';

class WatchlistTab extends ConsumerStatefulWidget {
  const WatchlistTab({super.key});

  @override
  ConsumerState<WatchlistTab> createState() => _WatchlistTabState();
}

class _WatchlistTabState extends ConsumerState<WatchlistTab> {
  List<dynamic> _items = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchWatchlist();
  }

  Future<void> _fetchWatchlist() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final repo = ref.read(watchlistRepositoryProvider);
      final data = await repo.getWatchlist();
      if (mounted) {
        setState(() {
          _items = (data['items'] as List<dynamic>?) ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _removeItem(String itemId) async {
    try {
      await ref.read(watchlistRepositoryProvider).removeFromWatchlist(itemId);
      setState(() {
        _items.removeWhere((item) => item['id'] == itemId);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Removed from Watchlist')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to remove item: $e')),
        );
      }
    }
  }

  void _logWatchlistItem(Map<String, dynamic> item) {
    final tmdbId = (item['tmdbId'] as num?)?.toInt();
    final mediaType = item['mediaType'] == 'tv' ? 'TV_SHOW' : 'MOVIE';
    final itemId = item['id'] as String?;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddEntrySheet(
        prefillTmdbId: tmdbId,
        prefillType: mediaType,
        onSuccess: () {
          if (itemId != null) {
            _removeItem(itemId);
          }
        },
      ),
    );
  }

  Future<void> _addToCurrentlyWatching(Map<String, dynamic> item) async {
    final title = item['title'] as String? ?? 'this title';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        title: const Text('Log as Currently Watching'),
        content: Text('Move "$title" to your Currently Watching log?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Move to Watching', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      final tmdbId = (item['tmdbId'] as num?)?.toInt() ?? 0;
      final mediaType = item['mediaType'] == 'tv' ? 'TV_SHOW' : 'MOVIE';
      final itemId = item['id'] as String?;
      final suggestedByUser = item['suggestedByUser'] as Map<String, dynamic>?;
      final suggestedByUserId = item['suggestedByUserId'] as String? ?? suggestedByUser?['id'] as String?;

      await ref.read(entriesRepositoryProvider).createEntry({
        'tmdbId': tmdbId,
        'title': title,
        'type': mediaType,
        'isWatching': true,
        'startedAt': DateTime.now().toIso8601String(),
        if (suggestedByUserId != null) 'suggestedByUserId': suggestedByUserId,
      });

      if (itemId != null) {
        await _removeItem(itemId);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"$title" added to Currently Watching!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add to currently watching: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
            const SizedBox(height: 12),
            Text('Failed to load Watchlist: $_error', style: const TextStyle(color: AppColors.textMuted)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _fetchWatchlist,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              child: const Text('Retry', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }
    if (_items.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bookmark_border, size: 48, color: AppColors.textMuted),
            SizedBox(height: 12),
            Text(
              'Your Watchlist is empty',
              style: TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            SizedBox(height: 6),
            Text(
              'Save movies & shows you want to watch later.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchWatchlist,
      color: AppColors.primary,
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: 0.63,
        ),
        itemCount: _items.length,
        itemBuilder: (ctx, i) {
          final item = _items[i] as Map<String, dynamic>;
          final itemId = item['id'] as String;

          return _WatchlistGridCard(
            item: item,
            onLog: () => _logWatchlistItem(item),
            onMoveToWatching: () => _addToCurrentlyWatching(item),
            onDelete: () => _removeItem(itemId),
          );
        },
      ),
    );
  }
}

class _WatchlistGridCard extends ConsumerWidget {
  final Map<String, dynamic> item;
  final VoidCallback onLog;
  final VoidCallback onMoveToWatching;
  final VoidCallback onDelete;

  const _WatchlistGridCard({
    required this.item,
    required this.onLog,
    required this.onMoveToWatching,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tmdbId = (item['tmdbId'] as num?)?.toInt() ?? 0;
    final title = item['title'] as String? ?? 'Untitled';
    final initialPosterPath = item['posterPath'] as String?;
    final mediaType = item['mediaType'] == 'tv' ? 'tv' : 'movie';
    final suggestedByUser = item['suggestedByUser'] as Map<String, dynamic>?;
    final suggestorUsername = suggestedByUser?['username'] as String? ?? item['suggestedByUsername'] as String?;

    final detailsAsync = tmdbId > 0
        ? ref.watch(tmdbMediaDetailsProvider((tmdbId: tmdbId, mediaType: mediaType)))
        : null;

    final posterPath = initialPosterPath ?? detailsAsync?.value?['poster_path'] as String?;
    final voteAvg = (detailsAsync?.value?['vote_average'] as num?)?.toDouble();
    final releaseDate = detailsAsync?.value?['release_date'] as String? ?? detailsAsync?.value?['first_air_date'] as String?;
    final year = releaseDate != null && releaseDate.length >= 4 ? releaseDate.substring(0, 4) : null;
    final posterUrl = ApiEndpoints.tmdbPoster(posterPath);

    return GestureDetector(
      onTap: () {
        if (tmdbId > 0) context.push('/details/$mediaType/$tmdbId');
      },
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
                  if (suggestorUsername != null && suggestorUsername.isNotEmpty)
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
                              '@$suggestorUsername',
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
                    ),
                  Positioned(
                    bottom: 8,
                    left: 8,
                    right: 8,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
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
                        if (year != null || voteAvg != null) ...[
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              if (year != null)
                                Text(
                                  year,
                                  style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              if (year != null && voteAvg != null)
                                const Text(' • ', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                              if (voteAvg != null)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.star_rounded, color: AppColors.primary, size: 12),
                                    const SizedBox(width: 2),
                                    Text(
                                      voteAvg.toStringAsFixed(1),
                                      style: const TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(4),
                    icon: const Icon(Icons.play_arrow_rounded, color: AppColors.info, size: 20),
                    tooltip: 'Log as Currently Watching',
                    onPressed: onMoveToWatching,
                  ),
                  IconButton(
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(4),
                    icon: const Icon(Icons.check_circle_outline_rounded, color: Colors.greenAccent, size: 19),
                    tooltip: 'Mark as Watched (Hive It)',
                    onPressed: onLog,
                  ),
                  IconButton(
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(4),
                    icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 19),
                    tooltip: 'Remove from Watchlist',
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
