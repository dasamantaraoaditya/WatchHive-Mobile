import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/error_handler.dart';
import '../../../shared/models/entry.dart';
import '../../../shared/widgets/shared_widgets.dart';
import '../repositories/entries_repository.dart';
import 'add_entry_sheet.dart';
import '../widgets/quick_currently_watching_sheet.dart';
import '../widgets/suggestions_tab.dart';
import '../widgets/watchlist_tab.dart';
import '../widgets/wh_entry_grid_card.dart';
import '../../feed/providers/feed_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../profile/widgets/user_rankings_tab.dart';

// ─── Providers ───────────────────────────────────────────────────────────────

class EntriesState {
  final List<Entry> entries;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final String? typeFilter;
  final String searchQuery;
  final String sortBy;
  final String order;
  final bool isWatching;
  final String? error;

  const EntriesState({
    this.entries = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.typeFilter,
    this.searchQuery = '',
    required this.sortBy,
    required this.order,
    required this.isWatching,
    this.error,
  });

  EntriesState copyWith({
    List<Entry>? entries,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    String? typeFilter,
    String? searchQuery,
    String? sortBy,
    String? order,
    bool? isWatching,
    String? error,
    bool clearError = false,
  }) =>
      EntriesState(
        entries: entries ?? this.entries,
        isLoading: isLoading ?? this.isLoading,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        hasMore: hasMore ?? this.hasMore,
        typeFilter: typeFilter ?? this.typeFilter,
        searchQuery: searchQuery ?? this.searchQuery,
        sortBy: sortBy ?? this.sortBy,
        order: order ?? this.order,
        isWatching: isWatching ?? this.isWatching,
        error: clearError ? null : (error ?? this.error),
      );
}

final entriesProvider =
    StateNotifierProvider.family<EntriesNotifier, EntriesState, bool>((ref, isWatching) {
  return EntriesNotifier(ref.read(entriesRepositoryProvider), isWatching: isWatching);
});

class EntriesNotifier extends StateNotifier<EntriesState> {
  final EntriesRepository _repo;
  final bool isWatching;
  static const _pageSize = 20;

  EntriesNotifier(this._repo, {required this.isWatching})
      : super(EntriesState(
          isWatching: isWatching,
          sortBy: isWatching ? 'createdAt' : 'watchedAt',
          order: 'desc',
        )) {
    loadEntries();
  }

  Future<void> loadEntries({
    String? type,
    String? search,
    String? sortBy,
    String? order,
  }) async {
    final finalType = type ?? state.typeFilter;
    final finalSearch = search ?? state.searchQuery;
    final finalSortBy = sortBy ?? state.sortBy;
    final finalOrder = order ?? state.order;

    state = state.copyWith(
      isLoading: true,
      clearError: true,
      typeFilter: finalType,
      searchQuery: finalSearch,
      sortBy: finalSortBy,
      order: finalOrder,
    );
    try {
      final result = await _repo.getEntries(
        type: finalType,
        search: finalSearch.trim().isNotEmpty ? finalSearch.trim() : null,
        sortBy: finalSortBy,
        order: finalOrder,
        isWatching: isWatching,
        limit: _pageSize,
        offset: 0,
      );
      state = state.copyWith(
        entries: result.entries,
        isLoading: false,
        hasMore: result.pagination.hasMore,
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: AppErrorHandler.toUserFriendlyMessage(e));
    }
  }

  Future<void> refresh() async {
    try {
      final result = await _repo.getEntries(
        type: state.typeFilter,
        search: state.searchQuery.trim().isNotEmpty ? state.searchQuery.trim() : null,
        sortBy: state.sortBy,
        order: state.order,
        isWatching: isWatching,
        limit: _pageSize,
        offset: 0,
      );
      state = state.copyWith(
        entries: result.entries,
        isLoading: false,
        hasMore: result.pagination.hasMore,
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(error: AppErrorHandler.toUserFriendlyMessage(e));
    }
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoadingMore || state.isLoading) return;
    state = state.copyWith(isLoadingMore: true);
    try {
      final result = await _repo.getEntries(
        type: state.typeFilter,
        search: state.searchQuery.trim().isNotEmpty ? state.searchQuery.trim() : null,
        sortBy: state.sortBy,
        order: state.order,
        isWatching: isWatching,
        limit: _pageSize,
        offset: state.entries.length,
      );
      state = state.copyWith(
        entries: [...state.entries, ...result.entries],
        isLoadingMore: false,
        hasMore: result.pagination.hasMore,
      );
    } catch (_) {
      state = state.copyWith(isLoadingMore: false);
    }
  }

