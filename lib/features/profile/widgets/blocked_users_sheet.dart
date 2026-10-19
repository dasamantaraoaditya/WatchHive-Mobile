import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/shared_widgets.dart';
import '../../feed/providers/feed_provider.dart';
import '../repositories/user_repository.dart';

class BlockedUsersSheet extends ConsumerStatefulWidget {
  const BlockedUsersSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const BlockedUsersSheet(),
    );
  }

  @override
  ConsumerState<BlockedUsersSheet> createState() => _BlockedUsersSheetState();
}

class _BlockedUsersSheetState extends ConsumerState<BlockedUsersSheet> {
  List<Map<String, dynamic>> _blockedUsers = [];
  bool _isLoading = true;
  final Set<String> _unblockingIds = {};

  @override
  void initState() {
    super.initState();
    _fetchBlockedUsers();
  }

  Future<void> _fetchBlockedUsers() async {
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(userRepositoryProvider);
      final list = await repo.getBlockedAccounts();
      if (mounted) {
        setState(() {
          _blockedUsers = list;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleUnblock(String userId, String username) async {
    final cleanName = username.startsWith('@') ? username : '@$username';
    final confirm = await WHAlert.confirm(
      context,
      title: 'Unblock $cleanName?',
      message: 'They will be able to see your profile and posts, and their content will appear in your feed again.',
      confirmText: 'Unblock',
      severity: WHAlertSeverity.primary,
      icon: Icons.person_add_rounded,
    );

    if (!confirm || !mounted) return;

    setState(() => _unblockingIds.add(userId));

    try {
      final repo = ref.read(userRepositoryProvider);
      await repo.unblockUser(userId);

      if (mounted) {
        setState(() {
          _blockedUsers.removeWhere((item) {
            final uId = item['blockedId'] ?? (item['user'] is Map ? item['user']['id'] : null);
            return uId == userId;
          });
          _unblockingIds.remove(userId);
        });

        // Invalidate or reload feed to show unblocked content
        ref.read(feedProvider.notifier).loadFeed();
        WHAlert.showSuccess(context, 'Unblocked $cleanName');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _unblockingIds.remove(userId));
        WHAlert.showError(context, 'Failed to unblock user. Please try again.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.block_rounded, color: AppColors.error, size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Blocked Accounts',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Manage accounts you have blocked',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: AppColors.textMuted),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(color: AppColors.border, height: 24),

          // Content
          Flexible(
            child: _isLoading
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: WHBeeSpinner(size: 32),
                    ),
                  )
                : _blockedUsers.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: const BoxDecoration(
                                color: AppColors.surfaceElevated,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.check_circle_outline_rounded,
                                size: 36,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(height: 14),
                            const Text(
                              'No Blocked Accounts',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'You have not blocked any members of the Hive. When you block someone, they will appear here.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12.5,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        itemCount: _blockedUsers.length,
                        separatorBuilder: (_, __) => const Divider(color: AppColors.border, height: 16),
                        itemBuilder: (context, index) {
                          final item = _blockedUsers[index];
                          final userObj = item['user'] is Map ? item['user'] as Map<String, dynamic> : null;
                          final userId = (item['blockedId'] ?? userObj?['id'] ?? '').toString();
                          final username = (userObj?['username'] ?? 'User').toString();
                          final displayName = (userObj?['displayName'] ?? username).toString();
                          final avatarUrl = userObj?['profilePictureUrl'] as String?;
                          final isUnblocking = _unblockingIds.contains(userId);

                          return Row(
                            children: [
                              WHAvatar(
                                imageUrl: avatarUrl,
                                name: displayName,
                                radius: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      displayName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      username.startsWith('@') ? username : '@$username',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 12,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  side: const BorderSide(color: AppColors.border),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                onPressed: isUnblocking ? null : () => _handleUnblock(userId, username),
                                child: isUnblocking
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : const Text(
                                        'Unblock',
                                        style: TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                              ),
                            ],
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
