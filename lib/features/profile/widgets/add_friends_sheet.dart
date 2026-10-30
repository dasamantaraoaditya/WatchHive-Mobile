import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/config/web_urls.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/models/user.dart';
import '../../../shared/widgets/shared_widgets.dart';
import '../repositories/user_repository.dart';
import '../../search/repositories/search_repository.dart';
import '../../scanner/widgets/user_qr_dialog.dart';

class AddFriendsSheet extends ConsumerStatefulWidget {
  final User user;

  const AddFriendsSheet({
    super.key,
    required this.user,
  });

  static Future<void> show(
    BuildContext context, {
    required User user,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AddFriendsSheet(user: user),
    );
  }

  @override
  ConsumerState<AddFriendsSheet> createState() => _AddFriendsSheetState();
}

class _AddFriendsSheetState extends ConsumerState<AddFriendsSheet> {
  List<User>? _suggestedUsers;
  bool _isLoadingSuggestions = true;
  final Map<String, bool> _followingMap = {};
  final Map<String, bool> _loadingFollowMap = {};

  @override
  void initState() {
    super.initState();
    _loadSuggestedUsers();
  }

  Future<void> _loadSuggestedUsers() async {
    setState(() => _isLoadingSuggestions = true);
    try {
      final results = await ref.read(searchRepositoryProvider).getSuggestedUsers();
      if (mounted) {
        setState(() {
          _suggestedUsers = results;
          _isLoadingSuggestions = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingSuggestions = false);
    }
  }

  void _handleInvite() {
    final profileUrl = WebUrls.userProfile(widget.user.id, refUsername: widget.user.username);
    final text = 'Join me on WatchersHive! Check out my cinematic journey and let\'s build our movie hive together. 🐝🎥\n\n$profileUrl';
    Share.share(text, subject: 'Join me on WatchersHive');
  }

  Future<void> _toggleFollow(User target) async {
    final isFollowing = _followingMap[target.id] ?? false;
    setState(() => _loadingFollowMap[target.id] = true);

    try {
      if (isFollowing) {
        await ref.read(userRepositoryProvider).unfollowUser(target.id);
        if (mounted) {
          setState(() => _followingMap[target.id] = false);
        }
      } else {
        await ref.read(userRepositoryProvider).followUser(target.id);
        if (mounted) {
          setState(() => _followingMap[target.id] = true);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update follow status: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loadingFollowMap[target.id] = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 12, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.group_add_rounded,
                          color: AppColors.primary,
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Add Friends to Your Hive',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'Connect, share suggestions & compare taste',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 11,
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: AppColors.textMuted),
                  onPressed: () => Navigator.pop(context),
                  tooltip: 'Close',
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: AppColors.border),

          // Scrollable body
          Flexible(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                // 1. Quick Actions Grid
                Row(
                  children: [
                    // Search Cinephiles
                    Expanded(
                      child: _buildActionCard(
                        icon: Icons.search_rounded,
                        title: 'Search Cinephiles',
                        subtitle: 'Find by name or @username',
                        onTap: () {
                          Navigator.pop(context);
                          context.push('/search?tab=people');
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Invite Friends
                    Expanded(
                      child: _buildActionCard(
                        icon: Icons.share_rounded,
                        title: 'Invite Friends',
                        subtitle: 'Share your personal invite link',
                        onTap: () {
                          Navigator.pop(context);
                          _handleInvite();
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    // Show My QR Code
                    Expanded(
                      child: _buildActionCard(
                        icon: Icons.qr_code_2_rounded,
                        title: 'My Hive Code',
                        subtitle: 'Show QR for friends to scan',
                        onTap: () {
                          Navigator.pop(context);
                          UserQrDialog.show(
                            context,
                            userId: widget.user.id,
                            name: widget.user.name,
                            username: widget.user.username,
                            profilePictureUrl: widget.user.profilePictureUrl,
                            isMe: true,
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Scan QR Code
                    Expanded(
                      child: _buildActionCard(
                        icon: Icons.qr_code_scanner_rounded,
                        title: 'Scan QR Code',
                        subtitle: 'Open camera to follow friend',
                        onTap: () {
                          Navigator.pop(context);
                          context.push('/scanner');
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // 2. Suggested Cinephiles Section Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.stars_rounded, color: AppColors.primary, size: 18),
                        SizedBox(width: 6),
                        Text(
                          'Suggested Cinephiles',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                    if (!_isLoadingSuggestions)
                      GestureDetector(
                        onTap: _loadSuggestedUsers,
                        child: const Row(
                          children: [
                            Icon(Icons.refresh_rounded, size: 14, color: AppColors.textMuted),
                            SizedBox(width: 4),
                            Text(
                              'Refresh',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 12),

                // Suggested Cinephiles List
                if (_isLoadingSuggestions)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                      ),
                    ),
                  )
                else if (_suggestedUsers == null || _suggestedUsers!.isEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Center(
                      child: Column(
                        children: [
                          const Text(
                            'No new suggestions right now.',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                              context.push('/search?tab=people');
                            },
                            child: const Text(
                              'Search members on Explore →',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ..._suggestedUsers!.take(5).map((u) {
                    final isFollowing = _followingMap[u.id] ?? false;
                    final isLoadingFollow = _loadingFollowMap[u.id] ?? false;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () {
                              Navigator.pop(context);
                              context.push('/profile/${u.id}');
                            },
                            child: WHAvatar(
                              imageUrl: u.profilePictureUrl,
                              name: u.displayName ?? u.username,
                              radius: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                Navigator.pop(context);
                                context.push('/profile/${u.id}');
                              },
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    u.displayName ?? u.username,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    '@${u.username}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 11,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            height: 32,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isFollowing ? AppColors.surface : AppColors.primary,
                                foregroundColor: isFollowing ? AppColors.textPrimary : const Color(0xFF2D2926),
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  side: isFollowing
                                      ? const BorderSide(color: AppColors.border)
                                      : BorderSide.none,
                                ),
                              ),
                              onPressed: isLoadingFollow ? null : () => _toggleFollow(u),
                              icon: isLoadingFollow
                                  ? const SizedBox(
                                      width: 12,
                                      height: 12,
                                      child: CircularProgressIndicator(strokeWidth: 1.5, color: AppColors.primary),
                                    )
                                  : Icon(
                                      isFollowing ? Icons.check_rounded : Icons.person_add_rounded,
                                      size: 14,
                                    ),
                              label: Text(
                                isFollowing ? 'Following' : 'Follow',
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Icon(icon, color: AppColors.primary, size: 18),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 10,
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