  void setSearch(String query) {
    if (state.searchQuery == query) return;
    loadEntries(search: query);
  }

  void setSort(String sortBy, String order) {
    if (state.sortBy == sortBy && state.order == order) return;
    loadEntries(sortBy: sortBy, order: order);
  }

  Future<void> deleteEntry(String id) async {
    await _repo.deleteEntry(id);
    state = state.copyWith(
      entries: state.entries.where((e) => e.id != id).toList(),
    );
  }

  void removeEntry(String id) {
    state = state.copyWith(
      entries: state.entries.where((e) => e.id != id).toList(),
    );
  }

  void addEntry(Entry entry) {
    if (entry.isWatching == isWatching) {
      final filtered = state.entries.where((e) => e.id != entry.id).toList();
      state = state.copyWith(entries: [entry, ...filtered]);
    } else {
      state = state.copyWith(
        entries: state.entries.where((e) => e.id != entry.id).toList(),
      );
    }
  }

  void updateEntry(Entry updated) {
    if (updated.isWatching == isWatching) {
      final exists = state.entries.any((e) => e.id == updated.id);
      if (exists) {
        state = state.copyWith(
          entries: state.entries.map((e) => e.id == updated.id ? updated : e).toList(),
        );
      } else {
        state = state.copyWith(entries: [updated, ...state.entries]);
      }
    } else {
      state = state.copyWith(
        entries: state.entries.where((e) => e.id != updated.id).toList(),
      );
    }
  }
}

// ─── Screen ──────────────────────────────────────────────────────────────────

class EntriesScreen extends ConsumerStatefulWidget {
  final int? initialIndex;

  const EntriesScreen({super.key, this.initialIndex});

  @override
  ConsumerState<EntriesScreen> createState() => _EntriesScreenState();
}

