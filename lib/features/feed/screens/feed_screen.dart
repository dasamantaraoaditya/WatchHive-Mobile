import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/error_handler.dart';
import '../../../shared/models/entry.dart';
import '../../../shared/widgets/shared_widgets.dart';
import '../repositories/feed_repository.dart';
import '../widgets/comments_sheet.dart';
import '../../auth/providers/auth_provider.dart';
import '../../onboarding/services/tour_service.dart';
import '../../onboarding/widgets/quick_guide_tour_dialog.dart';
import '../../notifications/providers/notifications_provider.dart';
import '../../../core/notifications/push_notification_service.dart';
import '../widgets/wh_feed_card.dart';


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
      final initialLiked = result.entries.where((e) => e.isLiked).map((e) => e.id).toSet();
      state = state.copyWith(
        entries: result.entries,
        likedEntryIds: initialLiked,
        isLoading: false,
        hasMore: result.pagination.hasMore,
      );
    } catch (e, stackTrace) {
      debugPrint('Feed load error: $e');
      debugPrint('Feed stack trace: $stackTrace');
      state = state.copyWith(isLoading: false, error: AppErrorHandler.toUserFriendlyMessage(e));
    }
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoadingMore) return;
    state = state.copyWith(isLoadingMore: true);
    try {
      final result = await _repo.getFeed(limit: _pageSize, offset: state.entries.length);
      final moreLiked = result.entries.where((e) => e.isLiked).map((e) => e.id);
      state = state.copyWith(
        entries: [...state.entries, ...result.entries],
        likedEntryIds: {...state.likedEntryIds, ...moreLiked},
        isLoadingMore: false,
        hasMore: result.pagination.hasMore,
      );
    } catch (_) {
      state = state.copyWith(isLoadingMore: false);
    }
  }

  Future<void> toggleLike(String entryId) async {
    final targetIndex = state.entries.indexWhere((e) => e.id == entryId);
    if (targetIndex == -1) return;

    final targetEntry = state.entries[targetIndex];
    final wasLiked = state.likedEntryIds.contains(entryId) || targetEntry.isLiked;
    final newIsLiked = !wasLiked;
    final newLikesCount = newIsLiked
        ? targetEntry.likesCount + (targetEntry.isLiked ? 0 : 1)
        : (targetEntry.likesCount > 0 ? targetEntry.likesCount - (targetEntry.isLiked ? 1 : 0) : 0);

    final updatedEntries = [...state.entries];
    updatedEntries[targetIndex] = targetEntry.copyWith(
      isLiked: newIsLiked,
      likesCount: newLikesCount,
    );

    final newLiked = Set<String>.from(state.likedEntryIds);
    if (newIsLiked) {
      newLiked.add(entryId);
    } else {
      newLiked.remove(entryId);
    }

    state = state.copyWith(entries: updatedEntries, likedEntryIds: newLiked);

    try {
      if (wasLiked) {
        await _repo.unlikeEntry(entryId);
      } else {
        await _repo.likeEntry(entryId);
      }
    } catch (_) {
      // Revert on failure
      final revertedEntries = [...state.entries];
      revertedEntries[targetIndex] = targetEntry;
      state = state.copyWith(
        entries: revertedEntries,
        likedEntryIds: Set<String>.from(state.likedEntryIds)..toggle(entryId),
      );
    }
  }

  void updateCommentsCount(String entryId, int newCount) {
    final targetIndex = state.entries.indexWhere((e) => e.id == entryId);
    if (targetIndex != -1) {
      final updatedEntries = [...state.entries];
      updatedEntries[targetIndex] = updatedEntries[targetIndex].copyWith(
        commentsCount: newCount,
        isCommented: newCount > 0,
      );
      state = state.copyWith(entries: updatedEntries);
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
  bool _hasCheckedTour = false;
  bool _hasSyncedPush = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _syncPushNotificationsOnce() {
    if (_hasSyncedPush) return;
    final auth = ref.read(authStateProvider).value;
    if (auth != null && auth.isAuthenticated) {
      _hasSyncedPush = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        final granted = await PushNotificationService.instance.requestPermission();
        if (granted) {
          ref.read(authStateProvider.notifier).syncDeviceToken();
        }
      });
    }
  }

  void _checkTourOnce() {
    if (_hasCheckedTour) return;
    final user = ref.read(authStateProvider).value?.user;
    if (user != null && user.id.isNotEmpty) {
      _hasCheckedTour = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkAndPromptTour(user.id);
      });
    }
  }

  Future<void> _checkAndPromptTour(String userId) async {
    // Short delay so the feed screen and layout settle cleanly first
    await Future.delayed(const Duration(milliseconds: 550));
    if (!mounted) return;

    final tourService = ref.read(tourServiceProvider);
    final shouldShow = await tourService.shouldShowTour(userId);
    debugPrint('QuickGuideTour: checking if tour should show for $userId: $shouldShow');
    if (shouldShow && mounted) {
      QuickGuideTourDialog.show(context, userId: userId);
    }
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
    ref.listen<AsyncValue<AuthState>>(authStateProvider, (prev, next) {
      final u = next.value?.user;
      if (u != null && u.id.isNotEmpty) {
        if (!_hasCheckedTour) _checkTourOnce();
        if (!_hasSyncedPush) _syncPushNotificationsOnce();
      }
    });

    _checkTourOnce();
    _syncPushNotificationsOnce();

    final feedState = ref.watch(feedProvider);
    final currentUser = ref.watch(authStateProvider).value?.user;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverAppBar(
            floating: true,
            title: const WHBrandLogo(logoSize: 30, fontSize: 21),
            actions: [
              IconButton(
                icon: const Icon(Icons.help_outline_rounded, color: AppColors.textSecondary),
                tooltip: 'Quick Guide Tour',
                onPressed: () {
                  final user = ref.read(authStateProvider).value?.user;
                  QuickGuideTourDialog.show(
                    context,
                    userId: user?.id ?? 'guest',
                    isReplay: true,
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.psychology_outlined, color: AppColors.primary),
                tooltip: 'MindLens AI',
                onPressed: () => context.push('/mindlens'),
              ),
              IconButton(
                icon: Consumer(
                  builder: (context, ref, child) {
                    final unreadCount = ref.watch(unreadNotificationsCountProvider);
                    return Badge(
                      isLabelVisible: unreadCount > 0,
                      backgroundColor: AppColors.primary,
                      textColor: Colors.black,
                      label: Text(
                        unreadCount > 99 ? '99+' : unreadCount.toString(),
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      child: const Icon(Icons.notifications_outlined),
                    );
                  },
                ),
                tooltip: 'Notifications',
                onPressed: () => context.push('/notifications'),
              ),
            ],
          ),
          if (feedState.isLoading)
            const SliverToBoxAdapter(child: WHSkeletonFeed(itemCount: 3))
          else if (feedState.error != null && feedState.entries.isEmpty)
            SliverFillRemaining(
              child: _ErrorFeed(
                errorMessage: feedState.error!,
                onRefresh: () => ref.read(feedProvider.notifier).loadFeed(),
              ),
            )
          else if (feedState.entries.isEmpty)
            SliverFillRemaining(
              child: _EmptyFeed(
                onRefresh: () => ref.read(feedProvider.notifier).loadFeed(),
              ),
            )
          else ...[
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              sliver: SliverList.builder(
                itemCount: feedState.entries.length + (feedState.isLoadingMore ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == feedState.entries.length) {
                    return const WHSkeletonFeedFooter();
                  }
                  final entry = feedState.entries[index];
                  final isLiked = feedState.likedEntryIds.contains(entry.id) || entry.isLiked;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: WHFeedCard(
                      entry: entry,
                      isLiked: isLiked,
                      isOwnEntry: currentUser?.id == entry.userId,
                      onLike: () => ref.read(feedProvider.notifier).toggleLike(entry.id),
                      onCommentTap: () => CommentsSheet.show(
                        context,
                        entryId: entry.id,
                        entryTitle: entry.title,
                        entryAuthorId: entry.userId,
                        onCommentCountChanged: (count) => ref.read(feedProvider.notifier).updateCommentsCount(entry.id, count),
                      ),
                      onUserTap: () {
                        final targetId = (entry.user?.id != null && entry.user!.id.isNotEmpty)
                            ? entry.user!.id
                            : entry.userId;
                        if (targetId.isNotEmpty) {
                          context.push('/profile/$targetId');
                        }
                      },
                      onMediaTap: () => context.push(
                        '/details/${entry.type == "MOVIE" ? "movie" : "tv"}/${entry.tmdbId}',
                        extra: entry,
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

class _ErrorFeed extends StatelessWidget {
  final String errorMessage;
  final VoidCallback onRefresh;

  const _ErrorFeed({
    required this.errorMessage,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 48, color: AppColors.textMuted),
            const SizedBox(height: 16),
            const Text(
              'Could not load feed',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              errorMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onRefresh,
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

