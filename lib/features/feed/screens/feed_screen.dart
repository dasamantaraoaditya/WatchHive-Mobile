import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../shared/models/entry.dart';
import '../../../shared/widgets/shared_widgets.dart';
import '../repositories/feed_repository.dart';
import '../../auth/providers/auth_provider.dart';
import '../../search/repositories/search_repository.dart';

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
                icon: const Icon(Icons.psychology_outlined, color: AppColors.primary),
                tooltip: 'MindLens AI',
                onPressed: () => context.push('/mindlens'),
              ),
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
    final isSuggestion = entry.isSuggestion || entry.user == null;
    final displayName = isSuggestion ? 'WatchHive' : (entry.user?.displayName ?? entry.user?.username ?? 'User');

    final actionText = () {
      if (isSuggestion) return 'recommends';
      if (entry.isWatching) return 'started watching';
      if (entry.startedAt != null) return 'completed watching';
      return entry.review != null && entry.review!.isNotEmpty ? 'reviewed' : 'watched';
    }();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSuggestion ? AppColors.primary.withValues(alpha: 0.4) : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Avatar + Action Sentence + Suggested By + Compact Header Date
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: isSuggestion ? null : onUserTap,
                  child: isSuggestion
                      ? Container(
                          width: 38,
                          height: 38,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.auto_awesome, color: Colors.black, size: 20),
                        )
                      : WHAvatar(
                          imageUrl: entry.user?.profilePictureUrl,
                          name: entry.user?.displayName ?? entry.user?.username,
                          radius: 19,
                        ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // User Name + Action Sentence
                      RichText(
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        text: TextSpan(
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            color: AppColors.textPrimary,
                          ),
                          children: [
                            TextSpan(
                              text: displayName,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                            ),
                            TextSpan(
                              text: ' $actionText',
                              style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w400),
                            ),
                          ],
                        ),
                      ),

                      // Subtitle / Username
                      if (!isSuggestion && entry.user?.username != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          '@${entry.user!.username}',
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ] else if (isSuggestion) ...[
                        const SizedBox(height: 2),
                        Text(
                          entry.suggestionReason ?? '✨ Recommended for You',
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ],

                      // Suggested By Row (If applicable)
                      if (entry.suggestedByUser != null) ...[
                        const SizedBox(height: 4),
                        GestureDetector(
                          onTap: () => context.push('/profile/${entry.suggestedByUser!.id}'),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'Suggested by ',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textMuted,
                                ),
                              ),
                              WHAvatar(
                                imageUrl: entry.suggestedByUser!.profilePictureUrl,
                                name: entry.suggestedByUser!.displayName ?? entry.suggestedByUser!.username,
                                radius: 7,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '@${entry.suggestedByUser!.username}',
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(width: 8),
                // Compact header timestamp (e.g. "2:30 PM" or "Aug 23")
                Text(
                  _formatCompactHeaderDate(entry.watchedAt),
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),

          // Hero Media Banner (Full Width Movie/Show Poster Image + Badges & Tags)
          FeedMediaHeroBanner(
            entry: entry,
            onTap: onMediaTap,
          ),

          // Status & Full Precise Timestamp Footer
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Row(
              children: [
                Icon(
                  isSuggestion
                      ? Icons.auto_awesome_rounded
                      : (entry.isWatching
                          ? Icons.play_circle_outline_rounded
                          : (entry.startedAt != null ? Icons.check_circle_outline_rounded : Icons.schedule_rounded)),
                  size: 14,
                  color: isSuggestion ? AppColors.primary : AppColors.textMuted,
                ),
                const SizedBox(width: 5),
                Text(
                  isSuggestion
                      ? (entry.suggestionReason ?? 'Recommended for You')
                      : (entry.isWatching
                          ? 'Started watching • '
                          : (entry.startedAt != null ? 'Completed watching • ' : 'Seen • ')),
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isSuggestion ? AppColors.primary : AppColors.textMuted,
                  ),
                ),
                if (!isSuggestion)
                  Text(
                    _formatFullTimestamp(entry.watchedAt),
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),

          // Review / MindLens Insight Quote Box
          if (entry.review != null && entry.review!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.psychology_outlined, color: AppColors.primary, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isSuggestion ? 'Why you might like this' : 'Review & Insight',
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '"${entry.review!}"',
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 13,
                              fontStyle: FontStyle.italic,
                              color: AppColors.textPrimary,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 10),
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

  String _formatCompactHeaderDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) return DateFormat('h:mm a').format(date.toLocal());
    if (diff.inDays < 7) return DateFormat('EEE, h:mm a').format(date.toLocal());
    return DateFormat('MMM d').format(date.toLocal());
  }

  String _formatFullTimestamp(DateTime date) {
    final localDate = date.toLocal();
    final dateStr = DateFormat('MMM d, yyyy').format(localDate);
    final timeStr = DateFormat('h:mm a').format(localDate);
    return '$dateStr at $timeStr';
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

final _tmdbMediaDetailsProvider = FutureProvider.family<Map<String, dynamic>?, ({int tmdbId, String mediaType})>((ref, arg) async {
  if (arg.tmdbId <= 0) return null;
  final searchRepo = ref.read(searchRepositoryProvider);
  try {
    if (arg.mediaType == 'tv') {
      return await searchRepo.getTvDetails(arg.tmdbId);
    } else {
      return await searchRepo.getMovieDetails(arg.tmdbId);
    }
  } catch (e) {
    return null;
  }
});

class FeedMediaHeroBanner extends ConsumerWidget {
  final Entry entry;
  final VoidCallback onTap;

  const FeedMediaHeroBanner({
    super.key,
    required this.entry,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mediaType = (entry.type == 'TV_SHOW' || entry.type == 'EPISODE') ? 'tv' : 'movie';
    final shouldFetch = (entry.posterPath == null || entry.posterPath!.isEmpty) &&
        (entry.backdropPath == null || entry.backdropPath!.isEmpty) &&
        entry.tmdbId > 0;

    final detailsAsync = shouldFetch
        ? ref.watch(_tmdbMediaDetailsProvider((tmdbId: entry.tmdbId, mediaType: mediaType)))
        : null;

    final posterPath = entry.posterPath ?? detailsAsync?.value?['poster_path'] as String?;
    final backdropPath = entry.backdropPath ?? detailsAsync?.value?['backdrop_path'] as String?;
    final imagePath = backdropPath ?? posterPath;
    final imageUrl = ApiEndpoints.tmdbBackdrop(imagePath);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 210,
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Stack(
          children: [
            // Background Image
            if (imageUrl.isNotEmpty)
              Positioned.fill(
                child: CachedNetworkImage(
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
                      child: Icon(Icons.movie_outlined, color: AppColors.textMuted, size: 40),
                    ),
                  ),
                ),
              )
            else
              Positioned.fill(
                child: Container(
                  color: AppColors.surfaceElevated,
                  child: const Center(
                    child: Icon(Icons.movie_outlined, color: AppColors.textMuted, size: 40),
                  ),
                ),
              ),

            // Subtle dark gradient overlay for text readability
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.2),
                      Colors.black.withValues(alpha: 0.8),
                    ],
                  ),
                ),
              ),
            ),

            // Top-Left Badges: Type & Rewatch
            Positioned(
              top: 10,
              left: 10,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      entry.type == 'MOVIE' ? '🎬 Movie' : '📺 TV Show',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  if (entry.isRewatch) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.info.withValues(alpha: 0.4)),
                      ),
                      child: const Text(
                        '🔁 Rewatch',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.info,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Top-Right Badge: Rating
            if (entry.rating != null)
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star_rounded, color: AppColors.primary, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        entry.rating!.toStringAsFixed(1),
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Bottom-Left Overlay: Movie Title & Tags
            Positioned(
              bottom: 12,
              left: 12,
              right: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      shadows: [
                        Shadow(offset: Offset(0, 1), blurRadius: 4, color: Colors.black),
                      ],
                    ),
                  ),
                  if (entry.tags.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: entry.tags.take(3).map((tag) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
                        ),
                        child: Text(
                          '#$tag',
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      )).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
