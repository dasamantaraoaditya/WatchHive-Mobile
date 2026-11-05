import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../models/interactive_onboarding_step.dart';
import '../providers/onboarding_guide_provider.dart';

/// An interactive, non-blocking guided overlay that floats above the content in [AppShell],
/// actively showing users where key features live as they navigate across tabs.
class InteractiveOnboardingOverlay extends ConsumerWidget {
  const InteractiveOnboardingOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final guideState = ref.watch(onboardingGuideProvider);
    if (!guideState.isActive) return const SizedBox.shrink();

    final step = guideState.currentStep;
    final totalSteps = InteractiveOnboardingStep.steps.length;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Positioned(
      left: 14,
      right: 14,
      bottom: bottomInset + 8,
      child: Material(
        color: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: step.accentColor.withValues(alpha: 0.45),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.45),
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
                  // ── Top Navigation Row: Step Badge + Skip ────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Badge Pill
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: step.accentColor.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            step.stepBadge,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.6,
                              color: step.accentColor,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Skip Tour Button
                      InkWell(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          ref.read(onboardingGuideProvider.notifier).dismissTour(context: context);
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          child: Text(
                            'Skip Tour',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // ── Progress Bar ──────────────────────────────────────────
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: (guideState.currentStepIndex + 1) / totalSteps,
                      minHeight: 3,
                      backgroundColor: AppColors.border.withValues(alpha: 0.4),
                      valueColor: AlwaysStoppedAnimation<Color>(step.accentColor),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ── Header: Icon + Title ──────────────────────────────────
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
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
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // ── Description ───────────────────────────────────────────
                  Text(
                    step.description,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12.5,
                      color: AppColors.textSecondary,
                      height: 1.35,
                    ),
                  ),

                  const SizedBox(height: 10),

                  // ── Bullet Highlights ─────────────────────────────────────
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: step.highlights.map((h) {
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle_rounded, size: 12, color: step.accentColor),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              h,
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
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

                      // Optional Secondary Action (e.g. "Log a Movie Now 🎬")
                      if (step.secondaryActionLabel != null) ...[
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: step.accentColor),
                              foregroundColor: step.accentColor,
                              padding: const EdgeInsets.symmetric(vertical: 10),
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
                            backgroundColor: step.accentColor,
                            foregroundColor: Colors.black,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 11),
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
                              fontSize: 12.5,
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
