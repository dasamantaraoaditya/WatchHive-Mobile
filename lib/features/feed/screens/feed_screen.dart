import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/app_route_observer.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/shared_widgets.dart';
import '../providers/feed_provider.dart';
import '../widgets/comments_sheet.dart';
import '../../auth/providers/auth_provider.dart';
import '../../onboarding/services/tour_service.dart';
import '../../onboarding/services/onboarding_service.dart';
import '../../onboarding/providers/onboarding_guide_provider.dart';
import '../../onboarding/widgets/watch_preferences_onboarding_dialog.dart';
import '../../notifications/providers/notifications_provider.dart';
import '../../../core/notifications/push_notification_service.dart';
import '../../entries/screens/add_entry_sheet.dart';
import '../widgets/wh_feed_card.dart';
import '../widgets/smart_suggest_hero_card.dart';

export '../providers/feed_provider.dart';

// ─── Screen ─────────────────────────────────────────────────────────────────

class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen>
    with WidgetsBindingObserver, RouteAware {
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
  void didChangeDependencies() {
    super.didChangeDependencies();
    final modalRoute = ModalRoute.of(context);
    if (modalRoute != null) {
      appRouteObserver.subscribe(this, modalRoute);
    }
  }

  @override
  void didPopNext() {
    // Top route was popped off (e.g. returning from details, profile, scanner)
    if (mounted) {
      ref.read(feedProvider.notifier).onArrivedAtFeed();
    }
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

    final user = ref.read(authStateProvider).value?.user;
    final onboardingService = ref.read(onboardingServiceProvider);

    // 1. Show the 3-question watch preferences onboarding if user hasn't completed it yet
    if (onboardingService.shouldShowPreferences(user)) {
      onboardingService.markPrompted();
      await WatchPreferencesOnboardingDialog.show(context);
      if (!mounted) return;
    }

    // 2. Afterwards, check if quick guide tour is needed
    final tourService = ref.read(tourServiceProvider);
    final shouldShow = await tourService.shouldShowTour(userId);
    debugPrint('QuickGuideTour: checking if tour should show for $userId: $shouldShow');
    if (shouldShow && mounted) {
      ref.read(onboardingGuideProvider.notifier).startTour(context, userId: userId);
    }
  }

  void _onScroll() {
    final isNearTop = !_scrollController.hasClients || _scrollController.offset <= 250;
    ref.read(feedProvider.notifier).setNearTop(isNearTop);

    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      ref.read(feedProvider.notifier).loadMore();
    }
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
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
                    if (feedState.isRefreshing || (feedState.isLoading && feedState.entries.isNotEmpty))
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4),
                        child: Center(
                          child: WHBeeSpinner(size: 18),
                        ),
                      ),
                    IconButton(
                      icon: const Icon(Icons.qr_code_scanner_rounded, color: AppColors.textPrimary),
                      tooltip: 'Scan Hive Code / Movie',
                      onPressed: () => context.push('/scanner'),
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
                const SliverToBoxAdapter(
                  child: SmartSuggestHeroCard(),
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
          // Top Loading Bar & Floating Indicator when an API call is actively fetching updates
          if (feedState.isRefreshing || (feedState.isLoading && feedState.entries.isNotEmpty)) ...[
            Positioned(
              top: topPadding + kToolbarHeight,
              left: 0,
              right: 0,
              child: const LinearProgressIndicator(
                minHeight: 2.5,
                backgroundColor: Colors.transparent,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),
            Positioned(
              top: topPadding + kToolbarHeight + 8,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.4),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      WHBeeSpinner(size: 16),
                      SizedBox(width: 8),
                      Text(
                        'Updating feed...',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ] else if (feedState.newPostsCount > 0)
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

class _EmptyFeed extends ConsumerWidget {
  final VoidCallback? onRefresh;
  const _EmptyFeed({this.onRefresh});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value?.user;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Glowing Honey Emblem
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withAlpha(45),
                    AppColors.primary.withAlpha(15),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(
                  color: AppColors.primary.withAlpha(100),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withAlpha(50),
                    blurRadius: 24,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Center(
                child: Icon(Icons.movie_outlined, size: 44, color: AppColors.primary),
              ),
            ),
            const SizedBox(height: 18),

            // Badge Category
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(30),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.primary.withAlpha(80),
                  width: 0.8,
                ),
              ),
              child: const Text(
                'GET STARTED',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: AppColors.primaryDark,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Welcome Title
            const Text(
              'Start Your Watch Journey',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 8),

            // Warm Explanatory Subtitle
            const Text(
              'Your feed is quiet right now. Log your first movie or show to begin tracking your taste, or discover fellow cinephiles to build your swarm!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13.5,
                color: AppColors.textSecondary,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 24),

            // Primary CTA: Log First Watch
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxWidth: 320),
              child: ElevatedButton.icon(
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    useRootNavigator: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => const AddEntrySheet(),
                  );
                },
                icon: const Icon(Icons.edit_note_rounded,
                    color: Colors.black, size: 20),
                label: const Text(
                  'Log Your First Watch 🎬',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.black,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.black,
                  elevation: 2,
                  shadowColor: AppColors.primary.withAlpha(120),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Secondary CTA: Find Friends
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxWidth: 320),
              child: OutlinedButton.icon(
                onPressed: () => context.push('/search'),
                icon: const Icon(Icons.people_alt_outlined, size: 18),
                label: const Text(
                  'Find Friends to Follow',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  side: const BorderSide(color: AppColors.border, width: 1.2),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Tertiary Guide Tour Revisit Button
            TextButton.icon(
              onPressed: () {
                ref.read(onboardingGuideProvider.notifier).startTour(
                  context,
                  userId: user?.id ?? 'guest',
                  isReplay: true,
                );
              },
              icon: const Icon(Icons.help_outline_rounded,
                  size: 16, color: AppColors.textMuted),
              label: const Text(
                'Revisit Quick Guide Tour',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                ),
              ),
            ),

            if (onRefresh != null) ...[
              const SizedBox(height: 4),
              TextButton(
                onPressed: onRefresh,
                child: const Text('Refresh Feed',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.textMuted)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
