import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../shared/models/user.dart';
import '../../../shared/models/entry.dart';
import '../../../shared/widgets/shared_widgets.dart';
import '../../../shared/widgets/wh_brand_logo.dart';
import '../../auth/providers/auth_provider.dart';
import '../../entries/repositories/entries_repository.dart';
import '../../entries/screens/add_entry_sheet.dart';
import '../../entries/screens/entries_screen.dart';
import '../../entries/widgets/wh_entry_grid_card.dart';
import '../../entries/widgets/watchlist_tab.dart';
import '../repositories/user_repository.dart';
import '../widgets/follow_list_sheet.dart';
import '../widgets/profile_stats_view.dart';
import '../widgets/user_rankings_tab.dart';
import '../widgets/compare_picker_modal.dart';
import 'edit_profile_dialog.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Entry> _historyEntries = [];
  List<Entry> _watchingEntries = [];
  bool _isLoading = true;
  bool _isEditingBio = false;
  late final TextEditingController _bioTextController;
  bool _isSavingBio = false;
  bool _isUploadingAvatar = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _bioTextController = TextEditingController();
    _loadProfileData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _bioTextController.dispose();
    super.dispose();
  }

  Future<void> _loadProfileData() async {
    setState(() => _isLoading = true);
    try {
      final userRepo = ref.read(userRepositoryProvider);
      final entriesRepo = ref.read(entriesRepositoryProvider);

      final user = await userRepo.getCurrentUser();
      ref.read(authStateProvider.notifier).updateUser(user);
      _bioTextController.text = user.bio ?? '';

      final results = await Future.wait([
        entriesRepo.getEntries(isWatching: false, limit: 50),
        entriesRepo.getEntries(isWatching: true, limit: 50),
        userRepo.getFollowStats(user.id),
      ]);

      final followStats = results[2] as ({int followersCount, int followingCount});
      final updatedUser = user.copyWith(
        followersCount: followStats.followersCount,
        followingCount: followStats.followingCount,
      );
      ref.read(authStateProvider.notifier).updateUser(updatedUser);

      if (mounted) {
        setState(() {
          _historyEntries = (results[0] as ({List<Entry> entries, dynamic pagination})).entries;
          _watchingEntries = (results[1] as ({List<Entry> entries, dynamic pagination})).entries;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _refreshFollowStats(String userId) async {
    try {
      final stats = await ref.read(userRepositoryProvider).getFollowStats(userId);
      final currentUser = ref.read(authStateProvider).value?.user;
      if (currentUser != null && mounted) {
        ref.read(authStateProvider.notifier).updateUser(
          currentUser.copyWith(
            followersCount: stats.followersCount,
            followingCount: stats.followingCount,
          ),
        );
      }
    } catch (_) {}
  }

  Future<void> _deleteEntry(Entry entry) async {
    final confirm = await WHAlert.confirm(
      context,
      title: entry.isWatching ? 'Delete Session' : 'Delete Watch Entry',
      message: entry.isWatching
          ? 'Are you sure you want to delete this currently watching session for "${entry.title}"?'
          : 'Are you sure you want to delete your logged entry for "${entry.title}"? This action cannot be undone.',
      confirmText: 'Delete',
      severity: WHAlertSeverity.danger,
      icon: Icons.delete_outline_rounded,
    );
    if (!confirm || !mounted) return;

    try {
      await ref.read(entriesRepositoryProvider).deleteEntry(entry.id);
      try {
        ref.read(entriesProvider(entry.isWatching).notifier).deleteEntry(entry.id);
      } catch (_) {}
      if (mounted) {
        setState(() {
          if (entry.isWatching) {
            _watchingEntries.removeWhere((e) => e.id == entry.id);
          } else {
            _historyEntries.removeWhere((e) => e.id == entry.id);
          }
        });
        WHAlert.showSuccess(context, 'Entry deleted');
      }
    } catch (e) {
      if (mounted) {
        WHAlert.showError(context, 'Failed to delete entry: $e');
      }
    }
  }

  Future<void> _pickAndUploadAvatar() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );

    if (image == null) return;

    setState(() => _isUploadingAvatar = true);
    try {
      final updatedUser = await ref.read(userRepositoryProvider).uploadAvatar(image);
      ref.read(authStateProvider.notifier).updateUser(updatedUser);
      if (mounted) {
        WHAlert.showSuccess(context, 'Profile picture updated! 📸');
      }
    } catch (e) {
      if (mounted) {
        WHAlert.showError(context, 'Failed to upload image: $e');
      }
    } finally {
      if (mounted) setState(() => _isUploadingAvatar = false);
    }
  }

  Future<void> _removeAvatar() async {
    final confirm = await WHAlert.confirm(
      context,
      title: 'Remove Profile Picture',
      message: 'Are you sure you want to remove your profile picture?',
      confirmText: 'Remove',
      severity: WHAlertSeverity.danger,
      icon: Icons.delete_outline_rounded,
    );

    if (!confirm) return;

    setState(() => _isUploadingAvatar = true);
    try {
      await ref.read(userRepositoryProvider).deleteAvatar();
      final user = ref.read(authStateProvider).value?.user;
      if (user != null) {
        final updatedUser = user.copyWith(clearProfilePicture: true);
        ref.read(authStateProvider.notifier).updateUser(updatedUser);
      }
      if (mounted) {
        WHAlert.showSuccess(context, 'Profile picture removed');
      }
    } catch (e) {
      if (mounted) {
        WHAlert.showError(context, 'Failed to remove image: $e');
      }
    } finally {
      if (mounted) setState(() => _isUploadingAvatar = false);
    }
  }

  Future<void> _saveQuickBio() async {
    final user = ref.read(authStateProvider).value?.user;
    if (user == null) return;

    setState(() => _isSavingBio = true);
    try {
      final updated = await ref.read(userRepositoryProvider).updateProfile(
        user.id,
        {'bio': _bioTextController.text.trim()},
      );
      ref.read(authStateProvider.notifier).updateUser(updated);
      setState(() => _isEditingBio = false);
      if (mounted) {
        WHAlert.showSuccess(context, 'Bio updated! ✨');
      }
    } catch (e) {
      if (mounted) {
        WHAlert.showError(context, 'Failed to update bio: $e');
      }
    } finally {
      if (mounted) setState(() => _isSavingBio = false);
    }
  }

  void _handleInviteFriends(User user) {
    final inviteUrl = 'https://watchhive-web.vercel.app/signup?ref=${user.username}';
    final text = 'Join me on WatchHive! Check out my cinematic journey and let\'s build our movie hive together. 🐝🎥\n$inviteUrl';
    Share.share(text, subject: 'Join me on WatchHive');
  }

  Future<void> _confirmSignOut() async {
    final confirm = await WHAlert.confirm(
      context,
      title: 'Sign Out',
      message: 'Are you sure you want to sign out of WatchHive?',
      confirmText: 'Sign Out',
      severity: WHAlertSeverity.danger,
      icon: Icons.logout_rounded,
    );

    if (confirm) {
      ref.read(authStateProvider.notifier).logout();
    }
  }


  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).value?.user;

    if (user == null) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Text('Session expired. Please log in again.', style: TextStyle(color: AppColors.textMuted)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              floating: false,
              pinned: true,
              elevation: 0,
              backgroundColor: AppColors.background,
              title: const WHBrandLogo(logoSize: 26, fontSize: 19),
              actions: [
                IconButton(
                  icon: const Icon(Icons.format_list_numbered_rounded, color: AppColors.primary),
                  tooltip: 'Rankings & Stacks 🏆',
                  onPressed: () async {
                    await context.push('/rankings');
                    _loadProfileData();
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.compare_arrows_rounded, color: AppColors.primaryDark),
                  tooltip: 'Compare Taste with Friends',
                  onPressed: () => ComparePickerModal.show(context),
                ),
                IconButton(
                  icon: const Icon(Icons.tune_rounded, color: AppColors.textPrimary),
                  tooltip: 'Profile Settings & Privacy',
                  onPressed: () {
                    EditProfileDialog.show(
                      context,
                      user: user,
                      onSaved: _loadProfileData,
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.logout_rounded, color: AppColors.textMuted),
                  tooltip: 'Sign Out',
                  onPressed: _confirmSignOut,
                ),
              ],
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: _buildHeroCard(user),
              ),
            ),
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
                  tabs: [
                    Tab(text: 'Watches (${_historyEntries.length})'),
                    Tab(text: 'Watching (${_watchingEntries.length})'),
                    const Tab(text: 'Watchlist'),
                    const Tab(text: 'Rankings'),
                    const Tab(text: 'Analytics'),
                  ],
                ),
              ),
            ),
          ];
        },
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : TabBarView(
                controller: _tabController,
                children: [
                  _buildHistoryTab(),
                  _buildWatchingTab(),
                  const WatchlistTab(),
                  UserRankingsTab(userId: user.id),
                  const ProfileStatsView(),
                ],
              ),
      ),
    );
  }

  Widget _buildHeroCard(User user) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Soul Persona badge
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
                      'SOUL PERSONA: THE COLLECTOR',
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

          // Middle: Avatar + Name + User info
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Avatar with interactive camera overlay
              Stack(
                children: [
                  GestureDetector(
                    onTap: _pickAndUploadAvatar,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.primary, width: 2),
                      ),
                      child: WHAvatar(
                        imageUrl: user.profilePictureUrl,
                        name: user.name,
                        radius: 36,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: _pickAndUploadAvatar,
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(color: Colors.black12, blurRadius: 4),
                          ],
                        ),
                        child: const Icon(Icons.photo_camera_rounded, size: 13, color: Colors.black),
                      ),
                    ),
                  ),
                  if (user.profilePictureUrl != null && user.profilePictureUrl!.isNotEmpty)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: _removeAvatar,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(color: Colors.black12, blurRadius: 4),
                            ],
                          ),
                          child: const Icon(Icons.close_rounded, size: 11, color: AppColors.error),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 16),

              // Names
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
                    if (user.location != null && user.location!.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined, size: 12, color: AppColors.textMuted),
                          const SizedBox(width: 3),
                          Text(user.location!, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Bio Section
          if (_isEditingBio)
            Column(
              children: [
                TextField(
                  controller: _bioTextController,
                  maxLines: 2,
                  maxLength: 500,
                  style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Write your cinematic bio...',
                    filled: true,
                    fillColor: AppColors.background,
                    contentPadding: const EdgeInsets.all(12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => setState(() => _isEditingBio = false),
                      child: const Text('Cancel', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: _isSavingBio ? null : _saveQuickBio,
                      child: _isSavingBio
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                          : const Text('Save Bio', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            )
          else
            GestureDetector(
              onTap: () => setState(() => _isEditingBio = true),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  user.bio != null && user.bio!.trim().isNotEmpty
                      ? '"${user.bio!}"'
                      : 'Add a bio to express your cinematic taste... ✏️',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    height: 1.4,
                    color: user.bio != null && user.bio!.trim().isNotEmpty ? AppColors.textSecondary : AppColors.textMuted,
                    fontStyle: user.bio != null && user.bio!.trim().isNotEmpty ? FontStyle.italic : FontStyle.normal,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 16),

          // Interactive Stat Counters Row
          Row(
            children: [
              Expanded(
                child: _buildStatChip(
                  count: user.entriesCount > 0 ? user.entriesCount : _historyEntries.length,
                  label: 'Watches',
                  onTap: () => _tabController.animateTo(0),
                  isPrimary: true,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatChip(
                  count: user.followersCount,
                  label: 'Followers',
                  onTap: () async {
                    await FollowListSheet.show(
                      context,
                      userId: user.id,
                      title: 'Followers',
                      isFollowers: true,
                    );
                    _refreshFollowStats(user.id);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatChip(
                  count: user.followingCount,
                  label: 'Following',
                  onTap: () async {
                    await FollowListSheet.show(
                      context,
                      userId: user.id,
                      title: 'Following',
                      isFollowers: false,
                    );
                    _refreshFollowStats(user.id);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Action Buttons: Edit Profile, Compare Taste & Invite Friends
          Row(
            children: [
              Expanded(
                flex: 3,
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
                      onSaved: _loadProfileData,
                    );
                  },
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text(
                    'Edit Profile',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.primary.withOpacity(0.12),
                  foregroundColor: AppColors.primaryDark,
                  padding: const EdgeInsets.all(12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                tooltip: 'Compare Taste with Friends',
                onPressed: () => ComparePickerModal.show(context),
                icon: const Icon(Icons.compare_arrows_rounded, size: 20),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.surfaceHighest,
                  foregroundColor: AppColors.textPrimary,
                  padding: const EdgeInsets.all(12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                tooltip: 'Invite Friends',
                onPressed: () => _handleInviteFriends(user),
                icon: const Icon(Icons.person_add_outlined, size: 20),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip({
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

  Widget _buildHistoryTab() {
    if (_historyEntries.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.movie_outlined, size: 30, color: AppColors.primary),
              ),
              const SizedBox(height: 14),
              const Text(
                'No Watch Entries Logged Yet',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Log movies and TV series you have watched to start building your cinematic hive!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadProfileData,
      color: AppColors.primary,
      child: GridView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
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
            tags: entry.tags,
            onTap: () {
              if (entry.tmdbId > 0) {
                context.push('/details/$mediaType/${entry.tmdbId}');
              }
            },
            onEdit: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => AddEntrySheet(
                  editEntry: entry,
                  onSuccess: _loadProfileData,
                ),
              );
            },
            onDelete: () => _deleteEntry(entry),
          );
        },
      ),
    );
  }

  Widget _buildWatchingTab() {
    if (_watchingEntries.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.visibility_outlined, size: 30, color: AppColors.primary),
              ),
              const SizedBox(height: 14),
              const Text(
                'Nothing Currently Watching',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Mark entries as currently watching to track your active series and shows!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadProfileData,
      color: AppColors.primary,
      child: GridView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
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
            tags: entry.tags,
            onTap: () {
              if (entry.tmdbId > 0) {
                context.push('/details/$mediaType/${entry.tmdbId}');
              }
            },
            onMarkWatched: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => AddEntrySheet(
                  editEntry: entry,
                  prefillIsWatching: false,
                  onSuccess: _loadProfileData,
                ),
              );
            },
            onEdit: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => AddEntrySheet(
                  editEntry: entry,
                  onSuccess: _loadProfileData,
                ),
              );
            },
            onDelete: () => _deleteEntry(entry),
          );
        },
      ),
    );
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
