import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/models/smart_suggest.dart';
import '../../entries/repositories/suggestions_repository.dart';
import '../../entries/repositories/watchlist_repository.dart';
import '../../entries/screens/add_entry_sheet.dart';

class SmartSuggestDeckSheet extends ConsumerStatefulWidget {
  final String initialMode;

  const SmartSuggestDeckSheet({
    super.key,
    this.initialMode = 'social',
  });

  static Future<void> show(BuildContext context, {String initialMode = 'social'}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SmartSuggestDeckSheet(initialMode: initialMode),
    );
  }

  @override
  ConsumerState<SmartSuggestDeckSheet> createState() => _SmartSuggestDeckSheetState();
}

class _SmartSuggestDeckSheetState extends ConsumerState<SmartSuggestDeckSheet> {
  late String _mode;
  List<SmartSuggestItem> _items = [];
  bool _isLoading = true;
  String? _error;
  late final PageController _pageController;
  int _currentIndex = 0;
  final Set<int> _watchlistedIds = {};

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
    _pageController = PageController(viewportFraction: 0.9);
    _fetchPicks();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _fetchPicks() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final repo = ref.read(suggestionsRepositoryProvider);
      final res = await repo.getSmartSuggestions(mode: _mode, limit: 10);
      if (mounted) {
        setState(() {
          _items = res.items;
          _isLoading = false;
          _currentIndex = 0;
        });
        if (_pageController.hasClients) {
          _pageController.jumpToPage(0);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Could not load recommendations';
          _isLoading = false;
        });
      }
    }
  }

  void _onModeChanged(String newMode) {
    if (_mode == newMode) return;
    HapticFeedback.selectionClick();
    setState(() {
      _mode = newMode;
    });
    _fetchPicks();
  }

  Future<void> _toggleWatchlist(SmartSuggestItem item) async {
    HapticFeedback.lightImpact();
    final tmdbId = item.tmdbId;
    final isAlready = _watchlistedIds.contains(tmdbId);

    try {
      final repo = ref.read(watchlistRepositoryProvider);
      if (isAlready) {
        await repo.removeFromWatchlistByTmdbId(tmdbId);
        setState(() {
          _watchlistedIds.remove(tmdbId);
        });
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
          tmdbId: tmdbId,
          mediaType: item.mediaType == 'tv' ? 'tv' : 'movie',
          title: item.title,
          posterPath: item.posterPath,
        );
        setState(() {
          _watchlistedIds.add(tmdbId);
        });
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update watchlist')),
        );
      }
    }
  }

  void _openAddEntry(SmartSuggestItem item) {
    HapticFeedback.lightImpact();
    Navigator.of(context).pop();
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
      ),
    );
  }

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

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Container(
      constraints: BoxConstraints(
        maxHeight: size.height * 0.9,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag Handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textMuted.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header Row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.psychology, color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SmartSuggest Deck',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'Personalized AI Recommendation Engine',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20, color: AppColors.textSecondary),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Mode Selector Chips
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  _buildModeChip('social', 'Hive Mind', Icons.group),
                  const SizedBox(width: 6),
                  _buildModeChip('critic', 'Certified Gold', Icons.verified),
                  const SizedBox(width: 6),
                  _buildModeChip('explore', 'Palate Cleanser', Icons.cached),
                ],
              ),
            ),

            const Divider(height: 1, color: AppColors.border),

            // Body
            Flexible(
              child: _isLoading
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 80),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(color: AppColors.primary),
                            SizedBox(height: 16),
                            Text(
                              'Analyzing your hive taste...',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : _error != null
                      ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 24),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.error_outline, size: 40, color: AppColors.textSecondary),
                                const SizedBox(height: 12),
                                Text(
                                  _error!,
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                ),
                                const SizedBox(height: 12),
                                ElevatedButton(
                                  onPressed: _fetchPicks,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: AppColors.textPrimary,
                                  ),
                                  child: const Text('Try Again'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : _items.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.symmetric(vertical: 60, horizontal: 24),
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.movie_filter, size: 44, color: AppColors.primary),
                                    SizedBox(height: 12),
                                    Text(
                                      'No recommendations yet',
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                                    ),
                                    SizedBox(height: 6),
                                    Text(
                                      'Log more movies and shows to train your personal SmartSuggest engine!',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : PageView.builder(
                              controller: _pageController,
                              itemCount: _items.length,
                              onPageChanged: (idx) {
                                setState(() {
                                  _currentIndex = idx;
                                });
                              },
                              itemBuilder: (ctx, index) {
                                return _buildCard(_items[index]);
                              },
                            ),
            ),

            // Bottom Navigation & Counter Indicator
            if (!_isLoading && _items.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left, color: AppColors.textPrimary),
                      onPressed: _currentIndex > 0
                          ? () => _pageController.previousPage(
                                duration: const Duration(milliseconds: 250),
                                curve: Curves.easeOut,
                              )
                          : null,
                    ),
                    Text(
                      '${_currentIndex + 1} of ${_items.length}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right, color: AppColors.textPrimary),
                      onPressed: _currentIndex < _items.length - 1
                          ? () => _pageController.nextPage(
                                duration: const Duration(milliseconds: 250),
                                curve: Curves.easeOut,
                              )
                          : null,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeChip(String modeKey, String label, IconData icon) {
    final isSelected = _mode == modeKey;
    return Expanded(
      child: GestureDetector(
        onTap: () => _onModeChanged(modeKey),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.border,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14,
                color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                    color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCard(SmartSuggestItem item) {
    final year = item.releaseDate != null && item.releaseDate!.length >= 4
        ? item.releaseDate!.substring(0, 4)
        : null;
    final isSaved = _watchlistedIds.contains(item.tmdbId);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Poster with Badges
            GestureDetector(
              onTap: () {
                Navigator.of(context).pop();
                context.push('/details/${item.mediaType}/${item.tmdbId}');
              },
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: item.backdropPath != null || item.posterPath != null
                          ? Image.network(
                              'https://image.tmdb.org/t/p/w780${item.backdropPath ?? item.posterPath}',
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: Colors.grey.shade900,
                                child: const Icon(Icons.movie, size: 40, color: Colors.white24),
                              ),
                            )
                          : Container(
                              color: Colors.grey.shade900,
                              child: const Icon(Icons.movie, size: 40, color: Colors.white24),
                            ),
                    ),
                  ),

                  // Match Score Pill
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.6)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.bolt, size: 14, color: AppColors.primary),
                          const SizedBox(width: 4),
                          Text(
                            '${item.score}% Match',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Rating Pill
                  if (item.voteAverage > 0)
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('★', style: TextStyle(color: AppColors.primary, fontSize: 12)),
                            const SizedBox(width: 4),
                            Text(
                              item.voteAverage.toStringAsFixed(1),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Media Type
                  Positioned(
                    bottom: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        item.mediaType.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          color: Colors.white70,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Badges row
            if (item.badges.isNotEmpty)
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: item.badges.take(2).map((badge) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_getBadgeIcon(badge.type), size: 12, color: AppColors.primary),
                        const SizedBox(width: 4),
                        Text(
                          badge.label,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),

            const SizedBox(height: 8),

            // Title & Meta
            Text(
              item.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                if (year != null) ...[
                  Text(
                    year,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (item.genreNames.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    const Text('•', style: TextStyle(color: AppColors.textSecondary)),
                    const SizedBox(width: 6),
                  ],
                ],
                if (item.genreNames.isNotEmpty)
                  Expanded(
                    child: Text(
                      item.genreNames.take(2).join(', '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
              ],
            ),

            if (item.overview != null && item.overview!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                item.overview!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
            ],

            const SizedBox(height: 14),

            // Action Row
            Row(
              children: [
                // Watchlist Toggle
                InkWell(
                  onTap: () => _toggleWatchlist(item),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSaved
                          ? AppColors.primary.withValues(alpha: 0.15)
                          : AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSaved ? AppColors.primary : AppColors.border,
                      ),
                    ),
                    child: Icon(
                      isSaved ? Icons.bookmark : Icons.bookmark_border,
                      size: 18,
                      color: isSaved ? AppColors.primary : AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Log Watch
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _openAddEntry(item),
                    icon: const Icon(Icons.edit_note, size: 16),
                    label: const Text('Log Watch'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      side: const BorderSide(color: AppColors.border),
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // View Details
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      context.push('/details/${item.mediaType}/${item.tmdbId}');
                    },
                    icon: const Icon(Icons.arrow_forward, size: 15),
                    label: const Text('Details'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.textPrimary,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
