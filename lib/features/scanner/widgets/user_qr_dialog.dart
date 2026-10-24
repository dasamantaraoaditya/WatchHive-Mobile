import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/config/web_urls.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/models/user.dart';
import '../../../shared/widgets/shared_widgets.dart';

/// Interactive modal displaying a user's unique WatchersHive QR Code (Hive Code).
/// Allows other users to scan and instantly follow or send follow requests.
class UserQrDialog extends StatelessWidget {
  final String userId;
  final String name;
  final String? username;
  final String? profilePictureUrl;
  final bool isMe;

  const UserQrDialog({
    super.key,
    required this.userId,
    required this.name,
    this.username,
    this.profilePictureUrl,
    this.isMe = false,
  });

  static void show(
    BuildContext context, {
    required String userId,
    required String name,
    String? username,
    String? profilePictureUrl,
    bool isMe = false,
  }) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      barrierDismissible: true,
      builder: (context) => UserQrDialog(
        userId: userId,
        name: name,
        username: username,
        profilePictureUrl: profilePictureUrl,
        isMe: isMe,
      ),
    );
  }

  static void showForUser(BuildContext context, User user, {bool isMe = false}) {
    show(
      context,
      userId: user.id,
      name: user.displayName ?? user.username,
      username: user.username,
      profilePictureUrl: user.profilePictureUrl,
      isMe: isMe,
    );
  }

  String get _profileUrl => WebUrls.userProfile(userId, refUsername: username);

  void _copyLink(BuildContext context) {
    Clipboard.setData(ClipboardData(text: _profileUrl));
    HapticFeedback.lightImpact();
    WHAlert.showSuccess(context, 'Profile link copied to clipboard! 📋');
  }

  void _shareProfile() {
    final handle = username != null && username!.isNotEmpty ? '@$username' : name;
    Share.share(
      'Connect with $handle on WatchersHive! 🐝 Track movies, anime & series together:\n\n$_profileUrl',
      subject: 'WatchersHive: $name',
    );
  }

  @override
  Widget build(BuildContext context) {
    final cleanHandle = username != null && username!.isNotEmpty ? '@$username' : '';

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 380),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.08),
                blurRadius: 36,
                spreadRadius: 2,
              ),
            ],
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
              // Header with title and close button
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 12, 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.qr_code_2_rounded,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        isMe ? 'My Hive Code' : 'Hive Code',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: AppColors.textMuted, size: 22),
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              const Divider(color: AppColors.border, height: 1),

              // Main content: User Avatar, Name, and QR Card
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
                  child: Column(
                    children: [
                      // Avatar and user identity
                      WHAvatar(
                        imageUrl: profilePictureUrl,
                        name: name,
                        radius: 32,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        name,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (cleanHandle.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          cleanHandle,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],

                      const SizedBox(height: 20),

                      // QR Code Card (High Contrast White Container for Flawless Camera Scanning)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            QrImageView(
                              data: _profileUrl,
                              version: QrVersions.auto,
                              size: 200,
                              backgroundColor: Colors.white,
                              eyeStyle: const QrEyeStyle(
                                eyeShape: QrEyeShape.square,
                                color: Color(0xFF141419),
                              ),
                              dataModuleStyle: const QrDataModuleStyle(
                                dataModuleShape: QrDataModuleShape.square,
                                color: Color(0xFF141419),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: const BoxDecoration(
                                    color: AppColors.primary,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.bolt_rounded,
                                    size: 11,
                                    color: Colors.black,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Text(
                                  'WatchersHive',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF2D2926),
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 18),

                      Text(
                        isMe
                            ? 'Friends can scan this code with any camera or the WatchersHive scanner to connect & follow you instantly.'
                            : 'Scan this code on another device to view and connect with $name on WatchersHive.',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textMuted,
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 20),

                      // Primary Action Buttons
                      Row(
                        children: [
                          // Copy Link
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.textPrimary,
                                side: const BorderSide(color: AppColors.border),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              onPressed: () => _copyLink(context),
                              icon: const Icon(Icons.copy_rounded, size: 16),
                              label: const Text(
                                'Copy Link',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          // Share
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                elevation: 0,
                              ),
                              onPressed: _shareProfile,
                              icon: const Icon(Icons.share_rounded, size: 16),
                              label: const Text(
                                'Share Code',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // Quick Toggle to Open Camera Scanner
                      SizedBox(
                        width: double.infinity,
                        child: TextButton.icon(
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.textSecondary,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          onPressed: () {
                            Navigator.of(context).pop();
                            context.push('/scanner');
                          },
                          icon: const Icon(Icons.qr_code_scanner_rounded, size: 18, color: AppColors.primary),
                          label: const Text(
                            'Scan Someone Else\'s Code',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}
