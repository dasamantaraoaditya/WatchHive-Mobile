import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../shared/models/models.dart' as wh;
import '../../../shared/widgets/shared_widgets.dart';

// ─── Repository ───────────────────────────────────────────────────────────────

final notificationsRepositoryProvider = Provider<NotificationsRepository>((ref) {
  return NotificationsRepository(ref.read(apiClientProvider));
});

class NotificationsRepository {
  final ApiClient _api;

  NotificationsRepository(this._api);

  Future<List<wh.Notification>> getNotifications({int limit = 30, int offset = 0}) async {
    final response = await _api.get(
      ApiEndpoints.notifications,
      queryParameters: {'limit': limit, 'offset': offset},
    );
    final data = response.data as Map<String, dynamic>;
    final items = data['notifications'] as List<dynamic>? ?? [];
    return items.map((n) => wh.Notification.fromJson(n as Map<String, dynamic>)).toList();
  }

  Future<void> markAllRead() async {
    await _api.post(ApiEndpoints.markAllNotificationsRead);
  }

  Future<void> markRead(String id) async {
    await _api.patch(ApiEndpoints.markNotificationRead(id));
  }
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  List<wh.Notification> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    try {
      final result = await ref.read(notificationsRepositoryProvider).getNotifications();
      setState(() {
        _notifications = result;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _markAllRead() async {
    await ref.read(notificationsRepositoryProvider).markAllRead();
    setState(() {
      _notifications = _notifications.map((n) => wh.Notification(
        id: n.id,
        userId: n.userId,
        type: n.type,
        content: n.content,
        isRead: true,
        createdAt: n.createdAt,
      )).toList();
    });
  }

  IconData _iconForType(String type) => switch (type) {
        'LIKE' => Icons.favorite_rounded,
        'COMMENT' || 'REPLY' => Icons.chat_bubble_rounded,
        'FOLLOW' || 'FOLLOW_ACCEPT' => Icons.person_add_rounded,
        'FOLLOW_REQUEST' => Icons.person_add_outlined,
        'SUGGESTION' => Icons.recommend_rounded,
        _ => Icons.notifications_rounded,
      };

  Color _colorForType(String type) => switch (type) {
        'LIKE' => AppColors.error,
        'COMMENT' || 'REPLY' => AppColors.info,
        'FOLLOW' || 'FOLLOW_ACCEPT' => AppColors.success,
        'SUGGESTION' => AppColors.primary,
        _ => AppColors.textSecondary,
      };

  String _textForNotification(wh.Notification n) {
    final content = n.content;
    final actorName = content['actorName'] as String? ?? content['senderName'] as String? ?? 'Someone';
    return switch (n.type) {
      'LIKE' => '$actorName liked your entry',
      'COMMENT' => '$actorName commented on your entry',
      'REPLY' => '$actorName replied to your comment',
      'FOLLOW' => '$actorName started following you',
      'FOLLOW_REQUEST' => '$actorName sent you a follow request',
      'FOLLOW_ACCEPT' => '$actorName accepted your follow request',
      'SUGGESTION' => '$actorName suggested "${content['mediaTitle'] ?? 'something'}"',
      _ => 'New notification',
    };
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _notifications.where((n) => !n.isRead).length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (unreadCount > 0)
            TextButton(
              onPressed: _markAllRead,
              child: const Text('Mark all read'),
            ),
        ],
      ),
      body: _isLoading
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
                  child: Row(
                    children: const [
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
          : _notifications.isEmpty
              ? const _EmptyNotifications()
              : RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: _loadNotifications,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _notifications.length,
                    itemBuilder: (context, i) {
                      final n = _notifications[i];
                      return _NotificationTile(
                        notification: n,
                        icon: _iconForType(n.type),
                        iconColor: _colorForType(n.type),
                        text: _textForNotification(n),
                        onTap: () async {
                          if (!n.isRead) {
                            await ref.read(notificationsRepositoryProvider).markRead(n.id);
                            setState(() {
                              _notifications[i] = wh.Notification(
                                id: n.id,
                                userId: n.userId,
                                type: n.type,
                                content: n.content,
                                isRead: true,
                                createdAt: n.createdAt,
                              );
                            });
                          }
                        },
                      );
                    },
                  ),
                ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final wh.Notification notification;
  final IconData icon;
  final Color iconColor;
  final String text;
  final VoidCallback onTap;

  const _NotificationTile({
    required this.notification,
    required this.icon,
    required this.iconColor,
    required this.text,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: notification.isRead ? Colors.transparent : AppColors.primary.withOpacity(0.06),
          border: const Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    text,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: notification.isRead ? FontWeight.w400 : FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _timeAgo(notification.createdAt),
                    style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            if (!notification.isRead)
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
              'Activity from your followers will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
