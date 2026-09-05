import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../shared/models/models.dart' as wh;

final notificationsRepositoryProvider = Provider<NotificationsRepository>((ref) {
  return NotificationsRepository(ref.read(apiClientProvider));
});

class PendingFollowRequest {
  final String id;
  final String requesterId;
  final String username;
  final String? displayName;
  final String? profilePictureUrl;
  final DateTime createdAt;

  const PendingFollowRequest({
    required this.id,
    required this.requesterId,
    required this.username,
    this.displayName,
    this.profilePictureUrl,
    required this.createdAt,
  });

  String get name => (displayName != null && displayName!.trim().isNotEmpty) ? displayName! : username;

  factory PendingFollowRequest.fromJson(Map<String, dynamic> json) {
    final requester = json['requester'] is Map<String, dynamic>
        ? json['requester'] as Map<String, dynamic>
        : (json['user'] is Map<String, dynamic> ? json['user'] as Map<String, dynamic> : json);

    return PendingFollowRequest(
      id: json['id']?.toString() ?? '',
      requesterId: requester['id']?.toString() ?? json['requesterId']?.toString() ?? '',
      username: requester['username'] as String? ?? 'user',
      displayName: requester['displayName'] as String?,
      profilePictureUrl: requester['profilePictureUrl'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

class NotificationsRepository {
  final ApiClient _api;

  NotificationsRepository(this._api);

  Future<List<wh.Notification>> getNotifications({int limit = 30, int offset = 0}) async {
    final response = await _api.get(
      ApiEndpoints.notifications,
      queryParameters: {'limit': limit, 'offset': offset},
    );
    final data = response.data;
    List<dynamic> items = [];
    if (data is Map<String, dynamic>) {
      items = data['notifications'] as List<dynamic>? ?? [];
    } else if (data is List) {
      items = data;
    }
    return items.map((n) => wh.Notification.fromJson(n as Map<String, dynamic>)).toList();
  }

  Future<void> markAllRead() async {
    await _api.post(ApiEndpoints.markAllNotificationsRead);
  }

  Future<void> markRead(String id) async {
    await _api.patch(ApiEndpoints.markNotificationRead(id));
  }

  /// Fetch pending follow requests waiting for current user's approval
  Future<List<PendingFollowRequest>> getPendingFollowRequests() async {
    try {
      final response = await _api.get(ApiEndpoints.pendingFollowRequests);
      final data = response.data;
      List<dynamic> list = [];
      if (data is List) {
        list = data;
      } else if (data is Map && data['requests'] is List) {
        list = data['requests'] as List;
      }
      return list.map((item) => PendingFollowRequest.fromJson(item as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Accept incoming follow request
  Future<void> acceptFollowRequest(String requestId) async {
    await _api.post(ApiEndpoints.acceptFollowRequest(requestId));
  }

  /// Reject incoming follow request
  Future<void> rejectFollowRequest(String requestId) async {
    await _api.post(ApiEndpoints.rejectFollowRequest(requestId));
  }
}
