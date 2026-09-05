import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/models/models.dart' as wh;
import '../../../shared/widgets/shared_widgets.dart';
import '../providers/notifications_provider.dart';
import '../repositories/notifications_repository.dart';

// Re-export repository provider for backward compatibility
export '../repositories/notifications_repository.dart'
    show notificationsRepositoryProvider, NotificationsRepository, PendingFollowRequest;

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(notificationsProvider.notifier).loadAll();
    });
  }

  Future<void> _handleAccept(PendingFollowRequest request) async {
    HapticFeedback.lightImpact();
    try {
      await ref.read(notificationsProvider.notifier).acceptRequest(request.id);
      if (mounted) {
        WHAlert.showSuccess(context, 'Accepted follow request from @${request.username}! 🤝');
      }
    } catch (e) {
      if (mounted) {
        WHAlert.showError(context, 'Failed to accept follow request. Please try again.');
      }
    }
  }

  Future<void> _handleReject(PendingFollowRequest request) async {
    HapticFeedback.lightImpact();
    try {
      await ref.read(notificationsProvider.notifier).rejectRequest(request.id);
      if (mounted) {
        WHAlert.showInfo(context, 'Declined follow request from @${request.username}.');
      }
    } catch (e) {
      if (mounted) {
        WHAlert.showError(context, 'Failed to decline follow request. Please try again.');
      }
    }
  }

  Future<void> _handleNotificationAccept(wh.Notification n) async {
    HapticFeedback.lightImpact();
    final requestId = n.content['requestId']?.toString() ??
        n.content['followRequestId']?.toString() ??
        n.content['id']?.toString() ??
        n.id;
    try {
      await ref.read(notificationsProvider.notifier).acceptRequest(requestId, notificationId: n.id);
      if (mounted) {
        final actor = n.content['actorName'] ?? n.content['actorUsername'] ?? 'User';
        WHAlert.showSuccess(context, 'Accepted follow request from $actor! 🤝');
      }
    } catch (e) {
      if (mounted) {
        WHAlert.showError(context, 'Failed to accept follow request: $e');
      }
    }
  }

  Future<void> _handleNotificationReject(wh.Notification n) async {
    HapticFeedback.lightImpact();
    final requestId = n.content['requestId']?.toString() ??
        n.content['followRequestId']?.toString() ??
        n.content['id']?.toString() ??
        n.id;
    try {
      await ref.read(notificationsProvider.notifier).rejectRequest(requestId, notificationId: n.id);
      if (mounted) {
        final actor = n.content['actorName'] ?? n.content['actorUsername'] ?? 'User';
        WHAlert.showInfo(context, 'Declined follow request from $actor.');
      }
    } catch (e) {
      if (mounted) {
        WHAlert.showError(context, 'Failed to decline follow request: $e');
      }
    }
  }

  void _navigateToTarget(wh.Notification n) {
    ref.read(notificationsProvider.notifier).markRead(n.id);

    final content = n.content;
    final actorId = content['actorId']?.toString() ??
        content['senderId']?.toString() ??
        content['userId']?.toString() ??
        content['requesterId']?.toString();

    // 1. Follow & request events -> Navigate to actor's profile
    if (n.type == 'FOLLOW' || n.type == 'FOLLOW_REQUEST' || n.type == 'FOLLOW_ACCEPT') {
      if (actorId != null && actorId.isNotEmpty) {
        context.push('/profile/$actorId');
        return;
      }
    }

    // 2. Media / review interactions -> Navigate to movie details
    final tmdbId = content['tmdbId'] is num
        ? (content['tmdbId'] as num).toInt()
        : int.tryParse(content['tmdbId']?.toString() ?? '');
    final mediaType = content['mediaType']?.toString().toLowerCase() ?? 'movie';

    if (tmdbId != null && tmdbId > 0) {
      context.push('/details/$mediaType/$tmdbId');
      return;
    }

    // 3. Fallback to actor's profile if available
    if (actorId != null && actorId.isNotEmpty) {
      context.push('/profile/$actorId');
    }
  }

  IconData _iconForType(String type) => switch (type) {
        'LIKE' => Icons.favorite_rounded,
        'COMMENT' || 'REPLY' => Icons.chat_bubble_rounded,
        'FOLLOW' || 'FOLLOW_ACCEPT' => Icons.person_add_rounded,
        'FOLLOW_REQUEST' => Icons.person_add_alt_1_rounded,
        'SUGGESTION' => Icons.recommend_rounded,
        _ => Icons.notifications_rounded,
      };

  Color _colorForType(String type) => switch (type) {
        'LIKE' => AppColors.error,
        'COMMENT' || 'REPLY' => AppColors.info,
        'FOLLOW' || 'FOLLOW_ACCEPT' => AppColors.success,
        'FOLLOW_REQUEST' => AppColors.primary,
        'SUGGESTION' => Colors.amber,
        _ => AppColors.textSecondary,
      };

  String _textForNotification(wh.Notification n) {
    final content = n.content;
    final actorName = content['actorName'] as String? ??
        content['senderName'] as String? ??
        content['actorUsername'] as String? ??
        'Someone';
    return switch (n.type) {
      'LIKE' => '$actorName liked your entry',
      'COMMENT' => '$actorName commented on your entry',
      'REPLY' => '$actorName replied to your comment',
      'FOLLOW' => '$actorName started following you',
      'FOLLOW_REQUEST' => '$actorName requested to follow you',
      'FOLLOW_ACCEPT' => '$actorName accepted your follow request',
      'SUGGESTION' => '$actorName suggested "${content['mediaTitle'] ?? 'something'}"',
      _ => 'New notification',
    };
  }

  @override
  Widget build(BuildContext context) {
    final notifState = ref.watch(notificationsProvider);
    final unreadCount = notifState.unreadCount;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Notifications',
          style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w800, fontSize: 18),
        ),
        actions: [
          if (unreadCount > 0)
            TextButton(
              onPressed: () => ref.read(notificationsProvider.notifier).markAllRead(),
              child: const Text(
                'Mark all read',
                style: TextStyle(fontFamily: 'Inter', color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ),
        ],
      ),
      body: notifState.isLoading && notifState.notifications.isEmpty && notifState.pendingRequests.isEmpty
          ? WHSkeleton(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                itemCount: 6,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, __) => Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Row(
                    children: [
                      WHSkeletonBox(width: 42, height: 42, shape: BoxShape.circle),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            WHSkeletonBox(width: double.infinity, height: 13, borderRadius: 4),
                            SizedBox(height: 6),
                            WHSkeletonBox(width: 90, height: 10, borderRadius: 4),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          : notifState.error != null && notifState.notifications.isEmpty && notifState.pendingRequests.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: const BoxDecoration(
                            color: AppColors.surfaceHighest,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.notifications_off_outlined, size: 40, color: AppColors.textMuted),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Notifications Unavailable',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          notifState.error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 14),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: () => ref.read(notificationsProvider.notifier).loadAll(),
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
                )
              : notifState.notifications.isEmpty && notifState.pendingRequests.isEmpty
                  ? const _EmptyNotifications()
                  : RefreshIndicator(
                      color: AppColors.primary,
                      onRefresh: () => ref.read(notificationsProvider.notifier).loadAll(),
                      child: ListView(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        children: [
                          // Pinned Pending Follow Requests Section
                          if (notifState.pendingRequests.isNotEmpty) ...[
                            _PendingFollowRequestsCard(
                              requests: notifState.pendingRequests,
                              actionLoadingIds: notifState.actionLoadingIds,
                              onAccept: _handleAccept,
                              onReject: _handleReject,
                              onTapUser: (userId) => context.push('/profile/$userId'),
                            ),
                            const Divider(height: 16, thickness: 1, color: AppColors.border),
                          ],

                          // Notifications List
                          ...notifState.notifications.map((n) {
                            final requestId = n.content['requestId']?.toString() ??
                                n.content['followRequestId']?.toString() ??
                                n.content['id']?.toString() ??
                                n.id;
                            final isActionLoading = notifState.actionLoadingIds.contains(n.id) ||
                                notifState.actionLoadingIds.contains(requestId);

                            return _NotificationTile(
                              key: ValueKey(n.id),
                              notification: n,
                              icon: _iconForType(n.type),
                              iconColor: _colorForType(n.type),
                              text: _textForNotification(n),
                              isActionLoading: isActionLoading,
                              onTap: () => _navigateToTarget(n),
                              onAccept: () => _handleNotificationAccept(n),
                              onReject: () => _handleNotificationReject(n),
                              onTapAvatar: () {
                                final actorId = n.content['actorId']?.toString() ??
                                    n.content['senderId']?.toString() ??
                                    n.content['userId']?.toString() ??
                                    n.content['requesterId']?.toString();
                                if (actorId != null && actorId.isNotEmpty) {
                                  context.push('/profile/$actorId');
                                }
                              },
                            );
                          }),
                        ],
                      ),
                    ),
    );
  }
}

