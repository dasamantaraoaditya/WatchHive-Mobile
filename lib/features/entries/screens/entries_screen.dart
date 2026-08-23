import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../shared/models/entry.dart';
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
    return GridView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 0.65,
      ),
      itemCount: state.entries.length,
      itemBuilder: (context, index) {
        final entry = state.entries[index];
        return _EntryGridCard(
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
        );
      },
    );
  }
}

class _EntryGridCard extends ConsumerWidget {
  final Entry entry;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const _EntryGridCard({
    required this.entry,
    required this.onTap,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final imageUrl = ApiEndpoints.tmdbPoster(entry.posterPath);

    return GestureDetector(
      onTap: onTap,
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
            // Poster Image Banner with Gradient & Badges
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: imageUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: imageUrl,
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

                  // Dark gradient overlay for title legibility
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: const [0.5, 1.0],
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.85),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Top-Left Category Badge
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
                        entry.type == 'MOVIE' ? '🎬 Movie' : '📺 TV',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),

                  // Top-Right Badge: Rating or Watching Indicator
                  if (entry.isWatching)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.info.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          '▶ Watching',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    )
                  else if (entry.rating != null)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star_rounded, color: AppColors.primary, size: 13),
                            const SizedBox(width: 3),
                            Text(
                              entry.rating!.toStringAsFixed(1),
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Bottom Title & Tags Overlay
                  Positioned(
                    bottom: 8,
                    left: 8,
                    right: 8,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.title,
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
                        if (entry.tags.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            entry.tags.take(2).map((t) => '#$t').join(' '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Card Footer: Date & Actions
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      entry.isWatching
                          ? 'Active Session'
                          : DateFormat('MMM d, yyyy').format(entry.watchedAt),
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                  PopupMenuButton<String>(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.more_vert_rounded, color: AppColors.textMuted, size: 18),
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
