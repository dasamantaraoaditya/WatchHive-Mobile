import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/connectivity_service.dart';
import '../../core/services/offline_sync_manager.dart';

/// Wraps the root Navigator to display a smooth, non-intrusive status bar
/// whenever the user is offline, syncing changes, or when sync completes.
class OfflineBannerWrapper extends ConsumerWidget {
  final Widget child;

  const OfflineBannerWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectivity = ref.watch(connectivityServiceProvider);
    final syncState = ref.watch(offlineSyncManagerProvider);

    final isOffline = !connectivity.isOnline;
    final isSyncing = connectivity.isOnline && syncState.status == SyncStatus.syncing;
    final isCompleted = connectivity.isOnline && syncState.status == SyncStatus.completed;
    final isError = connectivity.isOnline &&
        syncState.status == SyncStatus.error &&
        syncState.pendingCount > 0;

    final shouldShowBanner = isOffline || isSyncing || isCompleted || isError;

    if (!shouldShowBanner) {
      return child;
    }

    Color bannerBgColor;
    if (isOffline) {
      bannerBgColor = const Color(0xFFB45309); // Warm dark amber
    } else if (isSyncing) {
      bannerBgColor = const Color(0xFF1D4ED8); // Bright royal blue
    } else if (isCompleted) {
      bannerBgColor = const Color(0xFF047857); // Emerald green
    } else {
      bannerBgColor = const Color(0xFFB91C1C); // Crimson error
    }

    return Column(
      children: [
        Container(
          color: bannerBgColor,
          width: double.infinity,
          child: SafeArea(
            bottom: false,
            child: OfflineStatusBar(
              isOffline: isOffline,
              isSyncing: isSyncing,
              isCompleted: isCompleted,
              isError: isError,
              syncState: syncState,
              onRetrySync: () =>
                  ref.read(offlineSyncManagerProvider.notifier).syncPending(),
            ),
          ),
        ),
        Expanded(
          child: MediaQuery.removePadding(
            context: context,
            removeTop: true,
            child: child,
          ),
        ),
      ],
    );
  }
}

class OfflineStatusBar extends StatelessWidget {
  final bool isOffline;
  final bool isSyncing;
  final bool isCompleted;
  final bool isError;
  final OfflineSyncState syncState;
  final VoidCallback onRetrySync;

  const OfflineStatusBar({
    super.key,
    required this.isOffline,
    required this.isSyncing,
    required this.isCompleted,
    required this.isError,
    required this.syncState,
    required this.onRetrySync,
  });

  @override
  Widget build(BuildContext context) {
    Widget leadingIcon;
    String message;
    Widget? actionButton;

    if (isOffline) {
      leadingIcon = const Icon(
        Icons.cloud_off_rounded,
        color: Colors.white,
        size: 14,
      );
      final count = syncState.pendingCount;
      if (count > 0) {
        message = 'You are offline ($count change${count > 1 ? 's' : ''} queued to sync)';
      } else {
        message = 'You are offline — viewing cached library & feed';
      }
    } else if (isSyncing) {
      leadingIcon = const SizedBox(
        width: 12,
        height: 12,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      );
      message = syncState.message ?? 'Syncing offline changes...';
    } else if (isCompleted) {
      leadingIcon = const Icon(
        Icons.check_circle_rounded,
        color: Colors.white,
        size: 14,
      );
      message = syncState.message ?? 'All changes synced to your Hive! 🐝';
    } else {
      leadingIcon = const Icon(
        Icons.warning_amber_rounded,
        color: Colors.white,
        size: 14,
      );
      message = syncState.message ?? '${syncState.pendingCount} change(s) failed to sync';
      actionButton = GestureDetector(
        onTap: onRetrySync,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Text(
            'Retry',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      );
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Row(
        children: [
          leadingIcon,
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (actionButton != null) ...[
            const SizedBox(width: 8),
            actionButton,
          ],
        ],
      ),
    );
  }
}
