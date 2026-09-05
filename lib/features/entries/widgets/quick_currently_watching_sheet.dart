import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/models/models.dart';
import '../../../shared/widgets/shared_widgets.dart';
import '../../search/repositories/search_repository.dart';
import '../repositories/entries_repository.dart';
import '../repositories/watchlist_repository.dart';
import '../screens/entries_screen.dart';

class QuickCurrentlyWatchingSheet extends ConsumerStatefulWidget {
  const QuickCurrentlyWatchingSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const QuickCurrentlyWatchingSheet(),
    );
  }

  @override
  ConsumerState<QuickCurrentlyWatchingSheet> createState() => _QuickCurrentlyWatchingSheetState();
}

class _QuickCurrentlyWatchingSheetState extends ConsumerState<QuickCurrentlyWatchingSheet> {
  final _searchController = TextEditingController();
  List<MediaResult> _searchResults = [];
  bool _isSearching = false;
  bool _isSubmitting = false;
  int? _submittingMediaId;
  Timer? _debounceTimer;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    final q = query.trim();
    if (q.length < 2) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 350), () => _performSearch(q));
  }

  Future<void> _performSearch(String query) async {
    setState(() => _isSearching = true);
    try {
      final results = await ref.read(searchRepositoryProvider).searchMedia(query);
      if (mounted) {
        setState(() {
          _searchResults = results.take(10).toList();
          _isSearching = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _handleSelectMovie(MediaResult media) async {
    if (_isSubmitting) return;

    final title = media.title;
    final cleanTitle = title.trim().isNotEmpty && title != 'Untitled'
        ? title.trim()
        : (media.mediaType == 'tv' ? 'this TV show' : 'this movie');

    final confirm = await WHAlert.confirm(
      context,
      title: 'Log as Currently Watching',
      message: 'Would you like to add "$cleanTitle" to your Currently Watching log?',
      confirmText: 'Add to Watching',
      severity: WHAlertSeverity.primary,
      icon: Icons.visibility_rounded,
    );

    if (!confirm || !mounted) return;

    setState(() {
      _isSubmitting = true;
      _submittingMediaId = media.id;
    });

    try {
      final apiType = media.mediaType == 'tv' ? 'TV_SHOW' : 'MOVIE';
      final entry = await ref.read(entriesRepositoryProvider).createEntry({
        'tmdbId': media.id,
        'title': title,
        'type': apiType,
        'isWatching': true,
        'startedAt': DateTime.now().toIso8601String(),
      });

      // Optimistically update entries tab if active
      ref.read(entriesProvider(true).notifier).addEntry(entry);

      // Clean up from watchlist if previously present
      try {
        await ref.read(watchlistRepositoryProvider).removeFromWatchlistByTmdbId(media.id);
      } catch (_) {}

      if (mounted) {
        Navigator.of(context).pop();
        WHAlert.showSuccess(
          context,
          '"$cleanTitle" added to your Currently Watching log! 👁️✨',
        );
      }
    } catch (e) {
      if (mounted) {
        WHAlert.showError(context, 'Failed to add "$cleanTitle" to Currently Watching: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _submittingMediaId = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag Handle
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.visibility_rounded, color: Colors.green, size: 22),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Log Currently Watching',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'Select a title to start tracking right now',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: AppColors.textMuted),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          const Divider(color: AppColors.border, height: 1),

          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: 'Search movies or TV shows...',
                hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
                prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primary),
                suffixIcon: _isSearching
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                        ),
                      )
                    : _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              _onSearchChanged('');
                            },
                          )
                        : null,
                filled: true,
                fillColor: AppColors.surfaceElevated,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                ),
              ),
              onChanged: _onSearchChanged,
            ),
          ),

          // Results List / Empty State
          Expanded(
            child: _buildResultsView(),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsView() {
    if (_searchController.text.trim().isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.search_rounded, size: 48, color: AppColors.textMuted.withValues(alpha: 0.5)),
              const SizedBox(height: 12),
              const Text(
                'Type a title to search',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Search millions of movies, anime & shows on TMDB',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      );
    }

    if (_searchResults.isEmpty && !_isSearching) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.movie_outlined, size: 48, color: AppColors.textMuted),
              const SizedBox(height: 12),
              Text(
                'No results found for "${_searchController.text}"',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _searchResults.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final item = _searchResults[i];
        final isTv = item.mediaType == 'tv';

        return InkWell(
          onTap: () => _handleSelectMovie(item),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: TMDBPosterImage(
                    posterPath: item.posterPath,
                    width: 48,
                    height: 68,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isTv ? Colors.blue.withValues(alpha: 0.15) : AppColors.primary.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isTv ? 'TV' : 'MOVIE',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: isTv ? Colors.blue : AppColors.primary,
                              ),
                            ),
                          ),
                          if (item.year.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Text(
                              item.year,
                              style: const TextStyle(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w600),
                            ),
                          ],
                          if (item.voteAverage != null && item.voteAverage! > 0) ...[
                            const SizedBox(width: 6),
                            Text(
                              '⭐ ${item.voteAverage!.toStringAsFixed(1)}',
                              style: const TextStyle(fontSize: 11, color: Colors.amber, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: _isSubmitting && _submittingMediaId == item.id
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.green,
                          ),
                        )
                      : const Icon(Icons.add_rounded, color: Colors.green, size: 20),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
