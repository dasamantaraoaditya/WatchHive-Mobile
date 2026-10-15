import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:watchhive_mobile/core/services/offline_storage_service.dart';
import 'package:watchhive_mobile/core/services/offline_sync_manager.dart';
import 'package:watchhive_mobile/features/entries/widgets/wh_entry_grid_card.dart';
import 'package:watchhive_mobile/features/profile/widgets/offline_sync_card.dart';
import 'package:watchhive_mobile/shared/models/entry.dart';
import 'package:watchhive_mobile/shared/widgets/offline_banner.dart';

void main() {
  group('Offline Storage Service Tests', () {
    late OfflineStorageService storage;

    setUp(() {
      storage = OfflineStorageService();
    });

    test('Entry serialization preserves isPendingSync flag', () {
      final now = DateTime.now();
      final entry = Entry(
        id: 'test_1',
        userId: 'user_1',
        tmdbId: 101,
        title: 'Interstellar',
        type: 'MOVIE',
        rating: 9.5,
        watchedAt: now,
        createdAt: now,
        isPendingSync: true,
      );

      final fullJson = entry.toFullJson();
      expect(fullJson['isPendingSync'], isTrue);

      final reconstructed = Entry.fromJson(fullJson);
      expect(reconstructed.id, 'test_1');
      expect(reconstructed.isPendingSync, isTrue);
      expect(reconstructed.rating, 9.5);
    });

    test('Caches and retrieves library entries', () async {
      final now = DateTime.now();
      final entry = Entry(
        id: 'test_entry_1',
        userId: 'u1',
        tmdbId: 200,
        title: 'Inception',
        type: 'MOVIE',
        watchedAt: now,
        createdAt: now,
        isWatching: false,
      );

      await storage.insertOrUpdateCachedEntry(entry);
      final cached = await storage.getCachedEntries();
      expect(cached.length, 1);
      expect(cached.first.title, 'Inception');

      await storage.removeCachedEntry('test_entry_1');
      final afterRemove = await storage.getCachedEntries();
      expect(afterRemove.isEmpty, isTrue);
    });

    test('Queues and dequeues offline sync actions', () async {
      await storage.enqueueSyncAction(
        action: 'CREATE_ENTRY',
        entityId: 'offline_12345',
        payload: {'title': 'Dune', 'rating': 9.0},
      );

      final count = await storage.getPendingCount();
      expect(count, 1);

      final actions = await storage.getPendingSyncActions();
      expect(actions.length, 1);
      expect(actions.first.action, 'CREATE_ENTRY');
      expect(actions.first.entityId, 'offline_12345');
      expect(actions.first.payload['title'], 'Dune');

      await storage.removeSyncAction(actions.first.queueId);
      final remaining = await storage.getPendingCount();
      expect(remaining, 0);
    });

    test('Saves and retrieves media details in memory store', () async {
      await storage.saveMediaDetails(550, 'movie', {
        'id': 550,
        'title': 'Fight Club',
        'poster_path': '/fight_club.jpg',
      });

      final details = await storage.getCachedMediaDetails(550, 'movie');
      expect(details, isNotNull);
      expect(details!['title'], 'Fight Club');
      expect(details['poster_path'], '/fight_club.jpg');
    });

    test('Updates entry posters by tmdbId', () async {
      final now = DateTime.now();
      final entry = Entry(
        id: 'e_100',
        userId: 'u1',
        tmdbId: 550,
        title: 'Fight Club',
        type: 'MOVIE',
        watchedAt: now,
        createdAt: now,
      );
      await storage.insertOrUpdateCachedEntry(entry);

      await storage.updateEntryPostersByTmdbId(550, posterPath: '/poster.jpg', backdropPath: '/backdrop.jpg');
      final updatedList = await storage.getCachedEntries();
      expect(updatedList.first.posterPath, '/poster.jpg');
      expect(updatedList.first.backdropPath, '/backdrop.jpg');
    });

    test('Searches local media across entries and media details', () async {
      final now = DateTime.now();
      await storage.insertOrUpdateCachedEntry(Entry(
        id: 'e_matrix',
        userId: 'u1',
        tmdbId: 603,
        title: 'The Matrix',
        type: 'MOVIE',
        watchedAt: now,
        createdAt: now,
      ));

      final results = await storage.searchLocalMedia('matrix');
      expect(results.isNotEmpty, isTrue);
      expect(results.first['title'], 'The Matrix');
      expect(results.first['id'], 603);
    });
  });

  group('Offline UI Widgets Tests', () {
    testWidgets('OfflineStatusBar renders offline notification when offline',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OfflineStatusBar(
              isOffline: true,
              isSyncing: false,
              isCompleted: false,
              isError: false,
              syncState: const OfflineSyncState(pendingCount: 0),
              onRetrySync: () {},
            ),
          ),
        ),
      );

      expect(find.text('You are offline — viewing cached library & feed'),
          findsOneWidget);
      expect(find.byIcon(Icons.cloud_off_rounded), findsOneWidget);
    });

    testWidgets(
        'OfflineStatusBar renders pending changes count when offline with items',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OfflineStatusBar(
              isOffline: true,
              isSyncing: false,
              isCompleted: false,
              isError: false,
              syncState: const OfflineSyncState(pendingCount: 3),
              onRetrySync: () {},
            ),
          ),
        ),
      );

      expect(find.text('You are offline (3 changes queued to sync)'),
          findsOneWidget);
    });

    testWidgets('OfflineStatusBar renders syncing progress state',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OfflineStatusBar(
              isOffline: false,
              isSyncing: true,
              isCompleted: false,
              isError: false,
              syncState: const OfflineSyncState(
                status: SyncStatus.syncing,
                message: 'Syncing 2 offline changes...',
              ),
              onRetrySync: () {},
            ),
          ),
        ),
      );

      expect(find.text('Syncing 2 offline changes...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('OfflineStatusBar renders sync completed state',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OfflineStatusBar(
              isOffline: false,
              isSyncing: false,
              isCompleted: true,
              isError: false,
              syncState: const OfflineSyncState(
                status: SyncStatus.completed,
                message: 'All changes synced to your Hive! 🐝',
              ),
              onRetrySync: () {},
            ),
          ),
        ),
      );

      expect(
          find.text('All changes synced to your Hive! 🐝'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    });

    testWidgets('OfflineStatusBar renders retry button on error',
        (tester) async {
      bool retryPressed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OfflineStatusBar(
              isOffline: false,
              isSyncing: false,
              isCompleted: false,
              isError: true,
              syncState: const OfflineSyncState(
                status: SyncStatus.error,
                pendingCount: 1,
                message: 'Failed to connect to server',
              ),
              onRetrySync: () => retryPressed = true,
            ),
          ),
        ),
      );

      expect(find.text('Failed to connect to server'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      expect(retryPressed, isTrue);
    });

    testWidgets(
        'WHEntryGridCard displays Pending Sync badge when isPendingSync is true',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 200,
                height: 320,
                child: WHEntryGridCard(
                  tmdbId: 0,
                  title: 'Fight Club',
                  mediaType: 'movie',
                  mode: WHEntryCardMode.history,
                  isPendingSync: true,
                  onTap: () {},
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.text('Pending Sync'), findsOneWidget);
    });

    testWidgets('OfflineSyncCard displays connection state and sync action',
        (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: OfflineSyncCard(),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Offline & Local Storage'), findsOneWidget);
      expect(find.text('Sync Now'), findsOneWidget);
      expect(find.text('Refresh'), findsOneWidget);
    });
  });
}
