import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:watchhive_mobile/shared/models/models.dart' as wh;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Notification Text Formatting Tests', () {
    String formatNotificationText(wh.Notification n) {
      final content = n.content;
      final actorName = content['actorName'] as String? ??
          content['senderName'] as String? ??
          content['actorUsername'] as String? ??
          'Someone';
      final title = (content['title'] as String?) ??
          (content['mediaTitle'] as String?) ??
          (content['name'] as String?) ??
          (content['entryTitle'] as String?);
      return switch (n.type) {
        'LIKE' => title != null && title.isNotEmpty
            ? '$actorName liked your entry for "$title"'
            : '$actorName liked your entry',
        'COMMENT' => title != null && title.isNotEmpty
            ? '$actorName commented on "$title"'
            : '$actorName commented on your entry',
        'REPLY' => '$actorName replied to your comment',
        'FOLLOW' => '$actorName started following you',
        'FOLLOW_REQUEST' => '$actorName requested to follow you',
        'FOLLOW_ACCEPT' => '$actorName accepted your follow request',
        'SUGGESTION' => title != null && title.isNotEmpty
            ? '$actorName suggested "$title"'
            : '$actorName suggested a title for you',
        _ => 'New notification',
      };
    }

    test('Suggestion notification displays actual title', () {
      final notif = wh.Notification(
        id: 'notif-1',
        userId: 'user-1',
        type: 'SUGGESTION',
        content: {
          'actorName': 'Sarah',
          'title': 'Oppenheimer',
          'tmdbId': 872585,
          'mediaType': 'movie',
          'message': 'You have to watch this!',
        },
        isRead: false,
        createdAt: DateTime.now(),
      );

      final text = formatNotificationText(notif);
      expect(text, 'Sarah suggested "Oppenheimer"');
    });

    test('Suggestion notification falls back to mediaTitle if title key is mediaTitle', () {
      final notif = wh.Notification(
        id: 'notif-2',
        userId: 'user-1',
        type: 'SUGGESTION',
        content: {
          'actorName': 'Alex',
          'mediaTitle': 'Severance',
          'tmdbId': 93405,
          'mediaType': 'tv',
        },
        isRead: false,
        createdAt: DateTime.now(),
      );

      final text = formatNotificationText(notif);
      expect(text, 'Alex suggested "Severance"');
    });

    test('Like notification displays entry title when available', () {
      final notif = wh.Notification(
        id: 'notif-3',
        userId: 'user-1',
        type: 'LIKE',
        content: {
          'actorName': 'David',
          'entryTitle': 'Inception',
          'entryId': 'entry-abc-123',
        },
        isRead: false,
        createdAt: DateTime.now(),
      );

      final text = formatNotificationText(notif);
      expect(text, 'David liked your entry for "Inception"');
    });

    test('Comment notification displays entry title when available', () {
      final notif = wh.Notification(
        id: 'notif-4',
        userId: 'user-1',
        type: 'COMMENT',
        content: {
          'actorName': 'Emma',
          'title': 'Dune: Part Two',
          'entryId': 'entry-xyz-789',
        },
        isRead: false,
        createdAt: DateTime.now(),
      );

      final text = formatNotificationText(notif);
      expect(text, 'Emma commented on "Dune: Part Two"');
    });
  });

  group('Entry Route Matching Tests', () {
    testWidgets('Router parses /entry/:id and routes to entry screen', (tester) async {
      String capturedId = '';
      final router = GoRouter(
        initialLocation: '/entry/test-entry-999',
        routes: [
          GoRoute(
            path: '/entry/:id',
            builder: (context, state) {
              capturedId = state.pathParameters['id']!;
              return const Scaffold(body: Text('Entry Route Screen'));
            },
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
        ),
      );

      await tester.pump();
      expect(capturedId, 'test-entry-999');
      expect(find.text('Entry Route Screen'), findsOneWidget);
    });

    testWidgets('Router parses /entry/:id?openComments=true', (tester) async {
      bool capturedOpenComments = false;
      String capturedEntryId = '';

      final router = GoRouter(
        initialLocation: '/entry/test-entry-777?openComments=true',
        routes: [
          GoRoute(
            path: '/entry/:id',
            builder: (context, state) {
              capturedEntryId = state.pathParameters['id']!;
              capturedOpenComments = state.uri.queryParameters['openComments'] == 'true';
              return const Scaffold(body: Text('Entry parsed'));
            },
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
        ),
      );

      await tester.pump();
      expect(capturedEntryId, 'test-entry-777');
      expect(capturedOpenComments, isTrue);
      expect(find.text('Entry parsed'), findsOneWidget);
    });
  });
}
