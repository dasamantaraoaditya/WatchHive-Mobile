import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/models/smart_suggest.dart';
import '../../auth/providers/auth_provider.dart';
import '../../entries/repositories/suggestions_repository.dart';
import '../../entries/repositories/watchlist_repository.dart';
import 'smart_suggest_deck_sheet.dart';

class SmartSuggestHeroCard extends ConsumerStatefulWidget {
  const SmartSuggestHeroCard({super.key});

  @override
  ConsumerState<SmartSuggestHeroCard> createState() => _SmartSuggestHeroCardState();
}

class _SmartSuggestHeroCardState extends ConsumerState<SmartSuggestHeroCard> {
  String _mode = 'social';
  List<SmartSuggestItem> _items = [];
  int _currentIndex = 0;
  bool _isLoading = true;
  bool _isDismissed = false;
  final Set<int> _watchlistedIds = {};

  @override
  void initState() {
    super.initState();
    _fetchPicks();
  }

  Future<void> _fetchPicks() async {
    final auth = ref.read(authStateProvider).value;
    if (auth == null || !auth.isAuthenticated) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _items = [];
        });
      }
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final repo = ref.read(suggestionsRepositoryProvider);
      final res = await repo.getSmartSuggestions(mode: _mode, limit: 6);
      if (mounted) {
        setState(() {
          _items = res.items;
          _currentIndex = 0;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
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

  void _handleShuffle() {
    if (_items.isEmpty) return;
    HapticFeedback.lightImpact();
    setState(() {
      _currentIndex = (_currentIndex + 1) % _items.length;
    });
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
    if (_isDismissed || _items.isEmpty) return const SizedBox.shrink();

    final currentItem = _currentIndex < _items.length
        ? _items[_currentIndex]
        : null;

    if (currentItem == null) return const SizedBox.shrink();

    final isSaved = _watchlistedIds.contains(currentItem.tmdbId);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(Icons.psychology, color: AppColors.primary, size: 16),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text.rich(
                  TextSpan(
                    text: 'SmartSuggest ',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                    ),
                    children: [
                      TextSpan(
                        text: 'Tonight',
                        style: TextStyle(
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Mode Pills
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildModeButton('social', 'Social'),
                    _buildModeButton('critic', 'Critic'),
                    _buildModeButton('explore', 'Explore'),
                  ],
                ),
              ),

              const SizedBox(width: 4),
              // Dismiss Button
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() {
                    _isDismissed = true;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(4),
                  child: const Icon(Icons.close, size: 16, color: AppColors.textSecondary),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Body
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Analyzing your hive taste...',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            GestureDetector(
              onTap: () {
                context.push('/details/${currentItem.mediaType}/${currentItem.tmdbId}');
              },
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Mini Poster
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 58,
                      height: 82,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          currentItem.posterPath != null
                              ? Image.network(
                                  'https://image.tmdb.org/t/p/w342${currentItem.posterPath}',
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    color: Colors.grey.shade900,
                                    child: const Icon(Icons.movie, size: 24, color: Colors.white24),
                                  ),
                                )
                              : Container(
                                  color: Colors.grey.shade900,
                                  child: const Icon(Icons.movie, size: 24, color: Colors.white24),
                                ),
                          if (currentItem.voteAverage > 0)
                            Positioned(
                              top: 4,
                              left: 4,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.8),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '★ ${currentItem.voteAverage.toStringAsFixed(1)}',
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${currentItem.score}% Match',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            if (currentItem.genreNames.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  currentItem.genreNames.first,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),

                        const SizedBox(height: 4),

                        Text(
                          currentItem.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textPrimary,
                          ),
                        ),

                        if (currentItem.badges.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                _getBadgeIcon(currentItem.badges.first.type),
                                size: 13,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  currentItem.badges.first.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
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

            const SizedBox(height: 10),

            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Shuffle button
                InkWell(
                  onTap: _handleShuffle,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Icon(Icons.cached, size: 17, color: AppColors.textPrimary),
                  ),
                ),

                const SizedBox(width: 6),

                // Watchlist button
                InkWell(
                  onTap: () => _toggleWatchlist(currentItem),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: isSaved
                          ? AppColors.primary.withValues(alpha: 0.15)
                          : AppColors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSaved ? AppColors.primary : AppColors.border,
                      ),
                    ),
                    child: Icon(
                      isSaved ? Icons.bookmark : Icons.bookmark_border,
                      size: 17,
                      color: isSaved ? AppColors.primary : AppColors.textPrimary,
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                // Explore Deck button
                ElevatedButton.icon(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    SmartSuggestDeckSheet.show(context, initialMode: _mode);
                  },
                  icon: const Icon(Icons.arrow_forward, size: 14),
                  label: const Text('Explore Deck'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.textPrimary,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildModeButton(String modeKey, String label) {
    final isSelected = _mode == modeKey;
    return GestureDetector(
      onTap: () => _onModeChanged(modeKey),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
            color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
