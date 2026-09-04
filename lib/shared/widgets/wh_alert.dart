import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/error_handler.dart';

enum WHAlertSeverity {
  primary,
  success,
  warning,
  danger,
  info,
}

class WHAlert {
  /// Displays a modern, branded confirmation dialog matching the Web app design.
  static Future<bool> confirm(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
    WHAlertSeverity severity = WHAlertSeverity.primary,
    IconData? icon,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.55),
      builder: (ctx) => _WHConfirmDialog(
        title: title,
        message: message,
        confirmText: confirmText,
        cancelText: cancelText,
        severity: severity,
        customIcon: icon,
        isConfirm: true,
      ),
    );

    return result ?? false;
  }

  /// Displays an informative popup dialog with a single confirm CTA.
  static Future<void> alert(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = 'Got it',
    WHAlertSeverity severity = WHAlertSeverity.primary,
    IconData? icon,
  }) async {
    await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.55),
      builder: (ctx) => _WHConfirmDialog(
        title: title,
        message: message,
        confirmText: confirmText,
        cancelText: '',
        severity: severity,
        customIcon: icon,
        isConfirm: false,
      ),
    );
  }

  /// Displays a mobile-friendly, floating Toast alert banner.
  static void showSuccess(BuildContext context, String message) {
    _showFloatingToast(
      context,
      message: message,
      severity: WHAlertSeverity.success,
      icon: Icons.check_circle_rounded,
    );
  }

  static void showError(BuildContext context, dynamic messageOrError) {
    final cleanMessage = AppErrorHandler.toUserFriendlyMessage(messageOrError);
    _showFloatingToast(
      context,
      message: cleanMessage,
      severity: WHAlertSeverity.danger,
      icon: Icons.error_outline_rounded,
    );
  }

  static void showWarning(BuildContext context, String message) {
    _showFloatingToast(
      context,
      message: message,
      severity: WHAlertSeverity.warning,
      icon: Icons.warning_amber_rounded,
    );
  }

  static void showInfo(BuildContext context, String message) {
    _showFloatingToast(
      context,
      message: message,
      severity: WHAlertSeverity.info,
      icon: Icons.info_outline_rounded,
    );
  }

  static void showPrimary(BuildContext context, String message) {
    _showFloatingToast(
      context,
      message: message,
      severity: WHAlertSeverity.primary,
      icon: Icons.auto_awesome_rounded,
    );
  }

  static void _showFloatingToast(
    BuildContext context, {
    required String message,
    required WHAlertSeverity severity,
    required IconData icon,
  }) {
    final (iconColor, bgColor, textColor, borderColor) = switch (severity) {
      WHAlertSeverity.success => (
          const Color(0xFF10B981),
          const Color(0xFFF0FDF4),
          const Color(0xFF065F46),
          const Color(0xFF86EFAC).withOpacity(0.5),
        ),
      WHAlertSeverity.danger => (
          const Color(0xFFEF4444),
          const Color(0xFFFEF2F2),
          const Color(0xFF991B1B),
          const Color(0xFFFCA5A5).withOpacity(0.5),
        ),
      WHAlertSeverity.warning => (
          const Color(0xFFF59E0B),
          const Color(0xFFFFFBEB),
          const Color(0xFF92400E),
          const Color(0xFFFDE68A).withOpacity(0.5),
        ),
      WHAlertSeverity.info => (
          const Color(0xFF3B82F6),
          const Color(0xFFEFF6FF),
          const Color(0xFF1E40AF),
          const Color(0xFF93C5FD).withOpacity(0.5),
        ),
      WHAlertSeverity.primary => (
          AppColors.primaryDark,
          const Color(0xFFFFF9EE),
          AppColors.textPrimary,
          AppColors.primary.withOpacity(0.3),
        ),
    };

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        elevation: 6,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        backgroundColor: bgColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: borderColor, width: 1.2),
        ),
        duration: const Duration(milliseconds: 3200),
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WHConfirmDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmText;
  final String cancelText;
  final WHAlertSeverity severity;
  final IconData? customIcon;
  final bool isConfirm;

  const _WHConfirmDialog({
    required this.title,
    required this.message,
    required this.confirmText,
    required this.cancelText,
    required this.severity,
    this.customIcon,
    required this.isConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final (icon, iconBg, iconColor, btnBg, btnText) = switch (severity) {
      WHAlertSeverity.success => (
          customIcon ?? Icons.check_circle_outline_rounded,
          const Color(0xFFD1FAE5),
          const Color(0xFF10B981),
          const Color(0xFF10B981),
          Colors.white,
        ),
      WHAlertSeverity.danger => (
          customIcon ?? Icons.delete_outline_rounded,
          const Color(0xFFFEE2E2),
          const Color(0xFFEF4444),
          const Color(0xFFEF4444),
          Colors.white,
        ),
      WHAlertSeverity.warning => (
          customIcon ?? Icons.warning_amber_rounded,
          const Color(0xFFFEF3C7),
          const Color(0xFFF59E0B),
          AppColors.primary,
          Colors.black,
        ),
      WHAlertSeverity.info => (
          customIcon ?? Icons.info_outline_rounded,
          const Color(0xFFDBEAFE),
          const Color(0xFF3B82F6),
          const Color(0xFF3B82F6),
          Colors.white,
        ),
      WHAlertSeverity.primary => (
          customIcon ?? Icons.auto_awesome_rounded,
          AppColors.primary.withOpacity(0.15),
          AppColors.primaryDark,
          AppColors.primary,
          Colors.black,
        ),
    };

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon Pill
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(icon, color: iconColor, size: 30),
            ),
            const SizedBox(height: 18),

            // Title
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 8),

            // Message
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 24),

            // Action Buttons
            Row(
              children: [
                if (isConfirm) ...[
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        side: const BorderSide(color: AppColors.border, width: 1.5),
                        backgroundColor: AppColors.background,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () => Navigator.pop(context, false),
                      child: Text(
                        cancelText,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: btnBg,
                      foregroundColor: btnText,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(
                      confirmText,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
