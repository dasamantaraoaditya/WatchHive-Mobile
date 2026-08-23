import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/models/entry.dart';
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
  final bool? isWatchingFilter;
  final String? error;

  const EntriesState({
    this.entries = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.typeFilter,
    this.isWatchingFilter,
    this.error,
  });

  EntriesState copyWith({
    List<Entry>? entries,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    String? typeFilter,
    bool? isWatchingFilter,
    String? error,
  }) =>
      EntriesState(
        entries: entries ?? this.entries,
        isLoading: isLoading ?? this.isLoading,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        hasMore: hasMore ?? this.hasMore,
        typeFilter: typeFilter ?? this.typeFilter,
        isWatchingFilter: isWatchingFilter ?? this.isWatchingFilter,
        error: error,
      );
}

final entriesProvider = StateNotifierProvider<EntriesNotifier, EntriesState>((ref) {
  return EntriesNotifier(ref.read(entriesRepositoryProvider));
});

class EntriesNotifier extends StateNotifier<EntriesState> {
  final EntriesRepository _repo;
  static const _pageSize = 20;

  EntriesNotifier(this._repo) : super(const EntriesState()) {
    loadEntries();
  }

  Future<void> loadEntries({String? type, bool? isWatching}) async {
    state = state.copyWith(isLoading: true, error: null, typeFilter: type, isWatchingFilter: isWatching);
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
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoadingMore) return;
    state = state.copyWith(isLoadingMore: true);
    try {
      final result = await _repo.getEntries(
        type: state.typeFilter,
        isWatching: state.isWatchingFilter,
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

  void addEntry(Entry entry) {
    state = state.copyWith(entries: [entry, ...state.entries]);
  }

  void updateEntry(Entry updated) {
    state = state.copyWith(
      entries: state.entries.map((e) => e.id == updated.id ? updated : e).toList(),
    );
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
  final _scrollController = ScrollController();
  late final TabController _tabController;

  final _tabs = [
    (label: 'Currently Watching', type: null, isWatching: true, isSuggestions: false, isWatchlist: false),
    (label: 'Watch History', type: null, isWatching: false, isSuggestions: false, isWatchlist: false),
    (label: 'Watchlist', type: null, isWatching: null, isSuggestions: false, isWatchlist: true),
    (label: 'Suggestions', type: null, isWatching: null, isSuggestions: true, isWatchlist: false),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
        final tab = _tabs[_tabController.index];
        if (!tab.isSuggestions && !tab.isWatchlist) {
          ref.read(entriesProvider.notifier).loadEntries(
                type: tab.type,
                isWatching: tab.isWatching,
              );
        }
      }
    });
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 300) {
      ref.read(entriesProvider.notifier).loadMore();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _showAddEntry() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AddEntrySheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(entriesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Entries', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
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
          tabs: _tabs.map((t) => Tab(text: t.label)).toList(),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddEntry,
        tooltip: 'Log Movie or Show',
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Log Movie',
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildEntriesList(state),
          _buildEntriesList(state),
          const WatchlistTab(),
          SuggestionsTab(
            onTapMedia: (tmdbId, type) => context.push('/details/$type/$tmdbId'),
          ),
        ],
      ),
    );
  }

  Widget _buildEntriesList(EntriesState state) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (state.entries.isEmpty) {
      return const _EmptyEntries();
    }
    return GridView.builder(
      controller: _scrollController,
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
          mode: entry.isWatching ? WHEntryCardMode.watching : WHEntryCardMode.history,
          rating: entry.rating,
          watchedAt: entry.watchedAt,
          tags: entry.tags,
          onTap: () => context.push('/details/${entry.type == "MOVIE" ? "movie" : "tv"}/${entry.tmdbId}'),
          onEdit: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => AddEntrySheet(editEntry: entry),
            );
          },
          onDelete: () => ref.read(entriesProvider.notifier).deleteEntry(entry.id),
        );
      },
    );
  }
}

class _EmptyEntries extends StatelessWidget {
  const _EmptyEntries();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('📋', style: TextStyle(fontSize: 56)),
            SizedBox(height: 20),
            Text(
              'No entries yet',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Log your first movie or show!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
