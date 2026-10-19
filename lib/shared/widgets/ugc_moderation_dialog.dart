import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../features/profile/repositories/user_repository.dart';
import 'wh_alert.dart';
import 'wh_bee_loader.dart';

class UgcModerationDialog {
  /// Displays the Apple App Store Guideline 1.2 compliant Report Modal
  static Future<void> showReportDialog(
    BuildContext context,
    WidgetRef ref, {
    required String targetType,
    required String targetId,
    String? targetTitle,
    VoidCallback? onReported,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ReportModalSheet(
        targetType: targetType,
        targetId: targetId,
        targetTitle: targetTitle,
        onReported: onReported,
      ),
    );
  }

  /// Displays the Apple App Store Guideline 1.2 compliant Block User Dialog
  static Future<void> confirmBlockUser(
    BuildContext context,
    WidgetRef ref, {
    required String userId,
    required String username,
    VoidCallback? onBlocked,
  }) async {
    final cleanName = username.startsWith('@') ? username : '@$username';
    final confirmed = await WHAlert.confirm(
      context,
      title: 'Block $cleanName?',
      message:
          'You will no longer see content, comments, or recommendations from $cleanName. They will also not be able to view your profile or posts.',
      confirmText: 'Block User',
      severity: WHAlertSeverity.danger,
      icon: Icons.block_rounded,
    );

    if (!confirmed || !context.mounted) return;

    try {
      await ref.read(userRepositoryProvider).blockUser(userId);
      if (context.mounted) {
        WHAlert.showSuccess(context, '$cleanName has been blocked.');
        onBlocked?.call();
      }
    } catch (e) {
      if (context.mounted) {
        WHAlert.showError(context, 'Failed to block user. Please try again.');
      }
    }
  }
}

class _ReportModalSheet extends ConsumerStatefulWidget {
  final String targetType;
  final String targetId;
  final String? targetTitle;
  final VoidCallback? onReported;

  const _ReportModalSheet({
    required this.targetType,
    required this.targetId,
    this.targetTitle,
    this.onReported,
  });

  @override
  ConsumerState<_ReportModalSheet> createState() => _ReportModalSheetState();
}

class _ReportModalSheetState extends ConsumerState<_ReportModalSheet> {
  static const List<String> _reportReasons = [
    'Inappropriate or offensive content',
    'Harassment, bullying, or hate speech',
    'Spam, advertising, or scam',
    'Unmarked spoilers or misleading info',
    'Intellectual property violation',
    'Other concern',
  ];

  String _selectedReason = _reportReasons.first;
  final _detailsController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _submitReport() async {
    setState(() => _isSubmitting = true);
    try {
      await ref.read(userRepositoryProvider).submitReport(
            targetType: widget.targetType,
            targetId: widget.targetId,
            reason: _selectedReason,
            details: _detailsController.text.trim().isNotEmpty
                ? _detailsController.text.trim()
                : null,
          );

      if (mounted) {
        Navigator.of(context).pop();
        WHAlert.showSuccess(
          context,
          'Thank you for reporting. Our moderation team will review this within 24 hours.',
        );
        widget.onReported?.call();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        WHAlert.showError(
          context,
          'Failed to submit report. Please check your connection and try again.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: 24 + bottomInset,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header Title
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.flag_rounded, color: AppColors.error, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Report ${widget.targetType.toLowerCase()}',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (widget.targetTitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          widget.targetTitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: AppColors.textMuted),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            const Text(
              'Why are you reporting this?',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),

            // Reasons radio list
            ..._reportReasons.map((reason) {
              final isSelected = _selectedReason == reason;
              return InkWell(
                onTap: () => setState(() => _selectedReason = reason),
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  child: Row(
                    children: [
                      Icon(
                        isSelected
                            ? Icons.radio_button_checked_rounded
                            : Icons.radio_button_off_rounded,
                        color: isSelected ? AppColors.primary : AppColors.textMuted,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          reason,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                            color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 12),

            // Additional details input
            TextField(
              controller: _detailsController,
              maxLines: 2,
              maxLength: 300,
              style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Additional details (optional)...',
                hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                filled: true,
                fillColor: AppColors.background,
                contentPadding: const EdgeInsets.all(12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primary),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Submit Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _isSubmitting ? null : _submitReport,
                child: _isSubmitting
                    ? const WHBeeSpinner(size: 16)
                    : const Text(
                        'Submit Report',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
