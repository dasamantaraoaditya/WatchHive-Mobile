import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/models/user.dart';
import '../../../shared/models/entry.dart';
import '../../../shared/widgets/shared_widgets.dart';
import '../../auth/providers/auth_provider.dart';
import '../../entries/repositories/entries_repository.dart';
import '../../entries/repositories/watchlist_repository.dart';
import '../../entries/screens/add_entry_sheet.dart';
import '../../entries/screens/entries_screen.dart';
import '../../entries/widgets/suggest_movie_modal.dart';
import '../../entries/widgets/wh_entry_grid_card.dart';
import '../../search/repositories/search_repository.dart';
import '../repositories/user_repository.dart';
import '../widgets/follow_list_sheet.dart';
import '../widgets/user_rankings_tab.dart';
import 'edit_profile_dialog.dart';
import '../../../core/utils/error_handler.dart';

class UserProfileScreen extends ConsumerStatefulWidget {
  final String userId;

  const UserProfileScreen({super.key, required this.userId});

  @override
  ConsumerState<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _ProfileTabConfig {
  final String label;
  final Widget view;
  const _ProfileTabConfig({required this.label, required this.view});
}

class _UserProfileScreenState extends ConsumerState<UserProfileScreen> with SingleTickerProviderStateMixin {
  User? _user;
  bool _isLoading = true;
  String? _error;

  // Social action states
  bool _isFollowing = false;
  bool _isRequested = false;
  bool _isIncomingRequest = false;
  String? _incomingRequestId;
  bool _isActionLoading = false;

  // Tab content data
  TabController? _tabController;
  List<Entry> _historyEntries = [];
  List<Entry> _watchingEntries = [];
  List<dynamic> _watchlistItems = [];
  bool _isLoadingTabsData = false;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  Future<void> _fetchProfile() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final repo = ref.read(userRepositoryProvider);
      final results = await Future.wait([
        repo.getUserProfile(widget.userId),
        repo.getFollowStats(widget.userId),
      ]);
      final user = results[0] as User;
      final stats = results[1] as ({int followersCount, int followingCount});
      final userWithStats = user.copyWith(
        followersCount: stats.followersCount > 0 ? stats.followersCount : user.followersCount,
        followingCount: stats.followingCount > 0 ? stats.followingCount : user.followingCount,
      );

