import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import '../api/api_endpoints.dart';
import '../utils/error_handler.dart';
import '../../shared/models/entry.dart';
import 'connectivity_service.dart';
import 'offline_storage_service.dart';

enum SyncStatus { idle, syncing, completed, error }

class OfflineSyncState {
  final SyncStatus status;
  final int pendingCount;
  final int syncedCount;
  final String? message;
  final DateTime? lastSyncedAt;

  const OfflineSyncState({
    this.status = SyncStatus.idle,
    this.pendingCount = 0,
    this.syncedCount = 0,
    this.message,
    this.lastSyncedAt,
  });

  OfflineSyncState copyWith({
    SyncStatus? status,
    int? pendingCount,
    int? syncedCount,
    String? message,
    DateTime? lastSyncedAt,
  }) =>
      OfflineSyncState(
        status: status ?? this.status,
        pendingCount: pendingCount ?? this.pendingCount,
        syncedCount: syncedCount ?? this.syncedCount,
        message: message,
        lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      );
}

final offlineSyncManagerProvider =
    StateNotifierProvider<OfflineSyncManager, OfflineSyncState>((ref) {
  final storage = ref.read(offlineStorageServiceProvider);
  final api = ref.read(apiClientProvider);
  final connectivity = ref.read(connectivityServiceProvider.notifier);

  final manager = OfflineSyncManager(storage, api, connectivity);

  // Auto-sync when connectivity is restored
  connectivity.onReconnected = () {
    debugPrint('[OfflineSyncManager] Device came back online! Triggering auto-sync...');
    manager.syncPending();
  };

  return manager;
});

class OfflineSyncManager extends StateNotifier<OfflineSyncState> {
  final OfflineStorageService _storage;
  final ApiClient _api;
  final ConnectivityNotifier _connectivity;
  bool _isSyncing = false;

  OfflineSyncManager(this._storage, this._api, this._connectivity)
      : super(const OfflineSyncState()) {
    refreshPendingCount();
  }

  Future<void> refreshPendingCount() async {
    final count = await _storage.getPendingCount();
    state = state.copyWith(pendingCount: count);
  }

  /// Process all pending offline sync actions
  Future<void> syncPending({
    Function(Entry syncedEntry, String temporaryId)? onEntrySynced,
  }) async {
    if (_isSyncing) return;

    final isOnline = await _connectivity.checkConnection();
    if (!isOnline) {
      state = state.copyWith(
        status: SyncStatus.error,
        message: 'Cannot sync while offline. Please check your connection.',
      );
      return;
    }

    final items = await _storage.getPendingSyncActions();
    if (items.isEmpty) {
      state = state.copyWith(
        status: SyncStatus.idle,
        pendingCount: 0,
        message: null,
      );
      return;
    }

    _isSyncing = true;
    state = state.copyWith(
      status: SyncStatus.syncing,
      pendingCount: items.length,
      syncedCount: 0,
      message: 'Syncing ${items.length} offline changes...',
    );

    int successCount = 0;
    String? lastError;

    for (final item in items) {
      try {
        switch (item.action) {
          case 'CREATE_ENTRY':
            final response = await _api.post(
              ApiEndpoints.entries,
              data: item.payload,
            );
            final data = response.data as Map<String, dynamic>;
            final createdJson = (data['entry'] ?? data) as Map<String, dynamic>;
            final realEntry = Entry.fromJson(createdJson);

            // Replace temporary entry in cache with real backend entry
            await _storage.removeCachedEntry(item.entityId);
            await _storage.insertOrUpdateCachedEntry(realEntry);
            await _storage.removeSyncAction(item.queueId);

            onEntrySynced?.call(realEntry, item.entityId);
            successCount++;
            break;

          case 'UPDATE_ENTRY':
            final response = await _api.put(
              ApiEndpoints.entry(item.entityId),
              data: item.payload,
            );
            final data = response.data as Map<String, dynamic>;
            final updatedJson = (data['entry'] ?? data) as Map<String, dynamic>;
            final updatedEntry = Entry.fromJson(updatedJson);

            await _storage.insertOrUpdateCachedEntry(updatedEntry);
            await _storage.removeSyncAction(item.queueId);
            successCount++;
            break;

          case 'DELETE_ENTRY':
            await _api.delete(ApiEndpoints.entry(item.entityId));
            await _storage.removeCachedEntry(item.entityId);
            await _storage.removeSyncAction(item.queueId);
            successCount++;
            break;

          default:
            await _storage.removeSyncAction(item.queueId);
        }
      } catch (e) {
        lastError = AppErrorHandler.toUserFriendlyMessage(e);
        debugPrint('[OfflineSyncManager] Error syncing ${item.action} (${item.queueId}): $e');
        await _storage.updateSyncActionError(item.queueId, lastError);
      }
    }

    _isSyncing = false;
    final remainingCount = await _storage.getPendingCount();

    if (remainingCount == 0) {
      state = state.copyWith(
        status: SyncStatus.completed,
        pendingCount: 0,
        syncedCount: successCount,
        message: 'All offline changes synced! 🐝✨',
        lastSyncedAt: DateTime.now(),
      );
      // Reset back to idle after a moment
      Future.delayed(const Duration(seconds: 4), () {
        if (state.status == SyncStatus.completed) {
          state = state.copyWith(status: SyncStatus.idle, message: null);
        }
      });
    } else {
      state = state.copyWith(
        status: SyncStatus.error,
        pendingCount: remainingCount,
        syncedCount: successCount,
        message: lastError ?? '$remainingCount item(s) could not be synced. Will retry.',
      );
    }
  }
}