// ─── Pending Follow Requests Card ──────────────────────────────────────────────

class _PendingFollowRequestsCard extends StatelessWidget {
  final List<PendingFollowRequest> requests;
  final Set<String> actionLoadingIds;
  final Function(PendingFollowRequest) onAccept;
  final Function(PendingFollowRequest) onReject;
  final Function(String) onTapUser;

  const _PendingFollowRequestsCard({
    required this.requests,
    required this.actionLoadingIds,
    required this.onAccept,
    required this.onReject,
    required this.onTapUser,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.person_add_rounded, size: 16, color: AppColors.primaryDark),
                ),
                const SizedBox(width: 8),
                Text(
                  'Follow Requests (${requests.length})',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: 6),
            itemCount: requests.length,
            separatorBuilder: (_, __) => const Divider(height: 1, indent: 64, color: AppColors.border),
            itemBuilder: (context, i) {
              final req = requests[i];
              final isLoading = actionLoadingIds.contains(req.id);

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => onTapUser(req.requesterId),
                      child: WHAvatar(
                        imageUrl: req.profilePictureUrl,
                        name: req.name,
                        radius: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => onTapUser(req.requesterId),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              req.name,
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '@${req.username}',
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 11,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (isLoading)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                      )
                    else
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.black,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              visualDensity: VisualDensity.compact,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () => onAccept(req),
                            child: const Text(
                              'Confirm',
                              style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w800, fontSize: 12),
                            ),
                          ),
                          const SizedBox(width: 6),
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.textMuted,
                              side: const BorderSide(color: AppColors.border),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              visualDensity: VisualDensity.compact,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () => onReject(req),
                            child: const Text(
                              'Delete',
                              style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ─── Notification Tile with Inline Follow Request Actions ───────────────────────

class _NotificationTile extends StatelessWidget {
  final wh.Notification notification;
  final IconData icon;
  final Color iconColor;
  final String text;
  final bool isActionLoading;
  final VoidCallback onTap;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final VoidCallback onTapAvatar;

  const _NotificationTile({
    super.key,
    required this.notification,
    required this.icon,
    required this.iconColor,
    required this.text,
    required this.isActionLoading,
    required this.onTap,
    required this.onAccept,
    required this.onReject,
    required this.onTapAvatar,
  });

  @override
  Widget build(BuildContext context) {
    final isFollowRequest = notification.type == 'FOLLOW_REQUEST';
    final content = notification.content;
    final status = content['status']?.toString();
    final avatarUrl = content['actorAvatar']?.toString() ??
        content['senderAvatar']?.toString() ??
        content['avatar']?.toString();
    final actorName = content['actorName']?.toString() ??
        content['senderName']?.toString() ??
        content['actorUsername']?.toString() ??
        'User';

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: notification.isRead ? Colors.transparent : AppColors.primary.withValues(alpha: 0.05),
          border: const Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Avatar with badge or type icon
                GestureDetector(
                  onTap: onTapAvatar,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      if (avatarUrl != null && avatarUrl.isNotEmpty)
                        WHAvatar(imageUrl: avatarUrl, name: actorName, radius: 20)
                      else
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: iconColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(icon, color: iconColor, size: 20),
                        ),
                      Positioned(
                        right: -3,
                        bottom: -3,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            color: AppColors.surface,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(icon, size: 11, color: iconColor),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // Main Text & Timestamp
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        text,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13.5,
                          fontWeight: notification.isRead ? FontWeight.w400 : FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _timeAgo(notification.createdAt),
                        style: const TextStyle(fontFamily: 'Inter', fontSize: 11, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),

                // Unread Indicator Dot
                if (!notification.isRead && !isFollowRequest)
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),

            // Inline Actions for FOLLOW_REQUEST
            if (isFollowRequest) ...[
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.only(left: 52),
                child: status == 'ACCEPTED'
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle_rounded, size: 14, color: AppColors.success),
                            SizedBox(width: 4),
                            Text(
                              'Request Accepted',
                              style: TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.success),
                            ),
                          ],
                        ),
                      )
                    : status == 'REJECTED'
                        ? Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceHighest,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Request Declined',
                              style: TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textMuted),
                            ),
                          )
                        : isActionLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                              )
                            : Row(
                                children: [
                                  ElevatedButton.icon(
                                    key: const Key('notification_accept_btn'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      foregroundColor: Colors.black,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                      visualDensity: VisualDensity.compact,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    onPressed: onAccept,
                                    icon: const Icon(Icons.check_rounded, size: 14),
                                    label: const Text(
                                      'Confirm',
                                      style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w800, fontSize: 12),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  OutlinedButton.icon(
                                    key: const Key('notification_reject_btn'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppColors.textMuted,
                                      side: const BorderSide(color: AppColors.border),
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      visualDensity: VisualDensity.compact,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    onPressed: onReject,
                                    icon: const Icon(Icons.close_rounded, size: 14),
                                    label: const Text(
                                      'Delete',
                                      style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600, fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
              ),
            ],
          ],
        ),
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

class _EmptyNotifications extends StatelessWidget {
  const _EmptyNotifications();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('🔔', style: TextStyle(fontSize: 56)),
            SizedBox(height: 20),
            Text(
              'No notifications yet',
              style: TextStyle(fontFamily: 'Inter', fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
            SizedBox(height: 8),
            Text(
              'Follow requests, likes, comments, and recommendations will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
