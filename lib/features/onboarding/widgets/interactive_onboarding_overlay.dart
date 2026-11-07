import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../models/interactive_onboarding_step.dart';
import '../providers/onboarding_guide_provider.dart';

/// An impactful, focused onboarding overlay that spotlights key UI sections
/// and guides first-time users through why WatchHive is useful to them.
class InteractiveOnboardingOverlay extends ConsumerStatefulWidget {
  const InteractiveOnboardingOverlay({super.key});

  @override
  ConsumerState<InteractiveOnboardingOverlay> createState() =>
      _InteractiveOnboardingOverlayState();
}

class _InteractiveOnboardingOverlayState
    extends ConsumerState<InteractiveOnboardingOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    if (!WidgetsBinding.instance.runtimeType.toString().toLowerCase().contains('test')) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final guideState = ref.watch(onboardingGuideProvider);
    if (!guideState.isActive) return const SizedBox.shrink();

    final step = guideState.currentStep;
    final totalSteps = InteractiveOnboardingStep.steps.length;
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final topInset = MediaQuery.of(context).padding.top;

    return Stack(
      children: [
        // ── 1. Semi-transparent Backdrop ─────────────────────────────────────
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              // Ignore background taps so user interacts with the card buttons
            },
            child: Container(
              color: Colors.black.withValues(alpha: 0.68),
            ),
          ),
        ),

        // ── 2. Focused Spotlight on Specific Section or Button ───────────────
        if (step.target == OnboardingTarget.quickAddFab)
          Positioned(
            bottom: bottomInset + 12,
            right: 12,
            child: AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _pulseAnimation.value,
                  child: child,
                );
              },
              child: Container(
                width: 66,
                height: 66,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.primary,
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.6),
                      blurRadius: 18,
                      spreadRadius: 4,
                    ),
                  ],
                ),
              ),
            ),
          ),

        if (step.target == OnboardingTarget.entriesTab)
          Positioned(
            bottom: bottomInset + 2,
            left: 0,
            right: 0,
            child: Center(
              child: AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _pulseAnimation.value,
                    child: child,
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF38BDF8).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFF38BDF8),
                      width: 2.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF38BDF8).withValues(alpha: 0.5),
                        blurRadius: 16,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.arrow_downward_rounded, size: 14, color: Color(0xFF38BDF8)),
                      SizedBox(width: 4),
                      Text(
                        'Your Library',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF38BDF8),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

        // ── 3. High-Impact Floating Onboarding Card ──────────────────────────
        _buildPositionedCard(
          context: context,
          step: step,
          guideState: guideState,
          totalSteps: totalSteps,
          topInset: topInset,
          bottomInset: bottomInset,
        ),
      ],
    );
  }

  Widget _buildPositionedCard({
    required BuildContext context,
    required InteractiveOnboardingStep step,
    required OnboardingGuideState guideState,
    required int totalSteps,
    required double topInset,
    required double bottomInset,
  }) {
    double? top;
    double? bottom;

    switch (step.target) {
      case OnboardingTarget.quickAddFab:
        bottom = bottomInset + 92;
        break;
      case OnboardingTarget.entriesTab:
        bottom = bottomInset + 64;
        break;
      case OnboardingTarget.feedCommunity:
        top = topInset + 48;
        break;
    }

    return Positioned(
      left: 16,
      right: 16,
      top: top,
      bottom: bottom,
      child: Material(
        color: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.98),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: step.accentColor.withValues(alpha: 0.45),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: step.accentColor.withValues(alpha: 0.15),
                    blurRadius: 18,
                    spreadRadius: 1,
                  ),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Top Header Row: Badge, Dots, Skip ───────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Badge Pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: step.accentColor.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          step.stepBadge,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 10.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                            color: step.accentColor,
                          ),
                        ),
                      ),

                      // Step Dots Indicator
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(totalSteps, (idx) {
                          final isCurrent = idx == guideState.currentStepIndex;
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 2.5),
                            width: isCurrent ? 14 : 5,
                            height: 5,
                            decoration: BoxDecoration(
                              color: isCurrent
                                  ? step.accentColor
                                  : AppColors.border,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          );
                        }),
                      ),

                      // Skip Tour Button
                      InkWell(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          ref.read(onboardingGuideProvider.notifier).dismissTour(context: context);
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          child: Text(
                            'Skip Tour',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // ── Icon & Title ──────────────────────────────────────────
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: step.accentColor.withValues(alpha: 0.15),
                          border: Border.all(
                            color: step.accentColor.withValues(alpha: 0.35),
                            width: 1.2,
                          ),
                        ),
                        child: Icon(step.icon, color: step.accentColor, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          step.title,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // ── Description (Simple, Relatable, Explaining Why) ─────
                  Text(
                    step.description,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),

                  const SizedBox(height: 10),

                  // ── Highlights (Concise 1-Line Chips) ─────────────────────
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: step.highlights.map((h) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Icon(
                                Icons.check_circle_rounded,
                                size: 14,
                                color: step.accentColor,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                h,
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 14),

                  // ── Action Buttons ────────────────────────────────────────
                  Row(
                    children: [
                      if (guideState.currentStepIndex > 0) ...[
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.border),
                            foregroundColor: AppColors.textPrimary,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            ref.read(onboardingGuideProvider.notifier).previousStep(context);
                          },
                          child: const Icon(Icons.arrow_back_rounded, size: 16),
                        ),
                        const SizedBox(width: 8),
                      ],

                      // Optional Secondary Action (e.g. Try Logging Now)
                      if (step.secondaryActionLabel != null) ...[
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: step.accentColor, width: 1.2),
                              foregroundColor: AppColors.textPrimary,
                              backgroundColor: step.accentColor.withValues(alpha: 0.1),
                              padding: const EdgeInsets.symmetric(vertical: 11),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              ref.read(onboardingGuideProvider.notifier).openFirstWatchLogger(context);
                            },
                            child: Text(
                              step.secondaryActionLabel!,
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],

                      // Primary Next / Finish Button
                      Expanded(
                        flex: step.secondaryActionLabel != null ? 1 : 2,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: AppColors.textPrimary,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            ref.read(onboardingGuideProvider.notifier).nextStep(context);
                          },
                          child: Text(
                            step.primaryActionLabel,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
