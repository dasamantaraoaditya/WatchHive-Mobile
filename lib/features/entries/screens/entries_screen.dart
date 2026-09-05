import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/error_handler.dart';
import '../../../shared/models/entry.dart';
import '../../../shared/widgets/shared_widgets.dart';
import '../repositories/entries_repository.dart';
import 'add_entry_sheet.dart';
import '../widgets/suggestions_tab.dart';
import '../widgets/watchlist_tab.dart';
import '../widgets/wh_entry_grid_card.dart';

// ─── Providers ───────────────────────────────────────────────────────────────

class EntriesState {
  final List<Entry> entries;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final String? typeFilter;
  final bool isWatching;
  final String? error;

  const EntriesState({
    this.entries = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.typeFilter,
    required this.isWatching,
    this.error,
  });

  EntriesState copyWith({
    List<Entry>? entries,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    String? typeFilter,
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
      : super(EntriesState(isWatching: isWatching)) {
    loadEntries();
  }

  Future<void> loadEntries({String? type}) async {
    state = state.copyWith(isLoading: true, clearError: true, typeFilter: type);
    try {
      final result = await _repo.getEntries(
        type: type,
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
  const EntriesScreen({super.key});

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
    'Suggestions',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const WHBrandLogo(logoSize: 28, fontSize: 20),
        actions: [
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
          SuggestionsTab(
            onTapMedia: (tmdbId, type) => context.push('/details/$type/$tmdbId'),
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

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final state = ref.watch(entriesProvider(widget.isWatching));

    if (state.isLoading) {
      return const WHSkeletonGrid();
    }

    if (state.error != null && state.entries.isEmpty) {
      return Center(
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
      );
    }

    if (state.entries.isEmpty) {
      return RefreshIndicator(
        onRefresh: () =>
            ref.read(entriesProvider(widget.isWatching).notifier).refresh(),
        color: AppColors.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.all(32),
            height: MediaQuery.of(context).size.height * 0.65,
            child: _EmptyEntries(isWatching: widget.isWatching),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () =>
          ref.read(entriesProvider(widget.isWatching).notifier).refresh(),
      color: AppColors.primary,
      child: GridView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: 0.63,
        ),
        itemCount: state.entries.length,
        itemBuilder: (context, index) {
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
                title:
                    entry.isWatching ? 'Delete Session' : 'Delete Watch Entry',
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
                  if (context.mounted) {
                    WHAlert.showSuccess(context, 'Deleted "${entry.title}"');
                  }
                } catch (e) {
                  if (context.mounted) {
                    WHAlert.showError(context, 'Failed to delete entry: $e');
                  }
                }
              }
            },
          );
        },
      ),
    );
  }
}

class _EmptyEntries extends StatelessWidget {
  final bool isWatching;

  const _EmptyEntries({required this.isWatching});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(isWatching ? '🎬' : '🍿', style: const TextStyle(fontSize: 56)),
        const SizedBox(height: 20),
        Text(
          isWatching ? 'No active sessions' : 'No watch history yet',
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
              ? 'Start watching a movie or TV show to track your progress!'
              : 'Log your completed movies and TV shows to build your Hive!',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
