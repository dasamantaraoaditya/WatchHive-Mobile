import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/connectivity_service.dart';
import '../../../core/services/offline_sync_manager.dart';
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
                          if (context.mounted) {
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
              const SizedBox(width: 10),
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
}
