import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../models/tour_step.dart';
import '../services/tour_service.dart';

class QuickGuideTourDialog extends ConsumerStatefulWidget {
  final String userId;
  final bool isReplay;
  final VoidCallback? onCompleted;

  const QuickGuideTourDialog({
    super.key,
    required this.userId,
    this.isReplay = false,
    this.onCompleted,
  });

  /// Displays the Quick Guide Tour dialog.
  static Future<void> show(
    BuildContext context, {
    required String userId,
    bool isReplay = false,
    VoidCallback? onCompleted,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: isReplay,
      routeSettings: const RouteSettings(name: 'QuickGuideTourDialog'),
      builder: (dialogContext) => QuickGuideTourDialog(
        userId: userId,
        isReplay: isReplay,
        onCompleted: onCompleted,
      ),
    );
  }

  @override
  ConsumerState<QuickGuideTourDialog> createState() =>
      _QuickGuideTourDialogState();
}

class _QuickGuideTourDialogState extends ConsumerState<QuickGuideTourDialog> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final List<TourStep> _steps = TourStep.defaultSteps;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _finishTour([String? targetRoute]) async {
    final tourService = ref.read(tourServiceProvider);
    await tourService.markTourCompleted(widget.userId);

    if (mounted) {
      widget.onCompleted?.call();
      Navigator.of(context, rootNavigator: true).pop();

      if (targetRoute != null && targetRoute.isNotEmpty) {
        context.go(targetRoute);
      }
    }
  }

  void _nextPage() {
    if (_currentPage < _steps.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _finishTour();
    }
  }

  void _prevPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLastPage = _currentPage == _steps.length - 1;
    final currentStep = _steps[_currentPage];

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 630),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(50),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
            ],
            border: Border.all(color: AppColors.border, width: 1.2),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: Column(
              children: [
                // Top Navigation Bar
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Step Pill
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: currentStep.accentColor.withAlpha(30),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'STEP ${_currentPage + 1} OF ${_steps.length}',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                            color: currentStep.accentColor == AppColors.primary
                                ? AppColors.primaryDark
                                : currentStep.accentColor,
                          ),
                        ),
                      ),

                      // Animated Dots
                      Row(
                        children: List.generate(_steps.length, (index) {
                          final isActive = index == _currentPage;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            margin: const EdgeInsets.symmetric(horizontal: 2.5),
                            height: 6,
                            width: isActive ? 20 : 6,
                            decoration: BoxDecoration(
                              color: isActive
                                  ? currentStep.accentColor
                                  : AppColors.border,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          );
                        }),
                      ),

                      // Skip Button
                      TextButton(
                        onPressed: () => _finishTour(),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          visualDensity: VisualDensity.compact,
                          foregroundColor: AppColors.textMuted,
                        ),
                        child: Text(
                          isLastPage ? 'Close' : 'Skip',
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const Divider(height: 1, thickness: 1, color: AppColors.border),

                // Carousel Body
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (index) =>
                        setState(() => _currentPage = index),
                    itemCount: _steps.length,
                    itemBuilder: (context, index) {
                      final step = _steps[index];
                      return SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(22, 16, 22, 12),
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Icon Hero Emblem
                            Container(
                              width: 74,
                              height: 74,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [
                                    step.accentColor.withAlpha(45),
                                    step.accentColor.withAlpha(20),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                border: Border.all(
                                  color: step.accentColor.withAlpha(90),
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: step.accentColor.withAlpha(40),
                                    blurRadius: 16,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Icon(
                                step.icon,
                                size: 36,
                                color: step.accentColor == AppColors.primary
                                    ? AppColors.primaryDark
                                    : step.accentColor,
                              ),
                            ),

                            const SizedBox(height: 14),

                            // Badge Category
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 3.5),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceElevated,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppColors.border,
                                  width: 0.8,
                                ),
                              ),
                              child: Text(
                                step.badgeText,
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),

                            const SizedBox(height: 10),

                            // Title
                            Text(
                              step.title,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 18.5,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                                height: 1.25,
                              ),
                            ),

                            const SizedBox(height: 8),

                            // Description
                            Text(
                              step.description,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 13,
                                color: AppColors.textSecondary,
                                height: 1.45,
                              ),
                            ),

                            const SizedBox(height: 16),

                            // Highlights Box
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: AppColors.background,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                    color: AppColors.border, width: 1),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: step.highlights.map((highlight) {
                                  return Padding(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 4),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          margin:
                                              const EdgeInsets.only(top: 2.5),
                                          width: 16,
                                          height: 16,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: step.accentColor
                                                .withAlpha(40),
                                          ),
                                          child: Icon(
                                            Icons.check_rounded,
                                            size: 11,
                                            color: step.accentColor ==
                                                    AppColors.primary
                                                ? AppColors.primaryDark
                                                : step.accentColor,
                                          ),
                                        ),
                                        const SizedBox(width: 9),
                                        Expanded(
                                          child: Text(
                                            highlight,
                                            style: const TextStyle(
                                              fontFamily: 'Inter',
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.textPrimary,
                                              height: 1.35,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),

                            // Optional Action Route Shortcut
                            if (step.actionLabel != null &&
                                step.actionRoute != null) ...[
                              const SizedBox(height: 12),
                              TextButton.icon(
                                onPressed: () =>
                                    _finishTour(step.actionRoute),
                                style: TextButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                  foregroundColor: step.accentColor ==
                                          AppColors.primary
                                      ? AppColors.primaryDark
                                      : step.accentColor,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                icon: const Icon(Icons.arrow_outward_rounded,
                                    size: 14),
                                label: Text(
                                  'Jump to ${step.actionLabel}',
                                  style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                ),

                const Divider(height: 1, thickness: 1, color: AppColors.border),

                // Footer Navigation Buttons
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 14),
                  child: Row(
                    children: [
                      // Back Button (hidden on first page)
                      if (_currentPage > 0) ...[
                        OutlinedButton(
                          onPressed: _prevPage,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textSecondary,
                            side: const BorderSide(color: AppColors.border),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                          ),
                          child: const Text(
                            'Back',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],

                      // Next / Finish Button
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _nextPage,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: currentStep.accentColor,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                isLastPage
                                    ? 'Explore WatchHive 🚀'
                                    : 'Next Step',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: currentStep.accentColor ==
                                          AppColors.primary
                                      ? Colors.black
                                      : Colors.white,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Icon(
                                isLastPage
                                    ? Icons.check_circle_rounded
                                    : Icons.arrow_forward_rounded,
                                size: 16,
                                color: currentStep.accentColor ==
                                        AppColors.primary
                                    ? Colors.black
                                    : Colors.white,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
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
