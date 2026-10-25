import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/api/api_endpoints.dart';

/// Interactive modal dialog displaying a magnified, zoomable view of a user's profile picture.
class AvatarViewerDialog extends StatelessWidget {
  final String? imageUrl;
  final String name;
  final String? username;
  final VoidCallback? onRemoveAvatar;

  const AvatarViewerDialog({
    super.key,
    required this.imageUrl,
    required this.name,
    this.username,
    this.onRemoveAvatar,
  });

  static void show(
    BuildContext context, {
    required String? imageUrl,
    required String name,
    String? username,
    VoidCallback? onRemoveAvatar,
  }) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      barrierDismissible: true,
      builder: (context) => AvatarViewerDialog(
        imageUrl: imageUrl,
        name: name,
        username: username,
        onRemoveAvatar: onRemoveAvatar,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final resolvedUrl = ApiEndpoints.resolveAvatarUrl(imageUrl);
    final size = MediaQuery.of(context).size;
    final maxDimension = (size.width * 0.85).clamp(220.0, 340.0);

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background dismiss tap
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            behavior: HitTestBehavior.opaque,
            child: const SizedBox.expand(),
          ),

          // Dialog Card
          Container(
            width: maxDimension + 32,
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.45),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                // Top bar: Name/Handle + Close Button
                Row(
                  children: [
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (username != null && username!.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              '@$username',
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primaryDark,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: AppColors.textPrimary, size: 22),
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(context).pop(),
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.surfaceHighest,
                        shape: const CircleBorder(),
                        padding: const EdgeInsets.all(8),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Magnified Picture with InteractiveViewer (pinch to zoom)
                Container(
                  width: maxDimension,
                  height: maxDimension,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primary, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.25),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: InteractiveViewer(
                      clipBehavior: Clip.none,
                      minScale: 1.0,
                      maxScale: 3.5,
                      child: resolvedUrl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: resolvedUrl,
                              fit: BoxFit.cover,
                              width: maxDimension,
                              height: maxDimension,
                              placeholder: (context, url) => Container(
                                color: AppColors.surfaceHighest,
                                child: const Center(
                                  child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2.5),
                                ),
                              ),
                              errorWidget: (context, url, error) => _buildFallback(maxDimension),
                            )
                          : _buildFallback(maxDimension),
                    ),
                  ),
                ),

                const SizedBox(height: 16),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.pinch_outlined, size: 14, color: AppColors.textMuted),
                    SizedBox(width: 6),
                    Text(
                      'Pinch to zoom',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
                if (onRemoveAvatar != null && imageUrl != null && imageUrl!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: BorderSide(color: AppColors.error.withValues(alpha: 0.4)),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () {
                      Navigator.of(context).pop();
                      onRemoveAvatar!();
                    },
                    icon: const Icon(Icons.delete_outline_rounded, size: 16, color: AppColors.error),
                    label: const Text(
                      'Remove Profile Photo',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        ],
      ),
    );
  }

  Widget _buildFallback(double size) {
    final initial = (name.isNotEmpty ? name[0] : '?').toUpperCase();
    return Container(
      width: size,
      height: size,
      color: AppColors.surfaceHighest,
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: size * 0.4,
            fontWeight: FontWeight.w900,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }
}
