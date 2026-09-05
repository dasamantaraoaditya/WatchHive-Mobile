import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watchhive_mobile/core/api/api_client.dart';
import 'package:watchhive_mobile/features/notifications/providers/notifications_provider.dart';
import 'package:watchhive_mobile/features/notifications/repositories/notifications_repository.dart';
import 'package:watchhive_mobile/features/notifications/screens/notifications_screen.dart';
import 'package:watchhive_mobile/shared/models/models.dart' as wh;

class MockNotificationsRepository implements NotificationsRepository {
  List<wh.Notification> mockNotifications = [];
  List<PendingFollowRequest> mockPendingRequests = [];
  bool acceptCalled = false;
  bool rejectCalled = false;
  String? lastAcceptedId;
  String? lastRejectedId;

  @override
  ApiClient get _api => throw UnimplementedError();

  @override
  Future<List<wh.Notification>> getNotifications({int limit = 30, int offset = 0}) async {
    return mockNotifications;
  }

  @override
  Future<List<PendingFollowRequest>> getPendingFollowRequests() async {
    return mockPendingRequests;
  }

  @override
  Future<void> acceptFollowRequest(String requestId) async {
    acceptCalled = true;
    lastAcceptedId = requestId;
  }

  @override
  Future<void> rejectFollowRequest(String requestId) async {
    rejectCalled = true;
    lastRejectedId = requestId;
  }

  @override
  Future<void> markAllRead() async {
    mockNotifications = mockNotifications.map((n) => wh.Notification(
      id: n.id,
      userId: n.userId,
      type: n.type,
      content: n.content,
      isRead: true,
      createdAt: n.createdAt,
    )).toList();
  }

  @override
  Future<void> markRead(String id) async {
    mockNotifications = mockNotifications.map((n) => n.id == id ? wh.Notification(
      id: n.id,
      userId: n.userId,
      type: n.type,
      content: n.content,
      isRead: true,
      createdAt: n.createdAt,
    ) : n).toList();
  }
}

void main() {
  group('Follow Request Notifications & Acceptance System Tests', () {
    late MockNotificationsRepository mockRepo;

    setUp(() {
      mockRepo = MockNotificationsRepository();
    });

    test('NotificationsNotifier state management for pending follow requests', () async {
      mockRepo.mockPendingRequests = [
        PendingFollowRequest(
          id: 'req-1',
          requesterId: 'user-2',
          username: 'sarah_connor',
          displayName: 'Sarah C',
          createdAt: DateTime.now(),
        ),
      ];
      mockRepo.mockNotifications = [
        wh.Notification(
          id: 'notif-1',
          userId: 'user-1',
          type: 'FOLLOW_REQUEST',
          content: {
            'actorId': 'user-2',
            'actorUsername': 'sarah_connor',
            'actorName': 'Sarah C',
            'requestId': 'req-1',
          },
          isRead: false,
          createdAt: DateTime.now(),
        ),
      ];

      final notifier = NotificationsNotifier(mockRepo);
      await notifier.loadAll();

      expect(notifier.state.pendingRequests.length, 1);
      expect(notifier.state.notifications.length, 1);
      expect(notifier.state.unreadCount, 2); // 1 unread notification + 1 pending request

      // Accept request
      final success = await notifier.acceptRequest('req-1', notificationId: 'notif-1');
      expect(success, isTrue);
      expect(mockRepo.acceptCalled, isTrue);
      expect(mockRepo.lastAcceptedId, 'req-1');
      expect(notifier.state.pendingRequests, isEmpty);
      expect(notifier.state.notifications.first.content['status'], 'ACCEPTED');
    });

    testWidgets('NotificationsScreen displays inline Confirm & Delete buttons for FOLLOW_REQUEST', (tester) async {
      mockRepo.mockNotifications = [
        wh.Notification(
          id: 'notif-10',
          userId: 'user-1',
          type: 'FOLLOW_REQUEST',
          content: {
            'actorId': 'user-99',
            'actorUsername': 'john_wick',
            'actorName': 'John Wick',
            'requestId': 'req-10',
          },
          isRead: false,
          createdAt: DateTime.now(),
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            notificationsRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: const MaterialApp(
            home: NotificationsScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify notification text
      expect(find.text('John Wick requested to follow you'), findsOneWidget);

      // Verify inline Confirm and Delete action buttons
      expect(find.byKey(const Key('notification_accept_btn')), findsOneWidget);
      expect(find.byKey(const Key('notification_reject_btn')), findsOneWidget);
      expect(find.text('Confirm'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);

      // Tap Confirm
      await tester.tap(find.byKey(const Key('notification_accept_btn')));
      await tester.pumpAndSettle();

      expect(mockRepo.acceptCalled, isTrue);
      expect(mockRepo.lastAcceptedId, 'req-10');
      expect(find.text('Request Accepted'), findsOneWidget);
    });

    testWidgets('NotificationsScreen displays top pending requests card when pendingRequests are present', (tester) async {
      mockRepo.mockPendingRequests = [
        PendingFollowRequest(
          id: 'req-pending-1',
          requesterId: 'user-88',
          username: 'neo_matrix',
          displayName: 'Thomas Anderson',
          createdAt: DateTime.now(),
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            notificationsRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: const MaterialApp(
            home: NotificationsScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Top Pending Card Header
      expect(find.text('Follow Requests (1)'), findsOneWidget);
      expect(find.text('Thomas Anderson'), findsOneWidget);
      expect(find.text('@neo_matrix'), findsOneWidget);

      // Tap Confirm inside top pending card
      await tester.tap(find.widgetWithText(ElevatedButton, 'Confirm'));
      await tester.pumpAndSettle();

      expect(mockRepo.acceptCalled, isTrue);
      expect(mockRepo.lastAcceptedId, 'req-pending-1');
    });
  });
}