      if (mounted) {
        setState(() {
          _user = userWithStats;
          _isFollowing = user.isFollowing;
          _isRequested = user.isRequested;
          _isIncomingRequest = user.isIncomingRequest;
          _incomingRequestId = user.incomingRequestId;
          _isLoading = false;
        });

        _setupTabsAndLoadData();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = AppErrorHandler.toUserFriendlyMessage(e, defaultMessage: 'Unable to load profile.');
          _isLoading = false;
        });
      }
    }
  }

  bool get _isMe {
    final currentUserId = ref.read(authStateProvider).value?.user?.id;
    return currentUserId != null && currentUserId == widget.userId;
  }

  Future<void> _refreshStats() async {
    try {
      final stats = await ref.read(userRepositoryProvider).getFollowStats(widget.userId);
      if (_user != null && mounted) {
        setState(() {
          _user = _user!.copyWith(
            followersCount: stats.followersCount,
            followingCount: stats.followingCount,
          );
        });
      }
    } catch (_) {}
  }

  List<_ProfileTabConfig> _getVisibleTabs() {
    if (_user == null) return [];
    final list = <_ProfileTabConfig>[];
    if (_user!.showWatchEntries) {
      list.add(_ProfileTabConfig(
        label: 'Watches (${_historyEntries.length})',
        view: _buildUserHistoryTab(),
      ));
    }
    if (_user!.showCurrentlyWatching) {
      list.add(_ProfileTabConfig(
        label: 'Watching (${_watchingEntries.length})',
        view: _buildUserWatchingTab(),
      ));
    }
    if (_user!.showWatchlist) {
      list.add(_ProfileTabConfig(
        label: 'Watchlist (${_watchlistItems.length})',
        view: _buildUserWatchlistTab(),
      ));
    }
    if (_user!.showRankings) {
      list.add(_ProfileTabConfig(
        label: 'Rankings',
        view: UserRankingsTab(userId: _user!.id),
      ));
    }
    return list;
  }

  void _setupTabsAndLoadData() {
    if (_user == null) return;
    final canView = _canViewContent();

    if (canView) {
      final tabs = _getVisibleTabs();
      _tabController?.dispose();
      if (tabs.isNotEmpty) {
        _tabController = TabController(length: tabs.length, vsync: this);
      } else {
        _tabController = null;
      }
      _loadTabContents();
    }
  }

  bool _canViewContent() {
    if (_user == null) return false;
    if (_isMe) return true; // Owner can preview what their settings allow
    if (_user!.privacyLevel == 'PUBLIC') return true;
    if (_user!.privacyLevel == 'FOLLOWERS_ONLY' && _isFollowing) return true;
    return false;
  }

  Future<void> _loadTabContents() async {
    setState(() => _isLoadingTabsData = true);
    try {
      final entriesRepo = ref.read(entriesRepositoryProvider);
      final userRepo = ref.read(userRepositoryProvider);

      final results = await Future.wait([
        if (_user!.showWatchEntries)
          entriesRepo.getEntries(userId: widget.userId, isWatching: false, limit: 50)
        else
          Future.value((entries: <Entry>[], pagination: null)),
        if (_user!.showCurrentlyWatching)
          entriesRepo.getEntries(userId: widget.userId, isWatching: true, limit: 50)
        else
          Future.value((entries: <Entry>[], pagination: null)),
        if (_user!.showWatchlist)
          userRepo.getUserWatchlist(widget.userId)
        else
          Future.value(<String, dynamic>{}),
      ]);

      if (mounted) {
        final historyEntries = (results[0] as ({List<Entry> entries, dynamic pagination})).entries;
        final watchingEntries = (results[1] as ({List<Entry> entries, dynamic pagination})).entries;
        final watchlistMap = results[2] as Map<String, dynamic>;
        final rawWatchlist = (watchlistMap['items'] as List<dynamic>?) ?? [];

        setState(() {
          _historyEntries = historyEntries;
          _watchingEntries = watchingEntries;
          _watchlistItems = rawWatchlist;
          _isLoadingTabsData = false;
        });
        if (rawWatchlist.isNotEmpty) {
          _enrichWatchlistItems(rawWatchlist);
        }
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingTabsData = false);
    }
  }

  Future<void> _enrichWatchlistItems(List<dynamic> rawItems) async {
    final searchRepo = ref.read(searchRepositoryProvider);
    final updated = List<Map<String, dynamic>>.from(rawItems.map((e) => Map<String, dynamic>.from(e as Map)));
    bool anyChanged = false;

    for (int i = 0; i < updated.length; i++) {
      final item = updated[i];
      final currentTitle = item['title'] as String?;
      final currentPoster = item['posterPath'] as String?;
      final tmdbId = (item['tmdbId'] as num?)?.toInt() ?? 0;
      final isTv = (item['mediaType'] as String? ?? 'movie').toLowerCase().contains('tv');

      if ((currentTitle == null || currentTitle.isEmpty || currentTitle == 'Untitled') && tmdbId > 0) {
        try {
          Map<String, dynamic> details;
          if (isTv) {
            try {
              details = await searchRepo.getTvDetails(tmdbId);
            } catch (_) {
              details = await searchRepo.getMovieDetails(tmdbId);
            }
          } else {
            try {
              details = await searchRepo.getMovieDetails(tmdbId);
            } catch (_) {
              details = await searchRepo.getTvDetails(tmdbId);
            }
          }
          final realTitle = (details['title'] as String?) ??
              (details['name'] as String?) ??
              (details['original_title'] as String?) ??
              (details['original_name'] as String?);
          final realPoster = (details['poster_path'] as String?) ?? (details['backdrop_path'] as String?);

          if (realTitle != null && realTitle.isNotEmpty) {
            item['title'] = realTitle;
            anyChanged = true;
          }
          if (realPoster != null && realPoster.isNotEmpty && (currentPoster == null || currentPoster.isEmpty)) {
            item['posterPath'] = realPoster;
            anyChanged = true;
          }
        } catch (_) {}
      }
    }

    if (anyChanged && mounted) {
      setState(() {
        _watchlistItems = updated;
      });
    }
  }

  Future<void> _handleFollowToggle() async {
    if (_user == null || _isActionLoading) return;

    final origFollowing = _isFollowing;
    final origRequested = _isRequested;

    if (origFollowing || origRequested) {
      final confirm = await WHAlert.confirm(
        context,
        title: origRequested ? 'Cancel Request' : 'Unfollow @${_user!.username}',
        message: origRequested
            ? 'Cancel your pending follow request to @${_user!.username}?'
            : 'Are you sure you want to unfollow @${_user!.username}?',
        confirmText: origRequested ? 'Cancel Request' : 'Unfollow',
        severity: WHAlertSeverity.danger,
        icon: Icons.person_remove_rounded,
      );

      if (!confirm) return;
    }

    setState(() => _isActionLoading = true);

    try {
      final repo = ref.read(userRepositoryProvider);
      final currentUser = ref.read(authStateProvider).value?.user;
      if (origFollowing || origRequested) {
        await repo.unfollowUser(_user!.id);
        setState(() {
          _isFollowing = false;
          _isRequested = false;
          _user = _user!.copyWith(
            followersCount: _user!.followersCount > 0 ? _user!.followersCount - 1 : 0,
          );
        });
        if (currentUser != null && origFollowing) {
          ref.read(authStateProvider.notifier).updateUser(
            currentUser.copyWith(
              followingCount: currentUser.followingCount > 0 ? currentUser.followingCount - 1 : 0,
            ),
          );
        }
        if (mounted) {
          WHAlert.showInfo(context, origRequested ? 'Follow request cancelled' : 'Unfollowed @${_user!.username}');
        }
      } else {
        await repo.followUser(_user!.id);
        final isPrivate = _user!.privacyLevel == 'FOLLOWERS_ONLY' || _user!.privacyLevel == 'PRIVATE' || _user!.isPrivate;
        setState(() {
          if (isPrivate) {
            _isRequested = true;
          } else {
            _isFollowing = true;
            _user = _user!.copyWith(followersCount: _user!.followersCount + 1);
          }
        });
        if (currentUser != null && !isPrivate) {
          ref.read(authStateProvider.notifier).updateUser(
            currentUser.copyWith(
              followingCount: currentUser.followingCount + 1,
            ),
          );
        }
        if (mounted) {
          WHAlert.showSuccess(
            context,
            isPrivate
                ? 'Follow request sent to @${_user!.username} ⏳'
                : 'Now following @${_user!.username}! ✨',
          );
        }
      }

      _setupTabsAndLoadData();
      _refreshStats();
    } catch (e) {
      setState(() {
        _isFollowing = origFollowing;
        _isRequested = origRequested;
      });
      if (mounted) {
        WHAlert.showError(context, 'Action failed: $e');
      }
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  Future<void> _handleAcceptIncoming() async {
    if (_incomingRequestId == null || _user == null) return;
    setState(() => _isActionLoading = true);
    try {
      await ref.read(userRepositoryProvider).acceptFollowRequest(_incomingRequestId!);
      setState(() {
        _isIncomingRequest = false;
        _incomingRequestId = null;
      });
      if (mounted) {
        WHAlert.showSuccess(context, 'Follow request accepted! 🤝');
      }
    } catch (e) {
      if (mounted) {
        WHAlert.showError(context, 'Failed to accept request: $e');
      }
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  Future<void> _handleRejectIncoming() async {
    if (_incomingRequestId == null) return;
    setState(() => _isActionLoading = true);
    try {
      await ref.read(userRepositoryProvider).rejectFollowRequest(_incomingRequestId!);
      setState(() {
        _isIncomingRequest = false;
        _incomingRequestId = null;
      });
      if (mounted) {
        WHAlert.showInfo(context, 'Follow request declined.');
      }
    } catch (e) {
      if (mounted) {
        WHAlert.showError(context, 'Failed to decline request: $e');
      }
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const WHSkeletonProfile();
    }

    if (_error != null || _user == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Profile')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceHighest,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.person_off_outlined, size: 40, color: AppColors.textMuted),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Profile Unavailable',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _error ?? 'User not found.',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: _fetchProfile,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Try Again', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final canView = _canViewContent();
    final visibleTabs = _getVisibleTabs();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              floating: false,
              pinned: true,
              backgroundColor: AppColors.background,
              title: Text(
                _isMe ? 'My Public Profile' : _user!.name,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: AppColors.textPrimary,
                ),
              ),
              actions: [
                if (_isMe)
                  IconButton(
                    icon: const Icon(Icons.tune_rounded, color: AppColors.primaryDark),
                    tooltip: 'Adjust Privacy Settings',
                    onPressed: () {
                      EditProfileDialog.show(
                        context,
                        user: _user!,
                        onSaved: _fetchProfile,
                      );
                    },
                  ),
              ],
            ),
            if (_isMe)
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.remove_red_eye_outlined, size: 20, color: AppColors.primaryDark),
                      SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Profile Preview Mode',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'This is how other users view your profile based on your privacy permissions.',
                              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: _buildUserHeroCard(_user!),
              ),
            ),
            if (canView && visibleTabs.isNotEmpty && _tabController != null)
              SliverPersistentHeader(
                pinned: true,
                delegate: _StickyTabBarDelegate(
                  TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    labelColor: Colors.black,
                    unselectedLabelColor: AppColors.textMuted,
                    indicatorColor: AppColors.primary,
                    indicatorWeight: 3,
                    labelStyle: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    tabs: visibleTabs.map((t) => Tab(text: t.label)).toList(),
                  ),
                ),
              ),
          ];
        },
        body: canView
            ? (visibleTabs.isNotEmpty && _tabController != null
                ? TabBarView(
                    controller: _tabController,
                    children: visibleTabs.map((t) => t.view).toList(),
                  )
                : _buildNoPublicSectionsView())
            : _buildPrivateLockView(_user!),
      ),
    );
  }

  Widget _buildUserHeroCard(User user) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Persona Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.stars_rounded, size: 14, color: AppColors.primaryDark),
                    SizedBox(width: 4),
                    Text(
                      'SOUL PERSONA',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                        color: AppColors.primaryDark,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.surfaceHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'LVL ${user.level} · ${user.xp} XP',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Avatar & User Info
          Row(
            children: [
              WHAvatar(
                imageUrl: user.profilePictureUrl,
                name: user.name,
                radius: 36,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '@${user.username}',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    if (user.location != null && user.location!.trim().isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.location_on_outlined, size: 12, color: AppColors.textMuted),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(
                              user.location!.trim(),
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 11,
                                color: AppColors.textMuted,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Bio
          if (user.bio != null && user.bio!.trim().isNotEmpty) ...[
            Text(
              '"${user.bio!}"',
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                height: 1.4,
                color: AppColors.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 14),
          ],

          // Followers & Following Counters (Clickable)
          Row(
            children: [
              Expanded(
                child: _buildUserStatChip(
                  count: user.entriesCount,
                  label: 'Watches',
                  onTap: () {},
                  isPrimary: true,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildUserStatChip(
                  count: user.followersCount,
                  label: 'Followers',
                  onTap: () async {
                    await FollowListSheet.show(
                      context,
                      userId: user.id,
                      title: 'Followers',
                      isFollowers: true,
                    );
                    _refreshStats();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildUserStatChip(
                  count: user.followingCount,
                  label: 'Following',
                  onTap: () async {
                    await FollowListSheet.show(
                      context,
                      userId: user.id,
                      title: 'Following',
                      isFollowers: false,
                    );
                    _refreshStats();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Incoming Request Bar (if applicable)
          if (_isIncomingRequest) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primary.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Text(
                    '@${user.username} wants to follow you',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primaryDark),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.success,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: _isActionLoading ? null : _handleAcceptIncoming,
                          icon: const Icon(Icons.check, size: 14),
                          label: const Text('Accept', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.error,
                            side: const BorderSide(color: AppColors.error),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: _isActionLoading ? null : _handleRejectIncoming,
                          icon: const Icon(Icons.close, size: 14),
                          label: const Text('Decline', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Action Buttons: Follow + Compare + Suggest (or Adjust Privacy if own profile)
          if (_isMe)
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.black,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () {
                      EditProfileDialog.show(
                        context,
                        user: user,
                        onSaved: _fetchProfile,
                      );
                    },
                    icon: const Icon(Icons.tune_rounded, size: 16),
                    label: const Text(
                      'Adjust Privacy & Visible Tabs',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                // Follow / Following / Requested Button
                Expanded(
                  flex: 3,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isFollowing
                          ? AppColors.surfaceHighest
                          : _isRequested
                              ? Colors.amber.shade100
                              : AppColors.primary,
                      foregroundColor: _isFollowing
                          ? AppColors.textPrimary
                          : _isRequested
                              ? Colors.amber.shade900
                              : Colors.black,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: _isActionLoading ? null : _handleFollowToggle,
                    icon: Icon(
                      _isFollowing
                          ? Icons.person_remove_outlined
                          : _isRequested
                              ? Icons.hourglass_top_rounded
                              : Icons.person_add_rounded,
                      size: 16,
                    ),
                    label: Text(
                      _isFollowing
                          ? 'Following'
                          : _isRequested
                              ? 'Requested'
                              : 'Follow',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Compare Taste Shortcut
                IconButton.filledTonal(
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.primary.withOpacity(0.12),
                    foregroundColor: AppColors.primaryDark,
                    padding: const EdgeInsets.all(12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  tooltip: 'Compare Taste',
                  onPressed: () => context.push('/compare/${user.id}', extra: user),
                  icon: const Icon(Icons.compare_arrows_rounded, size: 20),
                ),
                const SizedBox(width: 8),

                // Suggest Movie Modal
                IconButton.filledTonal(
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.primary.withOpacity(0.12),
                    foregroundColor: AppColors.primaryDark,
                    padding: const EdgeInsets.all(12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  tooltip: 'Suggest a Movie',
                  onPressed: () {
                    SuggestMovieModal.show(
                      context,
                      initialToUserId: user.id,
                      initialToUserName: user.username,
                    );
                  },
                  icon: const Icon(Icons.auto_awesome_rounded, size: 20),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildNoPublicSectionsView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: const BoxDecoration(
                color: AppColors.surfaceHighest,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.visibility_off_outlined, size: 30, color: AppColors.textMuted),
            ),
            const SizedBox(height: 14),
            Text(
              _isMe ? 'No Public Sections Enabled' : 'No Public Activity',
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _isMe
                  ? 'You have disabled all individual tabs (Watches, Watching, Watchlist, Rankings) in your privacy settings. Other users will only see your basic profile and bio.'
                  : 'This user has kept their watch history, lists, and rankings private.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
            if (_isMe && _user != null) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  EditProfileDialog.show(
                    context,
                    user: _user!,
                    onSaved: _fetchProfile,
                  );
                },
                icon: const Icon(Icons.tune_rounded, size: 16),
                label: const Text('Enable Sections in Privacy Settings'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildUserStatChip({
    required int count,
    required String label,
    required VoidCallback onTap,
    bool isPrimary = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isPrimary ? AppColors.primary.withOpacity(0.08) : AppColors.background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isPrimary ? AppColors.primary.withOpacity(0.3) : AppColors.border,
          ),
        ),
        child: Column(
          children: [
            Text(
              '$count',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: isPrimary ? AppColors.primaryDark : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label.toUpperCase(),
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrivateLockView(User user) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lock_rounded, size: 32, color: AppColors.primary),
              ),
              const SizedBox(height: 16),
              const Text(
                'This Hive is Private',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Follow @${user.username} to see their watch history, watchlist, and ranking stacks.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: AppColors.textMuted, height: 1.4),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                onPressed: _isActionLoading ? null : _handleFollowToggle,
                icon: Icon(_isRequested ? Icons.hourglass_top_rounded : Icons.person_add_rounded, size: 16),
                label: Text(
                  _isRequested ? 'Follow Requested' : 'Request to Follow',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserHistoryTab() {
    if (_isLoadingTabsData) {
      return const WHSkeletonGrid(itemCount: 4);
    }
    if (_historyEntries.isEmpty) {
      return const Center(
        child: Text('No watch entries to show.', style: TextStyle(color: AppColors.textMuted)),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 0.63,
      ),
      itemCount: _historyEntries.length,
      itemBuilder: (ctx, index) {
        final entry = _historyEntries[index];
        final mediaType = entry.type.toLowerCase().contains('tv') ? 'tv' : 'movie';
        return WHEntryGridCard(
          tmdbId: entry.tmdbId,
          title: entry.title,
          initialPosterPath: entry.posterPath,
          mediaType: entry.type,
          mode: WHEntryCardMode.history,
          rating: entry.rating,
          watchedAt: entry.watchedAt,
          watchLocation: entry.watchLocation,
          tags: entry.tags,
          onTap: () {
            if (entry.tmdbId > 0) {
              context.push(
                '/details/$mediaType/${entry.tmdbId}',
                extra: {
                  'entry': entry,
                  'user': _user,
                },
              );
            }
          },
        );
      },
    );
  }

  Widget _buildUserWatchingTab() {
    if (_isLoadingTabsData) {
      return const WHSkeletonGrid(itemCount: 4);
    }
    if (_watchingEntries.isEmpty) {
      return const Center(
        child: Text('Not currently watching any movies or shows.', style: TextStyle(color: AppColors.textMuted)),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 0.63,
      ),
      itemCount: _watchingEntries.length,
      itemBuilder: (ctx, index) {
        final entry = _watchingEntries[index];
        final mediaType = entry.type.toLowerCase().contains('tv') ? 'tv' : 'movie';
        return WHEntryGridCard(
          tmdbId: entry.tmdbId,
          title: entry.title,
          initialPosterPath: entry.posterPath,
          mediaType: entry.type,
          mode: WHEntryCardMode.watching,
          rating: entry.rating,
          watchedAt: entry.watchedAt,
          startedAt: entry.startedAt ?? entry.createdAt,
          watchLocation: entry.watchLocation,
          tags: entry.tags,
          onTap: () {
            if (entry.tmdbId > 0) {
              context.push(
                '/details/$mediaType/${entry.tmdbId}',
                extra: {
                  'entry': entry,
                  'user': _user,
                },
              );
            }
          },
        );
      },
    );
  }

  Widget _buildUserWatchlistTab() {
    if (_isLoadingTabsData) {
      return const WHSkeletonGrid(itemCount: 4);
    }
    if (_watchlistItems.isEmpty) {
      return const Center(
        child: Text('Watchlist is empty.', style: TextStyle(color: AppColors.textMuted)),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 0.63,
      ),
      itemCount: _watchlistItems.length,
      itemBuilder: (ctx, i) {
        final item = _watchlistItems[i] as Map<String, dynamic>;
        final tmdbId = (item['tmdbId'] as num?)?.toInt() ?? 0;
        final title = (item['title'] as String?) ??
            (item['name'] as String?) ??
            (item['media_title'] as String?) ??
            '';
        final posterPath = (item['posterPath'] as String?) ??
            (item['poster_path'] as String?) ??
            (item['backdrop_path'] as String?);
        final mediaType = item['mediaType'] == 'tv' ? 'tv' : 'movie';
        final addedAtRaw = item['addedAt'] ?? item['createdAt'] ?? item['updatedAt'];
        final addedAt = addedAtRaw is DateTime
            ? addedAtRaw
            : (addedAtRaw is String && addedAtRaw.isNotEmpty ? DateTime.tryParse(addedAtRaw) : null);

        return WHEntryGridCard(
          tmdbId: tmdbId,
          title: title.isNotEmpty ? title : 'Untitled',
          initialPosterPath: posterPath,
          mediaType: mediaType,
          mode: WHEntryCardMode.watchlist,
          addedAt: addedAt,
          onTap: () {
            if (tmdbId > 0) context.push('/details/$mediaType/$tmdbId');
          },
          onMoveToWatchingWithTitle: _isMe ? (resolvedTitle) => _addToCurrentlyWatching(
            item,
            resolvedTitle: resolvedTitle.isNotEmpty && resolvedTitle != 'Untitled' ? resolvedTitle : title,
          ) : null,
          onMoveToWatching: _isMe ? () => _addToCurrentlyWatching(item, resolvedTitle: title) : null,
          onMarkWatchedWithTitle: _isMe ? (resolvedTitle) => _logWatchlistItem(
            item,
            resolvedTitle: resolvedTitle.isNotEmpty && resolvedTitle != 'Untitled' ? resolvedTitle : title,
          ) : null,
          onMarkWatched: _isMe ? () => _logWatchlistItem(item, resolvedTitle: title) : null,
          onDeleteWithTitle: _isMe ? (resolvedTitle) => _removeWatchlistItem(
            tmdbId: tmdbId,
            title: resolvedTitle.isNotEmpty && resolvedTitle != 'Untitled' ? resolvedTitle : title,
            itemId: item['id'] as String?,
            mediaType: mediaType,
          ) : null,
          onDelete: _isMe ? () => _removeWatchlistItem(
            tmdbId: tmdbId,
            title: title,
            itemId: item['id'] as String?,
            mediaType: mediaType,
          ) : null,
        );
      },
    );
  }

  Future<void> _addToCurrentlyWatching(Map<String, dynamic> item, {String? resolvedTitle}) async {
    final tmdbId = (item['tmdbId'] as num?)?.toInt() ?? 0;
    final isTv = (item['mediaType'] as String? ?? 'movie').toLowerCase().contains('tv');

    String effectiveTitle = (resolvedTitle != null && resolvedTitle.trim().isNotEmpty && resolvedTitle != 'Untitled')
        ? resolvedTitle.trim()
        : ((item['title'] as String?)?.trim() ?? '');

    if ((effectiveTitle.isEmpty || effectiveTitle == 'Untitled') && tmdbId > 0) {
      try {
        final searchRepo = ref.read(searchRepositoryProvider);
        final details = isTv
            ? await searchRepo.getTvDetails(tmdbId)
            : await searchRepo.getMovieDetails(tmdbId);
        final realTitle = (details['title'] as String?) ??
            (details['name'] as String?) ??
            (details['original_title'] as String?) ??
            (details['original_name'] as String?);
        if (realTitle != null && realTitle.trim().isNotEmpty) {
          effectiveTitle = realTitle.trim();
          item['title'] = effectiveTitle;
        }
      } catch (_) {}
    }

    final cleanTitle = effectiveTitle.isNotEmpty && effectiveTitle != 'Untitled'
        ? effectiveTitle
        : (isTv ? 'this TV show' : 'this movie');

    if (!mounted) return;

    final confirm = await WHAlert.confirm(
      context,
      title: 'Move to Currently Watching',
      message: 'Would you like to move "$cleanTitle" to your Currently Watching log?',
      confirmText: 'Move to Watching',
      severity: WHAlertSeverity.primary,
      icon: Icons.play_circle_outline_rounded,
    );

    if (!confirm || !mounted) return;

    try {
      final mediaType = isTv ? 'TV_SHOW' : 'MOVIE';
      final itemId = item['id'] as String?;
      final suggestedByUser = item['suggestedByUser'] as Map<String, dynamic>?;
      final suggestedByUserId = item['suggestedByUserId'] as String? ?? suggestedByUser?['id'] as String?;

      final entry = await ref.read(entriesRepositoryProvider).createEntry({
        'tmdbId': tmdbId,
        'title': effectiveTitle.isNotEmpty && effectiveTitle != 'Untitled' ? effectiveTitle : cleanTitle,
        'type': mediaType,
        'isWatching': true,
        'startedAt': DateTime.now().toIso8601String(),
        if (suggestedByUserId != null) 'suggestedByUserId': suggestedByUserId,
      });

      ref.read(entriesProvider(true).notifier).addEntry(entry);

      await ref.read(watchlistRepositoryProvider).removeFromWatchlist(
        tmdbId > 0 ? tmdbId : itemId,
      );
      if (mounted) {
        setState(() {
          _watchlistItems.removeWhere((it) =>
              (tmdbId > 0 && (it['tmdbId'] as num?)?.toInt() == tmdbId) ||
              (itemId != null && it['id'] == itemId));
        });
        WHAlert.showSuccess(context, 'Moved "$cleanTitle" to Currently Watching! 🎬');
      }
    } catch (e) {
      if (mounted) {
        WHAlert.showError(context, 'Failed to add to currently watching: $e');
      }
    }
  }

  Future<void> _logWatchlistItem(Map<String, dynamic> item, {String? resolvedTitle}) async {
    final itemId = item['id'] as String?;
    final tmdbId = (item['tmdbId'] as num?)?.toInt() ?? 0;
    final isTv = (item['mediaType'] as String? ?? 'movie').toLowerCase().contains('tv');
    final mediaType = isTv ? 'TV_SHOW' : 'MOVIE';
    final suggestedByUser = item['suggestedByUser'] as Map<String, dynamic>?;
    final suggestedByUserId = item['suggestedByUserId'] as String? ?? suggestedByUser?['id'] as String?;

    String effectiveTitle = (resolvedTitle != null && resolvedTitle.trim().isNotEmpty && resolvedTitle != 'Untitled')
        ? resolvedTitle.trim()
        : ((item['title'] as String?)?.trim() ?? '');

    if ((effectiveTitle.isEmpty || effectiveTitle == 'Untitled') && tmdbId > 0) {
      try {
        final searchRepo = ref.read(searchRepositoryProvider);
        final details = isTv
            ? await searchRepo.getTvDetails(tmdbId)
            : await searchRepo.getMovieDetails(tmdbId);
        final realTitle = (details['title'] as String?) ??
            (details['name'] as String?) ??
            (details['original_title'] as String?) ??
            (details['original_name'] as String?);
        if (realTitle != null && realTitle.trim().isNotEmpty) {
          effectiveTitle = realTitle.trim();
          item['title'] = effectiveTitle;
        }
      } catch (_) {}
    }

    final cleanTitle = effectiveTitle.isNotEmpty && effectiveTitle != 'Untitled'
        ? effectiveTitle
        : (isTv ? 'this TV show' : 'this movie');

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddEntrySheet(
        prefillTmdbId: tmdbId > 0 ? tmdbId : null,
        prefillType: mediaType,
        prefillSuggestedByUserId: suggestedByUserId,
        onSuccess: () {
          ref.read(watchlistRepositoryProvider).removeFromWatchlist(
            tmdbId > 0 ? tmdbId : itemId,
          );
          if (mounted) {
            setState(() {
              _watchlistItems.removeWhere((it) =>
                  (tmdbId > 0 && (it['tmdbId'] as num?)?.toInt() == tmdbId) ||
                  (itemId != null && it['id'] == itemId));
            });
            WHAlert.showSuccess(context, 'Logged and removed "$cleanTitle" from Watchlist! ✨');
          }
        },
      ),
    );
  }

  Future<void> _removeWatchlistItem({
    required int tmdbId,
    required String title,
    String? itemId,
    String? mediaType,
  }) async {
    final isTv = (mediaType ?? '').toLowerCase().contains('tv');
    String effectiveTitle = title.trim();

    if ((effectiveTitle.isEmpty || effectiveTitle == 'Untitled') && tmdbId > 0) {
      try {
        final searchRepo = ref.read(searchRepositoryProvider);
        final details = isTv
            ? await searchRepo.getTvDetails(tmdbId)
            : await searchRepo.getMovieDetails(tmdbId);
        final realTitle = (details['title'] as String?) ??
            (details['name'] as String?) ??
            (details['original_title'] as String?) ??
            (details['original_name'] as String?);
        if (realTitle != null && realTitle.trim().isNotEmpty) {
          effectiveTitle = realTitle.trim();
        }
      } catch (_) {}
    }

    final cleanTitle = effectiveTitle.isNotEmpty && effectiveTitle != 'Untitled'
        ? effectiveTitle
        : (isTv ? 'this TV show' : 'this movie');

    if (!mounted) return;

    final confirm = await WHAlert.confirm(
      context,
      title: 'Remove "$cleanTitle"?',
      message: 'Are you sure you want to remove "$cleanTitle" from your watchlist?',
      confirmText: 'Remove',
      severity: WHAlertSeverity.danger,
      icon: Icons.bookmark_remove_rounded,
    );

    if (!confirm || !mounted) return;

    try {
      await ref.read(watchlistRepositoryProvider).removeFromWatchlist(
        tmdbId > 0 ? tmdbId : itemId,
      );
      if (mounted) {
        setState(() {
          _watchlistItems.removeWhere((item) =>
              (tmdbId > 0 && (item['tmdbId'] as num?)?.toInt() == tmdbId) ||
              (itemId != null && item['id'] == itemId));
        });
        WHAlert.showSuccess(context, 'Removed "$cleanTitle" from Watchlist');
      }
    } catch (e) {
      if (mounted) {
        WHAlert.showError(context, 'Failed to remove "$cleanTitle": $e');
      }
    }
  }
}

class _StickyTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  _StickyTabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: AppColors.background,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_StickyTabBarDelegate oldDelegate) {
    return false;
  }
}
