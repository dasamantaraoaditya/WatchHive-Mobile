import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/connectivity_service.dart';
import '../../../core/services/offline_sync_manager.dart';
import '../../../core/services/offline_storage_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/wh_alert.dart';
import '../../entries/screens/entries_screen.dart';

class OfflineSyncCard extends ConsumerWidget {
  const OfflineSyncCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectivity = ref.watch(connectivityServiceProvider);
    final syncState = ref.watch(offlineSyncManagerProvider);
    final isOnline = connectivity.isOnline;
    final isSyncing = syncState.status == SyncStatus.syncing;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isOnline
                      ? AppColors.primary.withValues(alpha: 0.15)
                      : const Color(0xFFFEF3C7),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isOnline ? Icons.cloud_sync_rounded : Icons.cloud_off_rounded,
                  size: 20,
                  color: isOnline ? AppColors.primaryDark : const Color(0xFFB45309),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Offline & Local Storage',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Local cache & offline sync management',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Connection status pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surfaceHighest,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isOnline ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isOnline
                        ? 'Connected (${connectivity.connectionType})'
                        : 'Device is Offline',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isOnline ? AppColors.textPrimary : const Color(0xFFB45309),
                    ),
                  ),
                ),
                Text(
                  isOnline ? 'Online' : 'Offline Mode',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isOnline ? const Color(0xFF059669) : const Color(0xFFD97706),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Pending changes box
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: syncState.pendingCount > 0
                  ? const Color(0xFFFFFBEB)
                  : AppColors.surfaceHighest,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: syncState.pendingCount > 0
                    ? const Color(0xFFFDE68A)
                    : AppColors.border,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      syncState.pendingCount > 0
                          ? Icons.hourglass_top_rounded
                          : Icons.check_circle_rounded,
                      size: 16,
                      color: syncState.pendingCount > 0
                          ? const Color(0xFFD97706)
                          : const Color(0xFF10B981),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        syncState.pendingCount > 0
                            ? '${syncState.pendingCount} change${syncState.pendingCount > 1 ? 's' : ''} queued to sync'
                            : 'All changes in sync with cloud',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  syncState.pendingCount > 0
                      ? 'Entries or edits made while offline will automatically sync once your connection is active.'
                      : 'Your library and feed entries are safely stored on device for offline access.',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11.5,
                    color: AppColors.textSecondary,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),

          // Error alert banner if sync failed
          if (syncState.status == SyncStatus.error && syncState.message != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.error_outline_rounded, size: 18, color: Color(0xFFDC2626)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          syncState.message!,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF991B1B),
                          ),
                        ),
                        const SizedBox(height: 6),
                        GestureDetector(
                          onTap: () => _showQueueSheet(context, ref),
                          child: const Text(
                            'Inspect or discard pending changes →',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFDC2626),
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),

          // Action row
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: isSyncing
                      ? null
                      : () async {
                          if (!isOnline) {
                            WHAlert.showWarning(
                              context,
                              'Cannot sync while offline. Please connect to WiFi or cellular network.',
                            );
                            return;
                          }
                          await ref
                              .read(offlineSyncManagerProvider.notifier)
                              .syncPending();
                          if (context.mounted && syncState.status != SyncStatus.error) {
                            WHAlert.showSuccess(
                              context,
                              'Sync complete! Your local library is up to date.',
                            );
                          }
                        },
                  icon: isSyncing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : const Icon(Icons.sync_rounded, size: 18),
                  label: Text(
                    isSyncing ? 'Syncing...' : 'Sync Now',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              if (syncState.pendingCount > 0) ...[
                const SizedBox(width: 8),
                IconButton.outlined(
                  tooltip: 'Inspect Queue',
                  style: IconButton.styleFrom(
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () => _showQueueSheet(context, ref),
                  icon: const Icon(Icons.list_alt_rounded, size: 18, color: AppColors.textPrimary),
                ),
              ],
              const SizedBox(width: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  side: const BorderSide(color: AppColors.border),
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () {
                  ref.invalidate(entriesProvider(true));
                  ref.invalidate(entriesProvider(false));
                  WHAlert.showInfo(context, 'Local cache refreshed!');
                },
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text(
                  'Refresh',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showQueueSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _OfflineQueueSheet(ref: ref),
    );
  }
}

class _OfflineQueueSheet extends StatefulWidget {
  final WidgetRef ref;
  const _OfflineQueueSheet({required this.ref});

  @override
  State<_OfflineQueueSheet> createState() => _OfflineQueueSheetState();
}

class _OfflineQueueSheetState extends State<_OfflineQueueSheet> {
  List<SyncQueueItem> _items = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    final storage = widget.ref.read(offlineStorageServiceProvider);
    final items = await storage.getPendingSyncActions();
    if (mounted) {
      setState(() {
        _items = items;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text(
                'Pending Sync Queue',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              if (_items.any((it) => it.lastError != null))
                TextButton(
                  onPressed: () async {
                    await widget.ref.read(offlineSyncManagerProvider.notifier).discardAllFailed();
                    await _loadItems();
                  },
                  child: const Text('Discard Failed', style: TextStyle(color: Color(0xFFDC2626), fontSize: 12)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text('No pending offline actions! 🎉', style: TextStyle(color: AppColors.textMuted)),
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                itemCount: _items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (ctx, idx) {
                  final item = _items[idx];
                  final title = item.payload['title']?.toString() ?? item.entityId;
                  final actionLabel = switch (item.action) {
                    'CREATE_ENTRY' => 'Log Watch',
                    'UPDATE_ENTRY' => 'Update Watch',
                    'DELETE_ENTRY' => 'Delete Watch',
                    'ADD_WATCHLIST_ITEM' => 'Add to Watchlist',
                    'REMOVE_WATCHLIST_ITEM' => 'Remove from Watchlist',
                    _ => item.action,
                  };

                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: item.lastError != null ? const Color(0xFFFEF2F2) : AppColors.surfaceHighest,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: item.lastError != null ? const Color(0xFFFECACA) : AppColors.border,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                actionLabel,
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: item.lastError != null ? const Color(0xFFDC2626) : AppColors.primary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                title,
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              if (item.lastError != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  item.lastError!,
                                  style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 11,
                                    color: Color(0xFFB91C1C),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 20),
                          tooltip: 'Discard change',
                          onPressed: () async {
                            await widget.ref.read(offlineSyncManagerProvider.notifier).discardAction(item.queueId);
                            await _loadItems();
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

