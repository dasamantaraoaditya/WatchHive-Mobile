import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/error_handler.dart';
import '../../../shared/models/suggestion.dart';
import '../../../shared/models/user.dart';
import '../../../shared/widgets/shared_widgets.dart';
import '../../search/repositories/search_repository.dart';
import '../repositories/suggestions_repository.dart';
import 'suggest_movie_modal.dart';
import 'suggestion_card.dart';

class SuggestionsTab extends ConsumerStatefulWidget {
  final Function(int tmdbId, String mediaType, User? suggestor)? onTapMedia;

  const SuggestionsTab({super.key, this.onTapMedia});

  @override
  ConsumerState<SuggestionsTab> createState() => _SuggestionsTabState();
}

class _SuggestionsTabState extends ConsumerState<SuggestionsTab> {
  int _selectedSubTab = 0; // 0: Received Suggestions, 1: Suggested Items
  List<GroupedSuggestion> _receivedGroups = [];
  List<GroupedSuggestion> _sentGroups = [];
  bool _isLoading = true;
  String? _error;
  String _searchQuery = '';
  String _sortBy = 'recent-desc';

  static const _suggestionsSortOptions = [
    WHSortOption(value: 'recent-desc', label: 'Recently Suggested'),
    WHSortOption(value: 'recent-asc', label: 'Oldest Suggested'),
    WHSortOption(value: 'title-asc', label: 'Title: A-Z'),
    WHSortOption(value: 'title-desc', label: 'Title: Z-A'),
  ];

  @override
  void initState() {
    super.initState();
    _fetchSuggestions();
  }

  Future<void> _fetchSuggestions() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final repo = ref.read(suggestionsRepositoryProvider);
      final receivedFuture = repo.getMySuggestions().catchError((e) {
        return <GroupedSuggestion>[];
      });
      final sentFuture = repo.getSentSuggestions().catchError((e) {
        return <GroupedSuggestion>[];
      });