class _EntriesScreenState extends ConsumerState<EntriesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  static const _tabs = [
    'Currently Watching',
    'Watch History',
    'Watchlist',
    'Rankings',
    'Suggestions',
  ];

  @override
  void initState() {
    super.initState();
    final initial = widget.initialIndex != null &&
            widget.initialIndex! >= 0 &&
            widget.initialIndex! < _tabs.length
        ? widget.initialIndex!
        : 0;
    _tabController = TabController(
      length: _tabs.length,
      vsync: this,
      initialIndex: initial,
    );
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Widget _buildRankingsTab() {
    final currentUserId = ref.watch(authStateProvider).value?.user?.id;
    if (currentUserId == null || currentUserId.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    return UserRankingsTab(userId: currentUserId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const WHBrandLogo(logoSize: 28, fontSize: 20),
        actions: [
          if (_tabController.index == 3)
            IconButton(
              icon: const Icon(Icons.add_rounded, color: AppColors.primary, size: 24),
              tooltip: 'New Ranking Stack',
              onPressed: () => context.push('/rankings'),
            ),
          IconButton(
            icon: const Icon(Icons.psychology_outlined, color: AppColors.primary),
            tooltip: 'MindLens AI',
            onPressed: () => context.push('/mindlens'),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textMuted,
          tabs: _tabs.map((t) => Tab(text: t)).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          const _EntriesListTab(isWatching: true),
          const _EntriesListTab(isWatching: false),
          const WatchlistTab(),
          _buildRankingsTab(),
          SuggestionsTab(
            onTapMedia: (tmdbId, type, suggestor) => context.push(
              '/details/$type/$tmdbId',
              extra: suggestor != null ? {'suggestedByUser': suggestor, 'suggestedByUserId': suggestor.id} : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _EntriesListTab extends ConsumerStatefulWidget {
  final bool isWatching;

  const _EntriesListTab({required this.isWatching});

  @override
  ConsumerState<_EntriesListTab> createState() => _EntriesListTabState();
}

class _EntriesListTabState extends ConsumerState<_EntriesListTab>
    with AutomaticKeepAliveClientMixin {
  final _scrollController = ScrollController();
  Timer? _searchDebounce;
  String _search = '';

  static const _watchingSortOptions = [
    WHSortOption(value: 'createdAt-desc', label: 'Recently Added'),
    WHSortOption(value: 'createdAt-asc', label: 'Oldest Added'),
    WHSortOption(value: 'title-asc', label: 'Title: A-Z'),
    WHSortOption(value: 'title-desc', label: 'Title: Z-A'),
  ];

  static const _historySortOptions = [
    WHSortOption(value: 'watchedAt-desc', label: 'Recently Watched'),
    WHSortOption(value: 'watchedAt-asc', label: 'Oldest Watched'),
    WHSortOption(value: 'rating-desc', label: 'Highest Rated'),
    WHSortOption(value: 'rating-asc', label: 'Lowest Rated'),
    WHSortOption(value: 'title-asc', label: 'Movie: A-Z'),
    WHSortOption(value: 'title-desc', label: 'Movie: Z-A'),
  ];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      ref.read(entriesProvider(widget.isWatching).notifier).loadMore();
    }
  }

  void _onSearchChanged(String val) {
    setState(() => _search = val);
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) {
        ref.read(entriesProvider(widget.isWatching).notifier).setSearch(val);
      }
    });
  }

  void _onSortChanged(String val) {
    final parts = val.split('-');
    if (parts.length == 2) {
      ref.read(entriesProvider(widget.isWatching).notifier).setSort(parts[0], parts[1]);
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final state = ref.watch(entriesProvider(widget.isWatching));
    final sortKey = '${state.sortBy}-${state.order}';
    final sortOptions = widget.isWatching ? _watchingSortOptions : _historySortOptions;

    return Column(
      children: [
        // FilterBar matching web specifications
        WHFilterBar(
          search: _search,
          onSearchChanged: _onSearchChanged,
          placeholder: widget.isWatching
              ? 'Search currently watching list...'
              : 'Search logged movies, TV shows, or ratings...',
          sortBy: sortKey,
          sortOptions: sortOptions,
          onSortChanged: _onSortChanged,
          count: state.entries.length,
          countLabel: widget.isWatching
              ? (_search.isNotEmpty ? 'Matching Sessions' : 'Active Sessions')
              : (_search.isNotEmpty ? 'Matching Titles' : 'Logged Titles'),
          isLoading: state.isLoading && state.entries.isNotEmpty,
        ),

        Expanded(
          child: state.isLoading && state.entries.isEmpty
              ? const WHSkeletonGrid(
                  padding: EdgeInsets.fromLTRB(16, 6, 16, 16),
                )
              : state.error != null && state.entries.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.cloud_off_rounded, size: 48, color: AppColors.textMuted),
                            const SizedBox(height: 14),
                            Text(
                              widget.isWatching ? 'Could not load active watching list' : 'Could not load watch history',
                              style: const TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              state.error!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 13, color: AppColors.textMuted, height: 1.4),
                            ),
                            const SizedBox(height: 18),
                            ElevatedButton.icon(
                              onPressed: () => ref
                                  .read(entriesProvider(widget.isWatching).notifier)
                                  .loadEntries(),
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
                  : state.entries.isEmpty
                      ? RefreshIndicator(
                          onRefresh: () => ref.read(entriesProvider(widget.isWatching).notifier).refresh(),
                          color: AppColors.primary,
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            child: Container(
                              alignment: Alignment.center,
                              padding: const EdgeInsets.all(32),
                              height: MediaQuery.of(context).size.height * 0.60,
                              child: _EmptyEntries(
                                isWatching: widget.isWatching,
                                searchQuery: _search,
                              ),
                            ),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: () => ref.read(entriesProvider(widget.isWatching).notifier).refresh(),
                          color: AppColors.primary,
                          child: CustomScrollView(
                            controller: _scrollController,
                            physics: const AlwaysScrollableScrollPhysics(),
                            slivers: [
                              SliverPadding(
                                padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
                                sliver: SliverGrid(
                                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    mainAxisSpacing: 14,
                                    crossAxisSpacing: 14,
                                    childAspectRatio: 0.63,
                                  ),
                                  delegate: SliverChildBuilderDelegate(
                                    (context, index) {
                                      final entry = state.entries[index];
                                      return WHEntryGridCard(
                                        tmdbId: entry.tmdbId,
                                        title: entry.title,
                                        initialPosterPath: entry.posterPath,
                                        mediaType: entry.type,
                                        mode: entry.isWatching
                                            ? WHEntryCardMode.watching
                                            : WHEntryCardMode.history,
                                        rating: entry.rating,
                                        watchedAt: entry.watchedAt,
                                        startedAt: entry.startedAt ?? entry.createdAt,
                                        watchLocation: entry.watchLocation,
                                        tags: entry.tags,
                                        isPendingSync: entry.isPendingSync,
                                        onTap: () => context.push(
                                          '/details/${entry.type == "MOVIE" ? "movie" : "tv"}/${entry.tmdbId}',
                                          extra: entry,
                                        ),
                                        onMarkWatched: entry.isWatching
                                            ? () {
                                                showModalBottomSheet(
                                                  context: context,
                                                  isScrollControlled: true,
                                                  useRootNavigator: true,
                                                  backgroundColor: Colors.transparent,
                                                  builder: (_) => AddEntrySheet(
                                                    editEntry: entry,
                                                    prefillIsWatching: false,
                                                  ),
                                                );
                                              }
                                            : null,
                                        onEdit: () {
                                          showModalBottomSheet(
                                            context: context,
                                            isScrollControlled: true,
                                            useRootNavigator: true,
                                            backgroundColor: Colors.transparent,
                                            builder: (_) => AddEntrySheet(editEntry: entry),
                                          );
                                        },
                                        onDelete: () async {
                                          final confirm = await WHAlert.confirm(
                                            context,
                                            title: entry.isWatching ? 'Delete Session' : 'Delete Watch Entry',
                                            message: entry.isWatching
                                                ? 'Are you sure you want to delete this currently watching session for "${entry.title}"?'
                                                : 'Are you sure you want to delete your logged entry for "${entry.title}"? This action cannot be undone.',
                                            confirmText: 'Delete',
                                            severity: WHAlertSeverity.danger,
                                            icon: Icons.delete_outline_rounded,
                                          );
                                          if (confirm && context.mounted) {
                                            try {
                                              await ref
                                                  .read(entriesProvider(widget.isWatching).notifier)
                                                  .deleteEntry(entry.id);
                                              ref
                                                  .read(entriesProvider(!widget.isWatching).notifier)
                                                  .removeEntry(entry.id);
                                              ref.read(feedProvider.notifier).removeEntry(entry.id);
                                              if (context.mounted) {
                                                WHAlert.showSuccess(context, 'Deleted "${entry.title}"');
                                              }
                                            } catch (e) {
                                              if (context.mounted) {
                                                WHAlert.showError(context, AppErrorHandler.toUserFriendlyMessage(e, action: 'Failed to delete entry'));
                                              }
                                            }
                                          }
                                        },
                                      );
                                    },
                                    childCount: state.entries.length,
                                  ),
                                ),
                              ),

                              // Bottom loading / caught up indicator
                              SliverToBoxAdapter(
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: 80),
                                  child: WHBeeLoadingFooter(
                                    isLoadingMore: state.isLoadingMore,
                                    hasMore: state.hasMore,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
        ),
      ],
    );
  }
}

class _EmptyEntries extends StatelessWidget {
  final bool isWatching;
  final String searchQuery;

  const _EmptyEntries({
    required this.isWatching,
    this.searchQuery = '',
  });

  @override
  Widget build(BuildContext context) {
    if (searchQuery.isNotEmpty) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.search_off_rounded, size: 56, color: AppColors.textMuted),
          const SizedBox(height: 20),
          Text(
            isWatching ? 'No matching sessions' : 'No matching watch history',
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'We couldn\'t find any entries matching "$searchQuery"',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
        ],
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(isWatching ? Icons.play_circle_outline_rounded : Icons.history_rounded, size: 56, color: AppColors.textMuted),
        const SizedBox(height: 20),
        Text(
          isWatching ? 'Nothing currently watching' : 'No watch history yet',
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          isWatching
              ? 'Start watching a movie or TV show to track your progress.'
              : 'Log completed movies and series to build your history.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: () {
            if (isWatching) {
              QuickCurrentlyWatchingSheet.show(context);
            } else {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                useRootNavigator: true,
                backgroundColor: Colors.transparent,
                builder: (_) => const AddEntrySheet(),
              );
            }
          },
          icon: Icon(
            isWatching ? Icons.visibility_rounded : Icons.edit_note_rounded,
            size: 18,
            color: Colors.black,
          ),
          label: Text(
            isWatching ? 'Add Currently Watching 👁️' : 'Log Your First Watch 🎬',
            style: const TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w800,
              fontSize: 13.5,
              color: Colors.black,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
        ),
      ],
    );
  }
}

