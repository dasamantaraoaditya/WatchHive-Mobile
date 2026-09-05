import 'package:flutter/material.dart';

class TourStep {
  final int stepIndex;
  final String badgeText;
  final String title;
  final String description;
  final List<String> highlights;
  final IconData icon;
  final Color accentColor;
  final String? actionLabel;
  final String? actionRoute;

  const TourStep({
    required this.stepIndex,
    required this.badgeText,
    required this.title,
    required this.description,
    required this.highlights,
    required this.icon,
    required this.accentColor,
    this.actionLabel,
    this.actionRoute,
  });

  static const List<TourStep> defaultSteps = [
    TourStep(
      stepIndex: 1,
      badgeText: 'WELCOME ABOARD',
      title: 'Your Ultimate Movie & TV Sanctuary',
      description:
          'Welcome to WatchHive! Track everything you watch across movies, anime, K-dramas, and series. Discover what is buzzing and share your love of cinema.',
      highlights: [
        'Track all media types in one unified place',
        'Follow friends and discover their authentic ratings',
        'Build your personalized cinema hive',
      ],
      icon: Icons.hive_rounded,
      accentColor: Color(0xFFFFB700),
    ),
    TourStep(
      stepIndex: 2,
      badgeText: 'COMMUNITY & BUZZ',
      title: 'See What the World is Watching',
      description:
          'Explore live reviews, ratings, and watch moments from fellow cinephiles. Discover where others watched their movies with location tags.',
      highlights: [
        'Live Community Feed with instant reactions',
        'Watch location chips (📍 Netflix, 📍 Cinema, 📍 Home)',
        'Like, comment, and discuss reviews with friends',
      ],
      icon: Icons.dynamic_feed_rounded,
      accentColor: Color(0xFFF59E0B),
      actionLabel: 'Explore Feed',
      actionRoute: '/feed',
    ),
    TourStep(
      stepIndex: 3,
      badgeText: 'AI INTELLIGENCE',
      title: 'MindLens AI Companion',
      description:
          'Meet your cinematic brain. Ask MindLens for personalized recommendations, unpack complex plot twists, and uncover hidden thematic symbolism.',
      highlights: [
        'Tailored movie and series recommendations',
        'Deep theme breakdown & ending explanations',
        'Interactive AI chat powered for cinephiles',
      ],
      icon: Icons.psychology_rounded,
      accentColor: Color(0xFF6366F1),
      actionLabel: 'Try MindLens AI',
      actionRoute: '/mindlens',
    ),
    TourStep(
      stepIndex: 4,
      badgeText: 'ORGANIZATION',
      title: 'Entries, Watchlists & History',
      description:
          'Easily categorize your entire entertainment journey. Jump between what you are currently watching, your future watchlist, and past history.',
      highlights: [
        'Separate tabs for Watching, Watchlist, & History',
        'Filter by Movies, TV, Anime, and K-Drama',
        'Record watch dates and personal locations',
      ],
      icon: Icons.movie_creation_rounded,
      accentColor: Color(0xFF10B981),
      actionLabel: 'View Entries',
      actionRoute: '/entries',
    ),
    TourStep(
      stepIndex: 5,
      badgeText: 'CINEMATIC IDENTITY',
      title: 'Level Up Your Soul Persona',
      description:
          'Every log and review earns you XP! Unlock unique Soul Personas like The Collector, The Critic, or The Binge-Watcher, and show off your achievements.',
      highlights: [
        'Gain XP and level up with every watch logged',
        'Dynamic Soul Persona reflecting your taste',
        'Export and backup your Hive data anytime',
      ],
      icon: Icons.auto_awesome_rounded,
      accentColor: Color(0xFFEC4899),
      actionLabel: 'View Profile',
      actionRoute: '/profile',
    ),
    TourStep(
      stepIndex: 6,
      badgeText: 'LOG ANYWHERE',
      title: 'Quick Add in Seconds (+)',
      description:
          'Look for the golden "+" button floating in the bottom right. Tap it anytime from any screen to log what you are watching or save to your watchlist in seconds!',
      highlights: [
        'Always accessible floating action button',
        'Quickly log Currently Watching with one tap',
        'Rate, review, and tag watch locations on the fly',
      ],
      icon: Icons.add_circle_rounded,
      accentColor: Color(0xFFFFB700),
    ),
  ];
}
