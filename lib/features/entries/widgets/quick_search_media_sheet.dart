import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/models/models.dart';
import '../../../shared/widgets/shared_widgets.dart';
import '../../search/repositories/search_repository.dart';
import '../repositories/watchlist_repository.dart';
import 'suggest_movie_modal.dart';

enum QuickSearchIntent {
  watchlist,
  suggest,
}

class QuickSearchMediaSheet extends ConsumerStatefulWidget {
  final QuickSearchIntent intent;

  const QuickSearchMediaSheet({
    super.key,
    required this.intent,
  });

  static Future<void> show(BuildContext context, {required QuickSearchIntent intent}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (_) => QuickSearchMediaSheet(intent: intent),
    );
  }

  @override
  ConsumerState<QuickSearchMediaSheet> createState() => _QuickSearchMediaSheetState();
}

class _QuickSearchMediaSheetState extends ConsumerState<QuickSearchMediaSheet> {
  final _searchController = TextEditingController();
  List<MediaResult> _searchResults = [];
  bool _isSearching = false;
  bool _isSubmitting = false;
  Timer? _debounceTimer;

  bool get _isWatchlist => widget.intent == QuickSearchIntent.watchlist;

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

    if (_isWatchlist) {
      final title = media.title;
      final cleanTitle = title.trim().isNotEmpty && title != 'Untitled'
          ? title.trim()
          : (media.mediaType == 'tv' ? 'this TV show' : 'this movie');

      final confirm = await WHAlert.confirm(
        context,
        title: 'Add to Watchlist',
        message: 'Would you like to add "$cleanTitle" to your Watchlist?',
        confirmText: 'Add to Watchlist',
        severity: WHAlertSeverity.primary,
        icon: Icons.bookmark_add_rounded,
      );

      if (!confirm || !mounted) return;

      setState(() => _isSubmitting = true);
      try {
        await ref.read(watchlistRepositoryProvider).addToWatchlist(
          tmdbId: media.id,
          title: title,
          mediaType: media.mediaType,
          posterPath: media.posterPath,
          overview: media.overview,
        );

        if (mounted) {
          Navigator.of(context).pop();
          WHAlert.showSuccess(
            context,
            'Added "$cleanTitle" to your Watchlist! 📌',
          );
        }
      } catch (e) {
        if (mounted) {
          WHAlert.showError(context, 'Failed to add "$cleanTitle" to Watchlist: $e');
        }
      } finally {
        if (mounted) setState(() => _isSubmitting = false);
      }
    } else {
      // Suggest intent
      Navigator.of(context).pop();
      SuggestMovieModal.show(
        context,
        tmdbId: media.id,
        title: media.title,
        mediaType: media.mediaType,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final titleText = _isWatchlist ? 'Add to Watchlist' : 'Suggest to Friends';
    final subtitleText = _isWatchlist
        ? 'Select a movie or show to save for later'
        : 'Search a title to recommend to cinephiles';
    final headerIcon = _isWatchlist ? Icons.bookmark_add_rounded : Icons.send_rounded;
    final headerColor = _isWatchlist ? AppColors.primary : const Color(0xFFA855F7);

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
                    color: headerColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(headerIcon, color: headerColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titleText,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        subtitleText,
                        style: const TextStyle(
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
                prefixIcon: Icon(Icons.search_rounded, color: headerColor),
                suffixIcon: _isSearching
                    ? Padding(
                        padding: const EdgeInsets.all(12),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: headerColor),
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
                  borderSide: BorderSide(color: headerColor, width: 1.5),
                ),
              ),
              onChanged: _onSearchChanged,
            ),
          ),

          // Results List / Empty State
          Expanded(
            child: _buildResultsView(headerColor),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsView(Color actionColor) {
    if (_searchController.text.trim().isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.search_rounded, size: 48, color: AppColors.textMuted.withOpacity(0.5)),
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
                'Search millions of titles from TMDB',
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
                              color: isTv ? Colors.blue.withOpacity(0.15) : AppColors.primary.withOpacity(0.2),
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
                    color: actionColor.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isWatchlist ? Icons.bookmark_add_rounded : Icons.arrow_forward_rounded,
                    color: actionColor,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
