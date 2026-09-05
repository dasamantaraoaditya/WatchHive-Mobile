import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/models/user.dart';
import '../../../shared/widgets/shared_widgets.dart';
import '../../auth/providers/auth_provider.dart';
import '../repositories/user_repository.dart';
import '../widgets/follow_list_sheet.dart';
import '../widgets/profile_stats_view.dart';
import '../widgets/compare_picker_modal.dart';
import '../widgets/data_management_card.dart';
import 'edit_profile_dialog.dart';
import '../../../core/utils/error_handler.dart';
import '../../onboarding/widgets/quick_guide_tour_dialog.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  bool _isEditingBio = false;
  late final TextEditingController _bioTextController;
  bool _isSavingBio = false;
  bool _isUploadingAvatar = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
      final user = await userRepo.getCurrentUser();
      ref.read(authStateProvider.notifier).updateUser(user);
      _bioTextController.text = user.bio ?? '';

      final followStats = await userRepo.getFollowStats(user.id);
      final updatedUser = user.copyWith(
        followersCount: followStats.followersCount,
        followingCount: followStats.followingCount,
      );
      ref.read(authStateProvider.notifier).updateUser(updatedUser);

      if (mounted) setState(() => _isLoading = false);
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

  Future<void> _updatePrivacyField(String field, dynamic value) async {
    final user = ref.read(authStateProvider).value?.user;
    if (user == null) return;

    try {
      final repo = ref.read(userRepositoryProvider);
      final updatedUser = await repo.updateProfile(user.id, {field: value});
      ref.read(authStateProvider.notifier).updateUser(updatedUser);
      if (mounted) {
        WHAlert.showSuccess(
          context,
          'Setting updated! Tap "View Public Profile" to preview changes.',
        );
      }
    } catch (e) {
      if (mounted) {
        WHAlert.showError(
          context,
          AppErrorHandler.toUserFriendlyMessage(
            e,
            defaultMessage: 'Failed to update setting. Please try again.',
          ),
        );
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
        WHAlert.showError(
          context,
          AppErrorHandler.toUserFriendlyMessage(
            e,
            defaultMessage: 'Failed to upload image. Please try again.',
          ),
        );
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
        WHAlert.showError(
          context,
          AppErrorHandler.toUserFriendlyMessage(
            e,
            defaultMessage: 'Failed to remove image. Please try again.',
          ),
        );
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
        WHAlert.showError(
          context,
          AppErrorHandler.toUserFriendlyMessage(
            e,
            defaultMessage: 'Failed to update bio. Please try again.',
          ),
        );
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
                  icon: const Icon(Icons.help_outline_rounded, color: AppColors.textSecondary),
                  tooltip: 'Quick Guide Tour',
                  onPressed: () => QuickGuideTourDialog.show(
                    context,
                    userId: user.id,
                    isReplay: true,
                  ),
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
                  isScrollable: false,
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
                  tabs: const [
                    Tab(text: 'Privacy & Visibility'),
                    Tab(text: 'Hive Analytics'),
                  ],
                ),
              ),
            ),
          ];
        },
        body: _isLoading
            ? const Padding(
                padding: EdgeInsets.all(16),
                child: WHSkeleton(
                  child: Column(
                    children: [
                      WHSkeletonBox(height: 52, borderRadius: 12),
                      SizedBox(height: 12),
                      WHSkeletonBox(height: 52, borderRadius: 12),
                      SizedBox(height: 12),
                      WHSkeletonBox(height: 52, borderRadius: 12),
                    ],
                  ),
                ),
              )
            : TabBarView(
                controller: _tabController,
                children: [
                  _buildPrivacyAndSettingsTab(user),
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
            color: Colors.black.withValues(alpha: 0.02),
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
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
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
                  if (_isUploadingAvatar)
                    Positioned.fill(
                      child: ClipOval(
                        child: Container(
                          color: Colors.black45,
                          child: const Center(
                            child: WHSkeleton(
                              child: WHSkeletonBox(
                                width: 72,
                                height: 72,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
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
                    GestureDetector(
                      onTap: () {
                        EditProfileDialog.show(
                          context,
                          user: user,
                          onSaved: _loadProfileData,
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.location_on_outlined,
                              size: 12,
                              color: (user.location != null && user.location!.trim().isNotEmpty)
                                  ? AppColors.textMuted
                                  : AppColors.primaryDark,
                            ),
                            const SizedBox(width: 3),
                            Flexible(
                              child: Text(
                                (user.location != null && user.location!.trim().isNotEmpty)
                                    ? user.location!.trim()
                                    : 'Add location',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 11,
                                  fontWeight: (user.location != null && user.location!.trim().isNotEmpty)
                                      ? FontWeight.w500
                                      : FontWeight.w600,
                                  color: (user.location != null && user.location!.trim().isNotEmpty)
                                      ? AppColors.textMuted
                                      : AppColors.primaryDark,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
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
                  count: user.entriesCount,
                  label: 'Watches',
                  onTap: () => context.push('/profile/${user.id}'),
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

          // View Public Profile Button (Prominent)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.black,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () => context.push('/profile/${user.id}'),
              icon: const Icon(Icons.remove_red_eye_outlined, size: 20),
              label: const Text(
                'View Public Profile',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ),
          const SizedBox(height: 5),
          const Center(
            child: Text(
              'See how your profile appears to other users for reference',
              style: TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
          ),
          const SizedBox(height: 14),

          // Action Buttons: Edit Profile, Compare Taste & Invite Friends
          Row(
            children: [
              Expanded(
                flex: 3,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: const BorderSide(color: AppColors.border),
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
                  backgroundColor: AppColors.primary.withValues(alpha: 0.12),
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
          color: isPrimary ? AppColors.primary.withValues(alpha: 0.08) : AppColors.background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isPrimary ? AppColors.primary.withValues(alpha: 0.3) : AppColors.border,
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

  Widget _buildPrivacyAndSettingsTab(User user) {
    final currentTier = user.privacyLevel.isNotEmpty
        ? user.privacyLevel
        : (user.isPrivate ? 'FOLLOWERS_ONLY' : 'PUBLIC');

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Privacy Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.lock_outline_rounded, size: 18, color: AppColors.primaryDark),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Privacy & Visibility',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Control what other members see when visiting your profile',
                            style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                const Text(
                  'PROFILE VISIBILITY TIER',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 10),
                _buildPrivacyTierChips(user),
                const SizedBox(height: 20),

                if (currentTier != 'PRIVATE') ...[
                  const Text(
                    'TAB VISIBILITY PERMISSIONS',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Toggle individual sections visible to visitors on your public profile:',
                    style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 12),

                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surfaceHighest.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        _buildSwitchTile(
                          icon: Icons.history_rounded,
                          title: 'Show Watch Entries',
                          subtitle: 'Display movies & shows you have watched',
                          value: user.showWatchEntries,
                          onChanged: (v) => _updatePrivacyField('showWatchEntries', v),
                        ),
                        const Divider(height: 1, color: AppColors.border),
                        _buildSwitchTile(
                          icon: Icons.visibility_outlined,
                          title: 'Currently Watching',
                          subtitle: 'Show what you are currently viewing',
                          value: user.showCurrentlyWatching,
                          onChanged: (v) => _updatePrivacyField('showCurrentlyWatching', v),
                        ),
                        const Divider(height: 1, color: AppColors.border),
                        _buildSwitchTile(
                          icon: Icons.list_alt_rounded,
                          title: 'Show Watchlist',
                          subtitle: 'Let visitors see your upcoming picks',
                          value: user.showWatchlist,
                          onChanged: (v) => _updatePrivacyField('showWatchlist', v),
                        ),
                        const Divider(height: 1, color: AppColors.border),
                        _buildSwitchTile(
                          icon: Icons.format_list_numbered_rounded,
                          title: 'Show Rankings & Stacks',
                          subtitle: 'Allow others to view your ranked stacks',
                          value: user.showRankings,
                          onChanged: (v) => _updatePrivacyField('showRankings', v),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceHighest,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.shield_outlined, size: 20, color: AppColors.textMuted),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Your profile is set to Strictly Private. Other users cannot see your watch entries, lists, or rankings.',
                            style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.3),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 16),
                InkWell(
                  onTap: () => context.push('/profile/${user.id}'),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.remove_red_eye_outlined, size: 16, color: AppColors.primaryDark),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Tap here to preview how visitors see your profile',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryDark,
                            ),
                          ),
                        ),
                        Icon(Icons.arrow_forward_ios_rounded, size: 12, color: AppColors.primaryDark),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Quick Navigation & Account Shortcuts
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                _buildActionTile(
                  icon: Icons.format_list_numbered_rounded,
                  title: 'Rankings & Cinematic Stacks',
                  subtitle: 'Manage your ranked movie lists',
                  onTap: () => context.push('/rankings'),
                ),
                const Divider(height: 1, color: AppColors.border),
                _buildActionTile(
                  icon: Icons.compare_arrows_rounded,
                  title: 'Compare Taste with Friends',
                  subtitle: 'Inspect common taste and compatibility',
                  onTap: () => ComparePickerModal.show(context),
                ),
                const Divider(height: 1, color: AppColors.border),
                _buildActionTile(
                  icon: Icons.person_add_outlined,
                  title: 'Invite Friends to WatchHive',
                  subtitle: 'Share your personal invite link',
                  onTap: () => _handleInviteFriends(user),
                ),
                const Divider(height: 1, color: AppColors.border),
                _buildActionTile(
                  icon: Icons.explore_outlined,
                  title: 'App Guide Tour',
                  subtitle: 'Walkthrough of features & how to use WatchHive',
                  onTap: () => QuickGuideTourDialog.show(
                    context,
                    userId: user.id,
                    isReplay: true,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Data Management (Export & Import Hive Data)
          DataManagementCard(onDataChanged: _loadProfileData),
          const SizedBox(height: 16),

          // Sign Out Button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: const BorderSide(color: AppColors.error),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: _confirmSignOut,
              icon: const Icon(Icons.logout_rounded, size: 18),
              label: const Text(
                'Sign Out',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacyTierChips(User user) {
    final currentTier = user.privacyLevel.isNotEmpty
        ? user.privacyLevel
        : (user.isPrivate ? 'FOLLOWERS_ONLY' : 'PUBLIC');

    final tiers = [
      {'id': 'PUBLIC', 'label': 'Public', 'icon': Icons.public_rounded},
      {'id': 'FOLLOWERS_ONLY', 'label': 'Followers Only', 'icon': Icons.group_rounded},
      {'id': 'PRIVATE', 'label': 'Strictly Private', 'icon': Icons.lock_rounded},
    ];

    return Row(
      children: tiers.map((tier) {
        final isSelected = currentTier == tier['id'];
        return Expanded(
          child: GestureDetector(
            onTap: () => _updatePrivacyField('privacyLevel', tier['id']),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary.withValues(alpha: 0.15) : AppColors.surfaceHighest,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.border,
                  width: isSelected ? 1.5 : 1,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    tier['icon'] as IconData,
                    size: 18,
                    color: isSelected ? AppColors.primaryDark : AppColors.textMuted,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    tier['label'] as String,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 10,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                      color: isSelected ? AppColors.primaryDark : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      secondary: Icon(icon, color: AppColors.primaryDark, size: 20),
      title: Text(
        title,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
      ),
      value: value,
      activeThumbColor: AppColors.primary,
      onChanged: onChanged,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.surfaceHighest,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: AppColors.textPrimary, size: 18),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
      ),
      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 13, color: AppColors.textMuted),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
