import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/shared_widgets.dart';
import '../providers/feed_provider.dart';
import '../widgets/comments_sheet.dart';
import '../../auth/providers/auth_provider.dart';
import '../../onboarding/services/tour_service.dart';
import '../../onboarding/widgets/quick_guide_tour_dialog.dart';
import '../../notifications/providers/notifications_provider.dart';
import '../../../core/notifications/push_notification_service.dart';
import '../widgets/wh_feed_card.dart';

export '../providers/feed_provider.dart';

// ─── Screen ─────────────────────────────────────────────────────────────────

class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen> with WidgetsBindingObserver {
  final _scrollController = ScrollController();
  bool _hasCheckedTour = false;
  bool _hasSyncedPush = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollController.addListener(_onScroll);

    // Check if feed needs fresh data when arriving on feed screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(feedProvider.notifier).onArrivedAtFeed();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      ref.read(feedProvider.notifier).onArrivedAtFeed();
    }
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
    final isNearTop = !_scrollController.hasClients || _scrollController.offset <= 80;
    ref.read(feedProvider.notifier).setNearTop(isNearTop);

    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      ref.read(feedProvider.notifier).loadMore();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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

    // Listen to Home tab taps in bottom nav or external triggers to scroll to top & refresh
    ref.listen<int>(feedRefreshTriggerProvider, (prev, next) {
      if (next > (prev ?? 0)) {
        if (_scrollController.hasClients && _scrollController.offset > 0) {
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
          );
        }
        ref.read(feedProvider.notifier).loadFeed(isRefresh: true);
      }
    });

    _checkTourOnce();
    _syncPushNotificationsOnce();

    final feedState = ref.watch(feedProvider);
    final currentUser = ref.watch(authStateProvider).value?.user;
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          RefreshIndicator(
            color: Colors.black,
            backgroundColor: AppColors.primary,
            edgeOffset: topPadding + kToolbarHeight,
            onRefresh: () async {
              HapticFeedback.lightImpact();
              await ref.read(feedProvider.notifier).loadFeed(isRefresh: true);
            },
            child: CustomScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
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
                if (feedState.isLoading && feedState.entries.isEmpty)
                  const SliverToBoxAdapter(child: WHSkeletonFeed(itemCount: 3))
                else if (feedState.error != null && feedState.entries.isEmpty)
                  SliverFillRemaining(
                    child: _ErrorFeed(
                      errorMessage: feedState.error!,
                      onRefresh: () => ref.read(feedProvider.notifier).loadFeed(isRefresh: true),
                    ),
                  )
                else if (feedState.entries.isEmpty)
                  SliverFillRemaining(
                    child: _EmptyFeed(
                      onRefresh: () => ref.read(feedProvider.notifier).loadFeed(isRefresh: true),
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
          ),
          if (feedState.newPostsCount > 0)
            Positioned(
              top: topPadding + kToolbarHeight + 8,
              left: 0,
              right: 0,
              child: Center(
                child: _NewPostsPill(
                  count: feedState.newPostsCount,
                  onTap: () {
                    if (_scrollController.hasClients) {
                      _scrollController.animateTo(
                        0,
                        duration: const Duration(milliseconds: 320),
                        curve: Curves.easeOutCubic,
                      );
                    }
                    ref.read(feedProvider.notifier).applyPendingEntries();
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _NewPostsPill extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const _NewPostsPill({
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.arrow_upward_rounded, size: 16, color: Colors.black),
              const SizedBox(width: 8),
              Text(
                '$count new update${count > 1 ? 's' : ''} available',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: Colors.black,
                ),
              ),
            ],
          ),
        ),
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
