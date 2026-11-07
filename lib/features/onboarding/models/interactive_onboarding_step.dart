import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// Target section or element to spotlight during onboarding.
enum OnboardingTarget {
  quickAddFab,
  entriesTab,
  feedCommunity,
}

/// Represents an interactive step in the hands-on WatchHive onboarding tour.
class InteractiveOnboardingStep {
  final int stepIndex;
  final String stepBadge;
  final String title;
  final String description;
  final String route;
  final IconData icon;
  final Color accentColor;
  final List<String> highlights;
  final String primaryActionLabel;
  final String? secondaryActionLabel;
  final OnboardingTarget target;

  const InteractiveOnboardingStep({
    required this.stepIndex,
    required this.stepBadge,
    required this.title,
    required this.description,
    required this.route,
    required this.icon,
    required this.accentColor,
    required this.highlights,
    required this.primaryActionLabel,
    this.secondaryActionLabel,
    this.target = OnboardingTarget.feedCommunity,
  });

  static const List<InteractiveOnboardingStep> steps = [
    // 1. Quick Add Button (+) Focus
    InteractiveOnboardingStep(
      stepIndex: 0,
      stepBadge: 'STEP 1 OF 3 · QUICK LOG',
      title: 'Track What You Watch',
      description:
          'Tap the yellow (+) button anytime to log what you are watching, rate it, and build your personal diary across movies, TV shows, anime, and K-dramas.',
      route: '/feed',
      icon: Icons.add_circle_outline_rounded,
      accentColor: AppColors.primary,
      highlights: [
        'Log movies, TV series, anime & K-dramas',
        'Quick 1-tap ratings, watch dates & streaming tags',
      ],
      primaryActionLabel: 'Next: Your Library →',
      secondaryActionLabel: 'Try Logging Now 🎬',
      target: OnboardingTarget.quickAddFab,
    ),

    // 2. Entries & Watchlist Focus
    InteractiveOnboardingStep(
      stepIndex: 1,
      stepBadge: 'STEP 2 OF 3 · ENTRIES & WATCHLIST',
      title: 'Your Watchlist & History',
      description:
          'Never wonder what to watch next. Keep track of current series in progress, save upcoming titles for movie night, and browse your full watched history.',
      route: '/entries',
      icon: Icons.video_library_rounded,
      accentColor: Color(0xFF38BDF8),
      highlights: [
        'Never lose track of what to watch next',
        'Filter easily by Movies, TV, Anime & platform',
      ],
      primaryActionLabel: 'Next: Discover & Share →',
      target: OnboardingTarget.entriesTab,
    ),

    // 3. Discover & Friend Suggestions Focus
    InteractiveOnboardingStep(
      stepIndex: 2,
      stepBadge: 'STEP 3 OF 3 · DISCOVER & CONNECT',
      title: 'Discover & Share',
      description:
          'Find where any title is streaming (Netflix, Prime & more), see what friends are loving, and exchange recommendations with personal notes.',
      route: '/feed',
      icon: Icons.auto_awesome_rounded,
      accentColor: Color(0xFFF59E0B),
      highlights: [
        'Instant streaming availability on every title',
        'Send & receive movie suggestions with friends',
      ],
      primaryActionLabel: 'Personalize My Feed 🚀',
      target: OnboardingTarget.feedCommunity,
    ),
  ];
}