      final results = await Future.wait([receivedFuture, sentFuture]);
      if (mounted) {
        setState(() {
          _receivedGroups = results[0];
          _sentGroups = results[1];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = AppErrorHandler.toUserFriendlyMessage(e);
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildSubTabButton({
    required int index,
    required IconData icon,
    required String label,
    required int count,
  }) {
    final isSelected = _selectedSubTab == index;
    return GestureDetector(
      onTap: () {
        if (_selectedSubTab != index) {
          setState(() {
            _selectedSubTab = index;
          });
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.surfaceElevated : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary.withValues(alpha: 0.6) : AppColors.border,
            width: isSelected ? 1.2 : 0.8,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected ? AppColors.primary : AppColors.textMuted,
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected ? AppColors.textPrimary : AppColors.textMuted,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary.withValues(alpha: 0.15)
                    : AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? AppColors.primaryDark : AppColors.textMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentList = _selectedSubTab == 0 ? _receivedGroups : _sentGroups;
    final filteredGroups = currentList.where((g) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      final tmdbStr = g.tmdbId.toString();
      final names = _selectedSubTab == 0
          ? g.suggestors.map((s) => '${s.displayName} ${s.username}').join(' ').toLowerCase()
          : g.recipients.map((r) => '${r.displayName} ${r.username}').join(' ').toLowerCase();
      final mediaType = g.mediaType == 'tv' ? 'tv' : 'movie';
      final cachedDetails = ref.watch(tmdbMediaDetailsProvider((tmdbId: g.tmdbId, mediaType: mediaType))).value;
      final title = ((cachedDetails?['title'] ?? cachedDetails?['name'] ?? '') as String).toLowerCase();
      return tmdbStr.contains(q) || names.contains(q) || title.contains(q);
    }).toList();

    filteredGroups.sort((a, b) {
      final parts = _sortBy.split('-');
      final field = parts[0];
      final order = parts.length > 1 ? parts[1] : 'desc';

      if (field == 'recent') {
        final dateA = DateTime.tryParse(a.suggestions.firstOrNull?.createdAt ?? '')?.millisecondsSinceEpoch ?? 0;
        final dateB = DateTime.tryParse(b.suggestions.firstOrNull?.createdAt ?? '')?.millisecondsSinceEpoch ?? 0;
        return order == 'desc' ? dateB.compareTo(dateA) : dateA.compareTo(dateB);
      } else if (field == 'title') {
        final mediaTypeA = a.mediaType == 'tv' ? 'tv' : 'movie';
        final mediaTypeB = b.mediaType == 'tv' ? 'tv' : 'movie';
        final detailsA = ref.watch(tmdbMediaDetailsProvider((tmdbId: a.tmdbId, mediaType: mediaTypeA))).value;
        final detailsB = ref.watch(tmdbMediaDetailsProvider((tmdbId: b.tmdbId, mediaType: mediaTypeB))).value;
        final titleA = ((detailsA?['title'] ?? detailsA?['name'] ?? 'Movie #${a.tmdbId}') as String).toLowerCase();
        final titleB = ((detailsB?['title'] ?? detailsB?['name'] ?? 'Movie #${b.tmdbId}') as String).toLowerCase();
        return order == 'desc' ? titleB.compareTo(titleA) : titleA.compareTo(titleB);
      }
      return 0;
    });

    return RefreshIndicator(
      onRefresh: _fetchSuggestions,
      color: AppColors.primary,
      child: Column(
        children: [
          // Sub-tabs Toggle: Received Suggestions vs Suggested Items & Suggest to Friends Action
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: Row(
              children: [
                Expanded(
                  child: _buildSubTabButton(
                    index: 0,
                    icon: Icons.inbox_rounded,
                    label: 'Suggestions',
                    count: _receivedGroups.length,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildSubTabButton(
                    index: 1,
                    icon: Icons.send_rounded,
                    label: 'Suggested',
                    count: _sentGroups.length,
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () async {
                    await SuggestMovieModal.show(context);
                    _fetchSuggestions();
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    height: 38,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.auto_awesome, size: 14, color: AppColors.primaryDark),
                        SizedBox(width: 4),
                        Text(
                          'Suggest',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 11,
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
          ),

          // Filter & Search Bar
          WHFilterBar(
            search: _searchQuery,
            onSearchChanged: (val) => setState(() => _searchQuery = val.trim()),
            placeholder: _selectedSubTab == 0
                ? 'Search received recommendations…'
                : 'Search items you suggested…',
            sortBy: _sortBy,
            sortOptions: _suggestionsSortOptions,
            onSortChanged: (val) => setState(() => _sortBy = val),
            count: filteredGroups.length,
            countLabel: _searchQuery.isNotEmpty
                ? (_selectedSubTab == 0 ? 'Matching Suggestions' : 'Matching Items')
                : (_selectedSubTab == 0 ? 'Titles Suggested' : 'Items Suggested'),
            isLoading: _isLoading,
          ),

          Expanded(
            child: _isLoading
                ? const WHSkeletonGrid(
                    padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
                  )
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.cloud_off_rounded, size: 48, color: AppColors.textMuted),
                              const SizedBox(height: 14),
                              const Text(
                                'Could not load suggestions',
                                style: TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _error!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 13, color: AppColors.textMuted, height: 1.4),
                              ),
                              const SizedBox(height: 18),
                              ElevatedButton.icon(
                                onPressed: _fetchSuggestions,
                                icon: const Icon(Icons.refresh_rounded, size: 18),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.black,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                ),
                                label: const Text('Tap to Retry', style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ),
                      )
                    : filteredGroups.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.withValues(alpha: 0.1),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.amber.withValues(alpha: 0.2)),
                                    ),
                                    child: Icon(
                                      _selectedSubTab == 0 ? Icons.lightbulb_outline_rounded : Icons.send_rounded,
                                      size: 48,
                                      color: Colors.amber,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    _searchQuery.isNotEmpty
                                        ? 'No matches for "$_searchQuery"'
                                        : (_selectedSubTab == 0 ? 'No Received Suggestions' : 'No Suggested Items Yet'),
                                    style: const TextStyle(
                                      fontFamily: 'Inter',
                                      color: AppColors.textPrimary,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _searchQuery.isNotEmpty
                                        ? 'Try searching by a different name or ID'
                                        : (_selectedSubTab == 0
                                            ? 'When your cinephile friends recommend movies or TV shows to you, they will show up here!'
                                            : 'You haven\'t recommended any titles to friends yet. Spread your cinema taste!'),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontFamily: 'Inter',
                                      color: AppColors.textMuted,
                                      fontSize: 13,
                                      height: 1.4,
                                    ),
                                  ),
                                  const SizedBox(height: 18),
                                  ElevatedButton.icon(
                                    onPressed: () async {
                                      await SuggestMovieModal.show(context);
                                      _fetchSuggestions();
                                    },
                                    icon: const Icon(Icons.auto_awesome, size: 16),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      foregroundColor: Colors.black,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                                    ),
                                    label: const Text('Suggest to Friends', style: TextStyle(fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : CustomScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            slivers: [
                              SliverPadding(
                                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                                sliver: SliverGrid(
                                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    mainAxisSpacing: 14,
                                    crossAxisSpacing: 14,
                                    childAspectRatio: 0.63,
                                  ),
                                  delegate: SliverChildBuilderDelegate(
                                    (ctx, i) => SuggestionCard(
                                      group: filteredGroups[i],
                                      isSent: _selectedSubTab == 1,
                                      onRefresh: _fetchSuggestions,
                                      onTapMedia: widget.onTapMedia,
                                    ),
                                    childCount: filteredGroups.length,
                                  ),
                                ),
                              ),
                              const SliverToBoxAdapter(
                                child: Padding(
                                  padding: EdgeInsets.only(bottom: 80),
                                  child: WHBeeLoadingFooter(
                                    isLoadingMore: false,
                                    hasMore: false,
                                  ),
                                ),
                              ),
                            ],
                          ),
          ),
        ],
      ),
    );
  }
}
