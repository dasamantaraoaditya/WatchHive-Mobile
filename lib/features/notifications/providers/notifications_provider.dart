import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/models/models.dart' as wh;
import '../repositories/notifications_repository.dart';

class NotificationsState {
  final List<wh.Notification> notifications;
  final List<PendingFollowRequest> pendingRequests;
  final bool isLoading;
  final String? error;
  final Set<String> actionLoadingIds;

  const NotificationsState({
    this.notifications = const [],
    this.pendingRequests = const [],
    this.isLoading = false,
    this.error,
    this.actionLoadingIds = const {},
  });

  int get unreadCount =>
      notifications.where((n) => !n.isRead).length + pendingRequests.length;

  NotificationsState copyWith({
    List<wh.Notification>? notifications,
    List<PendingFollowRequest>? pendingRequests,
    bool? isLoading,
    String? error,
    Set<String>? actionLoadingIds,
  }) {
    return NotificationsState(
      notifications: notifications ?? this.notifications,
      pendingRequests: pendingRequests ?? this.pendingRequests,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      actionLoadingIds: actionLoadingIds ?? this.actionLoadingIds,
    );
  }
}

class NotificationsNotifier extends StateNotifier<NotificationsState> {
  final NotificationsRepository _repo;

  NotificationsNotifier(this._repo) : super(const NotificationsState()) {
    loadAll();
  }

  Future<void> loadAll() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final notifsFuture = _repo.getNotifications();
      final requestsFuture = _repo.getPendingFollowRequests();

      final results = await Future.wait([notifsFuture, requestsFuture]);
      final notifs = results[0] as List<wh.Notification>;
      final requests = results[1] as List<PendingFollowRequest>;

      state = state.copyWith(
        notifications: notifs,
        pendingRequests: requests,
        isLoading: false,
        error: null,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Could not load notifications. Pull down to refresh.',
      );
    }
  }

  Future<void> markAllRead() async {
    try {
      await _repo.markAllRead();
      final updated = state.notifications
          .map((n) => wh.Notification(
                id: n.id,
                userId: n.userId,
                type: n.type,
                content: n.content,
                isRead: true,
                createdAt: n.createdAt,
              ))
          .toList();
      state = state.copyWith(notifications: updated);
    } catch (_) {}
  }

  Future<void> markRead(String id) async {
    try {
      await _repo.markRead(id);
      final updated = state.notifications.map((n) {
        if (n.id == id) {
          return wh.Notification(
            id: n.id,
            userId: n.userId,
            type: n.type,
            content: n.content,
            isRead: true,
            createdAt: n.createdAt,
          );
        }
        return n;
      }).toList();
      state = state.copyWith(notifications: updated);
    } catch (_) {}
  }

  Future<bool> acceptRequest(String requestId, {String? notificationId}) async {
    final key = notificationId ?? requestId;
    state = state.copyWith(actionLoadingIds: {...state.actionLoadingIds, key});

    try {
      await _repo.acceptFollowRequest(requestId);

      // Remove from pending requests
      final remainingRequests =
          state.pendingRequests.where((r) => r.id != requestId).toList();

      // Update notification if associated
      final updatedNotifs = state.notifications.map((n) {
        final matches = (notificationId != null && n.id == notificationId) ||
            n.content['requestId'] == requestId ||
            n.content['followRequestId'] == requestId;
        if (matches) {
          final newContent = Map<String, dynamic>.from(n.content);
          newContent['status'] = 'ACCEPTED';
          return wh.Notification(
            id: n.id,
            userId: n.userId,
            type: n.type,
            content: newContent,
            isRead: true,
            createdAt: n.createdAt,
          );
        }
        return n;
      }).toList();

      final newLoading = Set<String>.from(state.actionLoadingIds)..remove(key);
      state = state.copyWith(
        pendingRequests: remainingRequests,
        notifications: updatedNotifs,
        actionLoadingIds: newLoading,
      );
      return true;
    } catch (e) {
      final newLoading = Set<String>.from(state.actionLoadingIds)..remove(key);
      state = state.copyWith(actionLoadingIds: newLoading);
      rethrow;
    }
  }

  Future<bool> rejectRequest(String requestId, {String? notificationId}) async {
    final key = notificationId ?? requestId;
    state = state.copyWith(actionLoadingIds: {...state.actionLoadingIds, key});

    try {
      await _repo.rejectFollowRequest(requestId);

      // Remove from pending requests
      final remainingRequests =
          state.pendingRequests.where((r) => r.id != requestId).toList();

      // Update notification if associated
      final updatedNotifs = state.notifications.map((n) {
        final matches = (notificationId != null && n.id == notificationId) ||
            n.content['requestId'] == requestId ||
            n.content['followRequestId'] == requestId;
        if (matches) {
          final newContent = Map<String, dynamic>.from(n.content);
          newContent['status'] = 'REJECTED';
          return wh.Notification(
            id: n.id,
            userId: n.userId,
            type: n.type,
            content: newContent,
            isRead: true,
            createdAt: n.createdAt,
          );
        }
        return n;
      }).toList();

      final newLoading = Set<String>.from(state.actionLoadingIds)..remove(key);
      state = state.copyWith(
        pendingRequests: remainingRequests,
        notifications: updatedNotifs,
        actionLoadingIds: newLoading,
      );
      return true;
    } catch (e) {
      final newLoading = Set<String>.from(state.actionLoadingIds)..remove(key);
      state = state.copyWith(actionLoadingIds: newLoading);
      rethrow;
    }
  }
}

final notificationsProvider =
    StateNotifierProvider<NotificationsNotifier, NotificationsState>((ref) {
  final repo = ref.watch(notificationsRepositoryProvider);
  return NotificationsNotifier(repo);
});

final unreadNotificationsCountProvider = Provider<int>((ref) {
  return ref.watch(notificationsProvider).unreadCount;
});
