import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

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
  });

  static const List<InteractiveOnboardingStep> steps = [
    // 1. Community Feed
    InteractiveOnboardingStep(
      stepIndex: 0,
      stepBadge: 'STEP 1 OF 8 · COMMUNITY FEED',
      title: 'Your Hive Community & Feed',
      description:
          'Welcome to WatchersHive! This is where you see what friends and movie lovers are watching right now. Spot watch location badges (Netflix, Prime, Cinema), like, and leave comments.',
      route: '/feed',
      icon: Icons.dynamic_feed_rounded,
      accentColor: AppColors.primary,
      highlights: [
        'Live community reviews and ratings',
        'Watch location chips (Netflix, Prime, Theater)',
        'Quick Suggest icon on cards to recommend in 1 tap',
      ],
      primaryActionLabel: 'Next: Log First Movie →',
    ),

    // 2. First Watch Entry
    InteractiveOnboardingStep(
      stepIndex: 1,
      stepBadge: 'STEP 2 OF 8 · FIRST WATCH ENTRY',
      title: 'Record What You Have Watched',
      description:
          'Start building your personal cinema diary! Search any movie or show you have watched, rate it on a 1–10 scale, pick where you watched it, and jot down an authentic review.',
      route: '/feed',
      icon: Icons.add_circle_outline_rounded,
      accentColor: Color(0xFFF59E0B),
      highlights: [
        'Instant TMDB search across millions of titles',
        '1–10 ratings, reviews, rewatch tags & platforms',
        'Logs appear on your profile and friends\' feeds',
      ],
      primaryActionLabel: 'Next: Quick Add Shortcut →',
      secondaryActionLabel: 'Log a Movie Now 🎬',
    ),

    // 3. Quick Add FAB
    InteractiveOnboardingStep(
      stepIndex: 2,
      stepBadge: 'STEP 3 OF 8 · QUICK SHORTCUT',
      title: 'The Quick Add Button (+)',
      description:
          'Notice the floating yellow (+) button? It is your fast lane! Tap it anytime from any screen to log what you are currently watching or record a new entry in seconds.',
      route: '/feed',
      icon: Icons.bolt_rounded,
      accentColor: Color(0xFFFFB700),
      highlights: [
        'Always accessible across all main tabs',
        'One-tap "Currently Watching" status updates',
        'Fastest way to capture a watch moment',
      ],
      primaryActionLabel: 'Next: Explore Entries & Vault →',
    ),

    // 4. Entries Vault (Watching, History, Watchlist)
    InteractiveOnboardingStep(
      stepIndex: 3,
      stepBadge: 'STEP 4 OF 8 · ENTRIES & VAULT',
      title: 'Your Personal Viewing Vault',
      description:
          'Your entire viewing life organized in tabs: Currently Watching, History, and Watchlist. Easily filter by movies, TV series, or genres to keep your backlog clean.',
      route: '/entries',
      icon: Icons.video_library_rounded,
      accentColor: Color(0xFF38BDF8),
      highlights: [
        'Active "Currently Watching" trackers',
        'Comprehensive logged watch history',
        'Curated watchlist with instant status moves',
      ],
      primaryActionLabel: 'Next: Friend Suggestions →',
    ),

    // 5. Friend Suggestions Tab
    InteractiveOnboardingStep(
      stepIndex: 4,
      stepBadge: 'STEP 5 OF 8 · FRIEND SUGGESTIONS',
      title: 'Movie Suggestions from Friends',
      description:
          'Whenever friends recommend titles to you, they land right here in the Suggestions tab! See who suggested it, their personal notes, and timestamps.',
      route: '/entries?tab=suggestions',
      icon: Icons.auto_awesome_rounded,
      accentColor: Color(0xFFA855F7),
      highlights: [
        'Personal notes and recommendation hype',
        'Read-only details of whom it was suggested to and when',
        'Suggest titles back from any feed card or details page',
      ],
      primaryActionLabel: 'Next: Rankings & Stacks →',
    ),

    // 6. Rankings & Stacks
    InteractiveOnboardingStep(
      stepIndex: 5,
      stepBadge: 'STEP 6 OF 8 · RANKINGS & STACKS',
      title: 'Curate Rankings & Theme Stacks',
      description:
          'Go beyond simple star ratings! Build your personal Top 10 lists, organize custom Stacks (e.g., "Best Sci-Fi of the 2020s" or "Rainy Day Movies"), and see community consensus.',
      route: '/entries?tab=rankings',
      icon: Icons.leaderboard_rounded,
      accentColor: Color(0xFF10B981),
      highlights: [
        'Personal Top 10 rankings and Tier lists',
        'Curated thematic Stacks to share with the Hive',
        'Community leaderboards and taste consensus',
      ],
      primaryActionLabel: 'Next: Data Migration & Privacy →',
    ),

    // 7. Profile & Data Migration (Letterboxd/IMDb CSV)
    InteractiveOnboardingStep(
      stepIndex: 6,
      stepBadge: 'STEP 7 OF 8 · DATA MIGRATION & PRIVACY',
      title: 'Migrate History & Set Privacy',
      description:
          'Already tracking on Letterboxd or IMDb? Bring your entire watch history over in seconds using our Data Management CSV import tool! You also have full control over your privacy tiers.',
      route: '/profile',
      icon: Icons.import_export_rounded,
      accentColor: Color(0xFFEC4899),
      highlights: [
        '1-Click CSV import from Letterboxd & IMDb',
        'Export your data anytime (JSON/CSV)',
        'Privacy controls: Public, Mutual Followers, or Private',
      ],
      primaryActionLabel: 'Next: Discover Friends & Search →',
    ),

    // 8. Search & Friends
    InteractiveOnboardingStep(
      stepIndex: 7,
      stepBadge: 'STEP 8 OF 8 · DISCOVER & CONNECT',
      title: 'Find Friends & Explore Titles',
      description:
          'Search for friends by @username, scan profile QR codes, and explore trending cinema. Follow friends to unlock Movie Suggestions and Compare Taste!',
      route: '/search',
      icon: Icons.person_search_rounded,
      accentColor: AppColors.primary,
      highlights: [
        'Search users by name or @username',
        'Instant Hive QR code scanner & profile sharing',
        'Follow friends to compare taste overlap',
      ],
      primaryActionLabel: 'Finish & Enter Hive 🐝',
    ),
  ];
}
