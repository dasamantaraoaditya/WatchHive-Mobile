import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/models/entry.dart';
import '../../../shared/widgets/shared_widgets.dart';
import '../repositories/entries_repository.dart';
import 'add_entry_sheet.dart';
import '../widgets/suggestions_tab.dart';
import '../widgets/watchlist_tab.dart';

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
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      itemCount: state.entries.length + (state.isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == state.entries.length) {
          return const Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
          );
        }
        final entry = state.entries[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _EntryListItem(
            entry: entry,
            onTap: () => context.push('/details/${entry.type == "MOVIE" ? "movie" : "tv"}/${entry.tmdbId}'),
            onDelete: () => ref.read(entriesProvider.notifier).deleteEntry(entry.id),
            onEdit: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => AddEntrySheet(editEntry: entry),
              );
            },
          ),
        );
      },
    );
  }
}

class _EntryListItem extends StatelessWidget {
  final Entry entry;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const _EntryListItem({
    required this.entry,
    required this.onTap,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            // Type icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  entry.type == 'MOVIE' ? '🎬' : '📺',
                  style: const TextStyle(fontSize: 22),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Title + meta
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.title,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (entry.rating != null) ...[
                        WHRatingStars(rating: entry.rating),
                        const SizedBox(width: 8),
                      ],
                      if (entry.isWatching)
                        const Text('▶ Watching', style: TextStyle(fontSize: 11, color: AppColors.info, fontWeight: FontWeight.w600))
                      else
                        Text(
                          DateFormat('MMM d, yyyy').format(entry.watchedAt),
                          style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                        ),
                    ],
                  ),
                  if (entry.tags.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      entry.tags.take(3).join(' · '),
                      style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            // More menu
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded, color: AppColors.textMuted, size: 20),
              color: AppColors.surfaceElevated,
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('Delete', style: TextStyle(color: AppColors.error)),
                ),
              ],
              onSelected: (value) {
                if (value == 'edit') onEdit();
                if (value == 'delete') onDelete();
              },
            ),
          ],
        ),
      ),
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
