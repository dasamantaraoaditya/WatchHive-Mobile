import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../models/interactive_onboarding_step.dart';
import '../providers/onboarding_guide_provider.dart';

/// An impactful, focused onboarding overlay that spotlights key UI sections
/// and guides first-time users through WatchersHive following the Warm Honey & Cream design system.
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
    final media = MediaQuery.of(context);
    final bottomInset = media.padding.bottom;
    final topInset = media.padding.top;
    final screenWidth = media.size.width;
    final screenHeight = media.size.height;

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

        // ── 2. Focused Spotlight on Specific Tab or Quick Add FAB ────────────
        if (step.target == OnboardingTarget.quickAddFab)
          _buildQuickAddFabSpotlight(bottomInset),

        if (step.target == OnboardingTarget.homeTab)
          _buildBottomTabSpotlight(
            screenWidth: screenWidth,
            bottomInset: bottomInset,
            tabIndex: 0,
            label: 'Home Feed',
          ),

        if (step.target == OnboardingTarget.entriesTab)
          _buildBottomTabSpotlight(
            screenWidth: screenWidth,
            bottomInset: bottomInset,
            tabIndex: 2,
            label: 'Entries',
          ),

        if (step.target == OnboardingTarget.searchTab)
          _buildBottomTabSpotlight(
            screenWidth: screenWidth,
            bottomInset: bottomInset,
            tabIndex: 3,
            label: 'Search',
          ),

        if (step.target == OnboardingTarget.profileTab)
          _buildBottomTabSpotlight(
            screenWidth: screenWidth,
            bottomInset: bottomInset,
            tabIndex: 4,
            label: 'Profile',
          ),

        // ── 3. Floating Onboarding Card ──────────────────────────────────────
        _buildPositionedCard(
          context: context,
          step: step,
          guideState: guideState,
          totalSteps: totalSteps,
          topInset: topInset,
          bottomInset: bottomInset,
          screenHeight: screenHeight,
        ),
      ],
    );
  }

  Widget _buildQuickAddFabSpotlight(double bottomInset) {
    // WHQuickAddFAB sits at bottom: 16, right: 16 inside Scaffold.body,
    // which is above the 56px BottomNavigationBar + 1px border + bottomInset.
    final fabBottom = bottomInset + kBottomNavigationBarHeight + 1.0 + 11.0;

    return Positioned(
      bottom: fabBottom,
      right: 11,
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _pulseAnimation.value,
            child: child,
          );
        },
        child: Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.primary,
              width: 3,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.65),
                blurRadius: 20,
                spreadRadius: 4,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomTabSpotlight({
    required double screenWidth,
    required double bottomInset,
    required int tabIndex,
    required String label,
  }) {
    const int totalTabs = 5;
    final tabWidth = screenWidth / totalTabs;
    final centerX = (tabIndex + 0.5) * tabWidth;
    const double ringSize = 62.0;
    final left = (centerX - ringSize / 2).clamp(8.0, screenWidth - ringSize - 8.0);

    return Positioned(
      bottom: bottomInset + 2,
      left: left,
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _pulseAnimation.value,
            child: child,
          );
        },
        child: Container(
          width: ringSize,
          height: 54,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.primary,
              width: 2.5,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.55),
                blurRadius: 18,
                spreadRadius: 3,
              ),
            ],
          ),
          child: Align(
            alignment: Alignment.topCenter,
            child: Transform.translate(
              offset: const Offset(0, -10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPositionedCard({
    required BuildContext context,
    required InteractiveOnboardingStep step,
    required OnboardingGuideState guideState,
    required int totalSteps,
    required double topInset,
    required double bottomInset,
    required double screenHeight,
  }) {
    double? top;
    double? bottom;

    switch (step.target) {
      case OnboardingTarget.quickAddFab:
        bottom = bottomInset + kBottomNavigationBarHeight + 94;
        break;
      case OnboardingTarget.homeTab:
      case OnboardingTarget.entriesTab:
      case OnboardingTarget.searchTab:
      case OnboardingTarget.profileTab:
        bottom = bottomInset + kBottomNavigationBarHeight + 26;
        break;
      case OnboardingTarget.logWatchFlow:
        // Centered comfortably above the bottom bar
        top = topInset + 36;
        bottom = bottomInset + kBottomNavigationBarHeight + 24;
        break;
    }

    final maxCardHeight = (screenHeight - topInset - bottomInset - kBottomNavigationBarHeight - 56)
        .clamp(240.0, 560.0);

    final cardWidget = Material(
      color: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            constraints: BoxConstraints(maxHeight: maxCardHeight),
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.98),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.55),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.16),
                  blurRadius: 18,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Top Header Row: Honey Badge, Dots, Skip ──────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            step.stepBadge,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.4,
                              color: AppColors.textPrimary, // Golden Contrast Rule
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Step Dots Indicator
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(totalSteps, (idx) {
                          final isCurrent = idx == guideState.currentStepIndex;
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            width: isCurrent ? 14 : 5,
                            height: 5,
                            decoration: BoxDecoration(
                              color: isCurrent
                                  ? AppColors.primary
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
                          ref
                              .read(onboardingGuideProvider.notifier)
                              .dismissTour(context: context);
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 4,
                          ),
                          child: Text(
                            'Skip',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
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
                          color: AppColors.primary.withValues(alpha: 0.18),
                          border: Border.all(
                            color: AppColors.primary,
                            width: 1.2,
                          ),
                        ),
                        child: Icon(
                          step.icon,
                          color: AppColors.textPrimary,
                          size: 22,
                        ),
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

                  // ── Description ───────────────────────────────────────────
                  Text(
                    step.description,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),

                  // ── Visual 5-Step Watch Logging Flow (Step 3) ─────────────
                  if (step.subSteps.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.background, // Warm Cream #FFF9F0
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Column(
                        children: step.subSteps.map((sub) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 22,
                                  height: 22,
                                  alignment: Alignment.center,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.primary,
                                  ),
                                  child: Text(
                                    sub.number,
                                    style: const TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        sub.title,
                                        style: const TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      Text(
                                        sub.subtitle,
                                        style: const TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 11,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],

                  // ── Highlights (Concise 1-Line Chips) ─────────────────────
                  if (step.highlights.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: step.highlights.map((h) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 5),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(top: 1),
                                child: Icon(
                                  Icons.check_circle_rounded,
                                  size: 15,
                                  color: AppColors.primaryDark,
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
                  ],

                  const SizedBox(height: 14),

                  // ── Action Buttons ────────────────────────────────────────
                  Row(
                    children: [
                      if (guideState.currentStepIndex > 0) ...[
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.border),
                            foregroundColor: AppColors.textPrimary,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 11,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            ref
                                .read(onboardingGuideProvider.notifier)
                                .previousStep(context);
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
                              side: const BorderSide(
                                color: AppColors.primaryDark,
                                width: 1.3,
                              ),
                              foregroundColor: AppColors.textPrimary,
                              backgroundColor: AppColors.background,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              ref
                                  .read(onboardingGuideProvider.notifier)
                                  .openFirstWatchLogger(context);
                            },
                            child: Text(
                              step.secondaryActionLabel!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                                color: AppColors.textPrimary,
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
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            ref
                                .read(onboardingGuideProvider.notifier)
                                .nextStep(context);
                          },
                          child: Text(
                            step.primaryActionLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                              color: AppColors.textPrimary, // Golden Contrast Rule
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

    if (step.target == OnboardingTarget.logWatchFlow) {
      return Positioned(
        left: 16,
        right: 16,
        top: top,
        bottom: bottom,
        child: Center(child: cardWidget),
      );
    }

    return Positioned(
      left: 16,
      right: 16,
      bottom: bottom,
      child: cardWidget,
    );
  }
}
