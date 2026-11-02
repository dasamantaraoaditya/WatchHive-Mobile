import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/theme/app_colors.dart';

/// An interactive panel shown in the Feed when a user has 0 friends,
/// encouraging them to add friends to diversify their feed and suggestions.
///
/// Features a clear "Add Friends" action and can be dismissed/cancelled by the user.
class FeedAddFriendsCard extends StatelessWidget {
  final VoidCallback onAddFriends;
  final VoidCallback onDismiss;

  static const String _storagePrefix = 'wh_dismissed_feed_add_friends_banner_';

  static FlutterSecureStorage _getStorage() => const FlutterSecureStorage(
        aOptions: AndroidOptions(encryptedSharedPreferences: true),
        iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
      );

  /// Check whether the user has previously dismissed this card.
  static Future<bool> isDismissed(String userId, [FlutterSecureStorage? storage]) async {
    if (userId.trim().isEmpty) return false;
    try {
      final s = storage ?? _getStorage();
      final val = await s.read(key: '$_storagePrefix${userId.trim()}');
      return val == 'true';
    } catch (_) {
      return false;
    }
  }

  /// Mark the card as dismissed for this user.
  static Future<void> setDismissed(String userId, [FlutterSecureStorage? storage]) async {
    if (userId.trim().isEmpty) return;
    try {
      final s = storage ?? _getStorage();
      await s.write(key: '$_storagePrefix${userId.trim()}', value: 'true');
    } catch (_) {}
  }

  /// Reset the dismissed state (useful for tests or user settings).
  static Future<void> resetDismissed(String userId, [FlutterSecureStorage? storage]) async {
    if (userId.trim().isEmpty) return;
    try {
      final s = storage ?? _getStorage();
      await s.delete(key: '$_storagePrefix${userId.trim()}');
    } catch (_) {}
  }

  const FeedAddFriendsCard({
    super.key,
    required this.onAddFriends,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Icon + Title + Close Button
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.group_add_rounded,
                  color: AppColors.primaryDark,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Diversify Your Feed & Suggestions',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                splashRadius: 18,
                icon: const Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: AppColors.textMuted,
                ),
                tooltip: 'Dismiss',
                onPressed: () {
                  HapticFeedback.selectionClick();
                  onDismiss();
                },
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Message Body
          const Text(
            'You haven’t added any friends yet! Connect with friends to see what your swarm is watching, share movie picks, and discover diverse suggestions tailored to your taste.',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),

          // Actions Row: "Add Friends" Primary + "Cancel" Secondary
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  onAddFriends();
                },
                icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
                label: const Text(
                  'Add Friends',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.black,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () {
                  HapticFeedback.selectionClick();
                  onDismiss();
                },
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textMuted,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                child: const Text(
                  'Cancel',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
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
