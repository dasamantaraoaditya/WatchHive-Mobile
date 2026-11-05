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
        final cleanPayload = _cleanPayload(item.payload);

        switch (item.action) {
          case 'CREATE_ENTRY':
            // If logged offline with title only (tmdbId == 0), auto-resolve via TMDB now that we're online
            if ((cleanPayload['tmdbId'] == null || cleanPayload['tmdbId'] == 0) && cleanPayload['title'] != null) {
              try {
                final searchRes = await _api.get(
                  ApiEndpoints.tmdbSearch,
                  queryParameters: {'query': cleanPayload['title'].toString().trim()},
                );
                final list = (searchRes.data['results'] as List<dynamic>?) ?? [];
                if (list.isNotEmpty) {
                  final first = list.first as Map<String, dynamic>;
                  cleanPayload['tmdbId'] = (first['id'] as num?)?.toInt() ?? 0;
                  final mediaType = first['media_type']?.toString().toUpperCase();
                  if (mediaType == 'TV') {
                    cleanPayload['type'] = 'TV_SHOW';
                  } else if (mediaType == 'MOVIE') {
                    cleanPayload['type'] = 'MOVIE';
                  }
                  if (first['poster_path'] != null) {
                    cleanPayload['posterPath'] = first['poster_path'];
                  }
                  if (first['backdrop_path'] != null) {
                    cleanPayload['backdropPath'] = first['backdrop_path'];
                  }
                }
              } catch (lookupErr) {
                debugPrint('[OfflineSyncManager] Could not auto-resolve TMDb ID: $lookupErr');
              }
            }

            final response = await _api.post(
              ApiEndpoints.entries,
              data: cleanPayload,
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
              data: cleanPayload,
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

          case 'ADD_WATCHLIST_ITEM':
            final listId = item.payload['listId'] as String?;
            String? actualListId = (listId != null && listId != 'cached_watchlist') ? listId : null;
            if (actualListId == null) {
              final wlRes = await _api.get(ApiEndpoints.lists);
              final lists = (wlRes.data['lists'] ?? wlRes.data) as List<dynamic>;
              final wl = lists.firstWhere(
                (l) => l['type'] == 'WATCHLIST',
                orElse: () => null,
              );
              if (wl != null) actualListId = wl['id'] as String;
            }
            if (actualListId != null) {
              await _api.post(ApiEndpoints.listItems(actualListId), data: cleanPayload);
            }
            await _storage.removeSyncAction(item.queueId);
            successCount++;
            break;

          case 'REMOVE_WATCHLIST_ITEM':
            final listId = item.payload['listId'] as String?;
            String? actualListId = (listId != null && listId != 'cached_watchlist') ? listId : null;
            if (actualListId == null) {
              final wlRes = await _api.get(ApiEndpoints.lists);
              final lists = (wlRes.data['lists'] ?? wlRes.data) as List<dynamic>;
              final wl = lists.firstWhere(
                (l) => l['type'] == 'WATCHLIST',
                orElse: () => null,
              );
              if (wl != null) actualListId = wl['id'] as String;
            }
            final itemId = item.payload['itemId']?.toString() ?? item.entityId;
            if (actualListId != null && itemId.isNotEmpty) {
              await _api.delete('${ApiEndpoints.listItems(actualListId)}/$itemId');
            }
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

  Map<String, dynamic> _cleanPayload(Map<String, dynamic> raw) {
    final clean = Map<String, dynamic>.from(raw);
    clean.removeWhere((k, v) => v == null || (v is String && v.trim().isEmpty));
    if (clean.containsKey('rating') && (clean['rating'] == null || clean['rating'] == 0)) {
      clean.remove('rating');
    }
    clean.remove('isPendingSync');
    clean.remove('id');
    return clean;
  }

  Future<void> discardAction(String queueId) async {
    await _storage.removeSyncAction(queueId);
    await refreshPendingCount();
    final items = await _storage.getPendingSyncActions();
    if (items.isEmpty) {
      state = state.copyWith(status: SyncStatus.idle, message: null, pendingCount: 0);
    }
  }

  Future<void> discardAllFailed() async {
    final items = await _storage.getPendingSyncActions();
    for (final item in items) {
      if (item.lastError != null) {
        await _storage.removeSyncAction(item.queueId);
      }
    }
    await refreshPendingCount();
    final remaining = await _storage.getPendingCount();
    state = state.copyWith(
      status: remaining == 0 ? SyncStatus.idle : state.status,
      message: remaining == 0 ? null : state.message,
      pendingCount: remaining,
    );
  }
}

