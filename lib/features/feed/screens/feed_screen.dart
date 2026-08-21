import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/models/entry.dart';
import '../../../shared/widgets/shared_widgets.dart';
import '../repositories/feed_repository.dart';
import '../../auth/providers/auth_provider.dart';

// Feed state
class FeedState {
  final List<Entry> entries;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final String? error;
  final Set<String> likedEntryIds;

  const FeedState({
    this.entries = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.error,
    this.likedEntryIds = const {},
  });

  FeedState copyWith({
    List<Entry>? entries,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    String? error,
    Set<String>? likedEntryIds,
  }) =>
      FeedState(
        entries: entries ?? this.entries,
        isLoading: isLoading ?? this.isLoading,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        hasMore: hasMore ?? this.hasMore,
        error: error,
        likedEntryIds: likedEntryIds ?? this.likedEntryIds,
      );
}

final feedProvider = StateNotifierProvider<FeedNotifier, FeedState>((ref) {
  return FeedNotifier(ref.read(feedRepositoryProvider));
});

class FeedNotifier extends StateNotifier<FeedState> {
  final FeedRepository _repo;
  static const _pageSize = 20;

  FeedNotifier(this._repo) : super(const FeedState()) {
    loadFeed();
  }

  Future<void> loadFeed() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await _repo.getFeed(limit: _pageSize, offset: 0);
      state = state.copyWith(
        entries: result.entries,
        isLoading: false,
        hasMore: result.pagination.hasMore,
      );
    } catch (e, stackTrace) {
      debugPrint('Feed load error: $e');
      debugPrint('Feed stack trace: $stackTrace');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoadingMore) return;
    state = state.copyWith(isLoadingMore: true);
    try {
      final result = await _repo.getFeed(limit: _pageSize, offset: state.entries.length);
      state = state.copyWith(
        entries: [...state.entries, ...result.entries],
        isLoadingMore: false,
        hasMore: result.pagination.hasMore,
      );
    } catch (_) {
      state = state.copyWith(isLoadingMore: false);
    }
  }

  Future<void> toggleLike(String entryId) async {
    final isLiked = state.likedEntryIds.contains(entryId);
    final newLiked = Set<String>.from(state.likedEntryIds);
    if (isLiked) {
      newLiked.remove(entryId);
    } else {
      newLiked.add(entryId);
    }
    state = state.copyWith(likedEntryIds: newLiked);
    try {
      if (isLiked) {
        await _repo.unlikeEntry(entryId);
      } else {
        await _repo.likeEntry(entryId);
      }
    } catch (_) {
      // Revert on failure
      state = state.copyWith(likedEntryIds: Set<String>.from(state.likedEntryIds)..toggle(entryId));
    }
  }
}

extension on Set<String> {
  void toggle(String value) {
    if (contains(value)) {
      remove(value);
    } else {
      add(value);
    }
  }
}

// ─── Screen ─────────────────────────────────────────────────────────────────

class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      ref.read(feedProvider.notifier).loadMore();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final feedState = ref.watch(feedProvider);
    final currentUser = ref.watch(authStateProvider).value?.user;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverAppBar(
            floating: true,
            title: const Text('WatchHive', style: TextStyle(color: AppColors.primary)),
            actions: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                onPressed: () => context.push('/notifications'),
              ),
            ],
          ),
          if (feedState.isLoading)
            const SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: AppColors.primary)))
          else if (feedState.error != null && feedState.entries.isEmpty)
            SliverFillRemaining(
              child: _EmptyFeed(onRefresh: () => ref.read(feedProvider.notifier).loadFeed()),
            )
          else if (feedState.entries.isEmpty)
            const SliverFillRemaining(child: _EmptyFeed())
          else ...[
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              sliver: SliverList.builder(
                itemCount: feedState.entries.length + (feedState.isLoadingMore ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == feedState.entries.length) {
                    return const Padding(
                      padding: EdgeInsets.all(20),
                      child: Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2)),
                    );
                  }
                  final entry = feedState.entries[index];
                  final isLiked = feedState.likedEntryIds.contains(entry.id);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _FeedCard(
                      entry: entry,
                      isLiked: isLiked,
                      isOwnEntry: currentUser?.id == entry.userId,
                      onLike: () => ref.read(feedProvider.notifier).toggleLike(entry.id),
                      onUserTap: () => context.push('/profile/${entry.user?.id}'),
                      onMediaTap: () => context.push(
                        '/details/${entry.type == "MOVIE" ? "movie" : "tv"}/${entry.tmdbId}',
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FeedCard extends StatelessWidget {
  final Entry entry;
  final bool isLiked;
  final bool isOwnEntry;
  final VoidCallback onLike;
  final VoidCallback onUserTap;
  final VoidCallback onMediaTap;

  const _FeedCard({
    required this.entry,
    required this.isLiked,
    required this.isOwnEntry,
    required this.onLike,
    required this.onUserTap,
    required this.onMediaTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Avatar + Username + Time
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                GestureDetector(
                  onTap: onUserTap,
                  child: WHAvatar(
                    imageUrl: entry.user?.profilePictureUrl,
                    name: entry.user?.name,
                    radius: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: onUserTap,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.user?.displayName ?? entry.user?.username ?? 'User',
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          '@${entry.user?.username ?? ""}',
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Text(
                  _timeAgo(entry.watchedAt),
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),

          // Media info
          GestureDetector(
            onTap: onMediaTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      entry.type == 'MOVIE' ? '🎬 Movie' : '📺 TV Show',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  if (entry.suggestedByUser != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.amber.withOpacity(0.4)),
                      ),
                      child: Text(
                        '💡 Suggested by @${entry.suggestedByUser!.username}',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.amber,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(width: 8),
                  if (entry.isRewatch)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.info.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        '🔁 Rewatch',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.info,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: GestureDetector(
              onTap: onMediaTap,
              child: Text(
                entry.title,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),

          if (entry.rating != null) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: WHRatingStars(rating: entry.rating),
            ),
          ],

          if (entry.review != null && entry.review!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Text(
                entry.review!,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
            ),
          ],

          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.border),

          // Action bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Row(
              children: [
                _ActionButton(
                  icon: isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  label: '${entry.likesCount + (isLiked ? 1 : 0)}',
                  color: isLiked ? AppColors.error : AppColors.textMuted,
                  onTap: onLike,
                ),
                _ActionButton(
                  icon: Icons.chat_bubble_outline_rounded,
                  label: '${entry.commentsCount}',
                  color: AppColors.textMuted,
                  onTap: () {},
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 7) return DateFormat('MMM d').format(date);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'now';
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyFeed extends StatelessWidget {
  final VoidCallback? onRefresh;
  const _EmptyFeed({this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🎬', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 20),
            const Text(
              'Your feed is empty',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Follow people to see what they\'re watching',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
            if (onRefresh != null) ...[
              const SizedBox(height: 24),
              OutlinedButton(onPressed: onRefresh, child: const Text('Refresh')),
            ],
          ],
        ),
      ),
    );
  }
}
