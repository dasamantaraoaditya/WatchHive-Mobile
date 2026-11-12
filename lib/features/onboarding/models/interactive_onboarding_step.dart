import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// Target section or element to spotlight during onboarding.
enum OnboardingTarget {
  homeTab,
  quickAddFab,
  logWatchFlow,
  entriesTab,
  searchTab,
  profileTab,
}

/// Represents a sub-step inside the interactive "Log a Watch" visual walkthrough.
class WatchLogSubStep {
  final String number;
  final String title;
  final String subtitle;

  const WatchLogSubStep({
    required this.number,
    required this.title,
    required this.subtitle,
  });
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
  final List<WatchLogSubStep> subSteps;
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
    this.accentColor = AppColors.primary,
    this.highlights = const [],
    this.subSteps = const [],
    required this.primaryActionLabel,
    this.secondaryActionLabel,
    this.target = OnboardingTarget.homeTab,
  });

  static const List<InteractiveOnboardingStep> steps = [
    // 1. The Hive Feed (Home Tab)
    InteractiveOnboardingStep(
      stepIndex: 0,
      stepBadge: 'STEP 1 OF 6 · THE HIVE FEED',
      title: 'See Your Social Cinema Feed',
      description:
          'Your Home tab is where you see what your friends are watching, rating, and reviewing in real time—plus personalized SmartSuggest picks.',
      route: '/feed',
      icon: Icons.home_rounded,
      accentColor: AppColors.primary,
      highlights: [
        'Follow friends\' latest ratings, reviews & watch activity',
        'Swipe through SmartSuggest recommendations tailored to you',
      ],
      primaryActionLabel: 'Next: Quick Add (+) →',
      target: OnboardingTarget.homeTab,
    ),

    // 2. Quick Add (+) Floating Button
    InteractiveOnboardingStep(
      stepIndex: 1,
      stepBadge: 'STEP 2 OF 6 · QUICK ADD',
      title: 'Tap (+) to Log Any Watch',
      description:
          'Spot the golden (+) Quick Add button at the bottom right on any screen. Tap it and choose "Log an Entry" to record what you watched.',
      route: '/feed',
      icon: Icons.add_circle_rounded,
      accentColor: AppColors.primary,
      highlights: [
        'Tap (+) → "Log an Entry" for movies, TV shows & anime',
        'Also add Currently Watching, Suggest to Friends, or Watchlist',
      ],
      primaryActionLabel: 'Next: Log a Watch Flow →',
      target: OnboardingTarget.quickAddFab,
    ),

    // 3. Complete Log a Watch Flow (5 clear sub-steps + Try It Live)
    InteractiveOnboardingStep(
      stepIndex: 2,
      stepBadge: 'STEP 3 OF 6 · LOG A WATCH',
      title: 'How to Log a Watch',
      description:
          'Logging takes seconds. Follow these 5 steps whenever you finish or start watching something:',
      route: '/feed',
      icon: Icons.edit_note_rounded,
      accentColor: AppColors.primary,
      subSteps: [
        WatchLogSubStep(
          number: '1',
          title: 'Click "Log an Entry"',
          subtitle: 'Open from the (+) Quick Add menu',
        ),
        WatchLogSubStep(
          number: '2',
          title: 'Choose Completed or Currently Watching',
          subtitle: 'Pick whether you finished it or are in progress',
        ),
        WatchLogSubStep(
          number: '3',
          title: 'Select the Movie or Show',
          subtitle: 'Search by title to attach artwork & details',
        ),
        WatchLogSubStep(
          number: '4',
          title: 'Rate (0.5–10 Stars) & Review',
          subtitle: 'Add your Honey Star rating and optional review',
        ),
        WatchLogSubStep(
          number: '5',
          title: 'Tap "Log a Watch"',
          subtitle: 'Save to your diary & share with your circle',
        ),
      ],
      primaryActionLabel: 'Next: Your Entries →',
      secondaryActionLabel: 'Try Logging Now',
      target: OnboardingTarget.logWatchFlow,
    ),

    // 4. Entries & Watchlist (Entries Tab)
    InteractiveOnboardingStep(
      stepIndex: 3,
      stepBadge: 'STEP 4 OF 6 · YOUR ENTRIES',
      title: 'Check All Your Entries',
      description:
          'Open the Entries tab to browse every movie, show, and anime you have logged, track Currently Watching progress, and manage your Watchlist.',
      route: '/entries',
      icon: Icons.movie_creation_rounded,
      accentColor: AppColors.primary,
      highlights: [
        'View your complete Watched History & ratings',
        'Switch between Currently Watching, Watchlist & Watched',
      ],
      primaryActionLabel: 'Next: Search Friends →',
      target: OnboardingTarget.entriesTab,
    ),

    // 5. Search Friends & Media (Search Tab)
    InteractiveOnboardingStep(
      stepIndex: 4,
      stepBadge: 'STEP 5 OF 6 · SEARCH FRIENDS',
      title: 'Search Friends & Titles',
      description:
          'Use the Search tab to find friends by name or username to follow their watch activity, or search any movie, TV series, or anime.',
      route: '/search',
      icon: Icons.search_rounded,
      accentColor: AppColors.primary,
      highlights: [
        'Find & follow friends to build your social circle',
        'Search any title to check streaming availability & details',
      ],
      primaryActionLabel: 'Next: Manage Profile →',
      target: OnboardingTarget.searchTab,
    ),

    // 6. Profile & Settings (Profile Tab)
    InteractiveOnboardingStep(
      stepIndex: 5,
      stepBadge: 'STEP 6 OF 6 · YOUR PROFILE',
      title: 'Manage Your Profile Details',
      description:
          'Visit your Profile tab to update your bio and avatar, control who sees your activity, inspect viewing stats, and unlock Honey Badges.',
      route: '/profile',
      icon: Icons.person_rounded,
      accentColor: AppColors.primary,
      highlights: [
        'Edit display name, username, bio & profile photo',
        'Manage privacy controls, stats & Honey Badges',
      ],
      primaryActionLabel: 'Get Started!',
      target: OnboardingTarget.profileTab,
    ),
  ];
}
