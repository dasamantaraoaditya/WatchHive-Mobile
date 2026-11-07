import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../providers/onboarding_guide_provider.dart';

/// Screen types supported by the contextual onboarding guide.
enum ScreenGuideType {
  feed,
  entries,
  search,
  rankings,
  profile,
  movieDetails,
  notifications,
  mindlens,
  scanner,
  userProfile,
  compareHistory,
}

class ScreenGuideItem {
  final IconData icon;
  final String title;
  final String description;

  const ScreenGuideItem({
    required this.icon,
    required this.title,
    required this.description,
  });
}

class ScreenGuideData {
  final String badgeText;
  final IconData icon;
  final String title;
  final String description;
  final List<ScreenGuideItem> highlights;
  final String proTip;

  const ScreenGuideData({
    required this.badgeText,
    required this.icon,
    required this.title,
    required this.description,
    required this.highlights,
    required this.proTip,
  });

  static ScreenGuideData forType(ScreenGuideType type) {
    switch (type) {
      case ScreenGuideType.feed:
        return const ScreenGuideData(
          badgeText: 'COMMUNITY FEED',
          icon: Icons.dynamic_feed_rounded,
          title: 'Hive Community Feed',
          description:
              'See what friends and the community are watching in real time.',
          highlights: [
            ScreenGuideItem(
              icon: Icons.chat_bubble_outline_rounded,
              title: 'Reviews & Watch Moments',
              description:
                  'Authentic ratings and watch tags (Netflix, Prime, Cinema) from friends.',
            ),
            ScreenGuideItem(
              icon: Icons.auto_awesome_rounded,
              title: 'Recommendations & Swaps',
              description:
                  'Get tailored suggestions and send recommendations to friends in 1 tap.',
            ),
          ],
          proTip: 'Tap any movie poster to see where it streams and read reviews.',
        );

      case ScreenGuideType.entries:
        return const ScreenGuideData(
          badgeText: 'ENTRIES & WATCHLIST',
          icon: Icons.movie_filter_rounded,
          title: 'Your Entertainment Sanctuary',
          description:
              'All your movies and shows organized in one simple, clean place.',
          highlights: [
            ScreenGuideItem(
              icon: Icons.play_circle_outline_rounded,
              title: 'Currently Watching',
              description:
                  'Track series and anime in progress so you never lose your place.',
            ),
            ScreenGuideItem(
              icon: Icons.check_circle_outline_rounded,
              title: 'Watched Diary & History',
              description:
                  'Your complete watch log with ratings, dates, and personal notes.',
            ),
            ScreenGuideItem(
              icon: Icons.bookmark_outline_rounded,
              title: 'Watchlist',
              description:
                  'Save upcoming releases and titles for your next movie night.',
            ),
          ],
          proTip: 'Use the category chips on top to filter Movies, TV, Anime, and K-Dramas.',
        );

      case ScreenGuideType.search:
        return const ScreenGuideData(
          badgeText: 'EXPLORE & SEARCH',
          icon: Icons.search_rounded,
          title: 'Discover Movies, Shows & Friends',
          description:
              'Search millions of titles or find friends across WatchersHive.',
          highlights: [
            ScreenGuideItem(
              icon: Icons.movie_creation_outlined,
              title: 'Universal Media Search',
              description:
                  'Search movies, TV shows, and anime by title, actor, or genre.',
            ),
            ScreenGuideItem(
              icon: Icons.group_outlined,
              title: 'Find Friends',
              description:
                  'Search usernames to connect with friends and share watchlists.',
            ),
          ],
          proTip: 'Tap the QR scanner icon to scan a friend’s profile code in person.',
        );

      case ScreenGuideType.rankings:
        return const ScreenGuideData(
          badgeText: 'RANKINGS & STACKS',
          icon: Icons.leaderboard_rounded,
          title: 'Curate Custom Ranked Lists',
          description:
              'Create, organize, and share your personal top movie rankings.',
          highlights: [
            ScreenGuideItem(
              icon: Icons.add_rounded,
              title: 'Create Stacks',
              description:
                  'Tap "+ New Stack" to build Top 10s, franchise lists, or genre tiers.',
            ),
            ScreenGuideItem(
              icon: Icons.drag_indicator_rounded,
              title: 'Drag & Reorder',
              description:
                  'Easily drag titles up and down to build your definitive ranking.',
            ),
          ],
          proTip: 'Publish stacks to your profile to share your favorite lists with friends.',
        );

      case ScreenGuideType.profile:
        return const ScreenGuideData(
          badgeText: 'PROFILE & MILESTONES',
          icon: Icons.person_rounded,
          title: 'Your Cinema Identity & Stats',
          description:
              'Your personal watch milestones, badges, stats, and settings.',
          highlights: [
            ScreenGuideItem(
              icon: Icons.military_tech_rounded,
              title: 'Honey Badges & Stats',
              description:
                  'Track total watches, hours logged, and unlocked level badges.',
            ),
            ScreenGuideItem(
              icon: Icons.qr_code_2_rounded,
              title: 'Hive QR Code',
              description:
                  'Display your QR code for friends nearby to follow you in seconds.',
            ),
          ],
          proTip: 'Tap any Honey Badge to see requirements for the next level!',
        );

      case ScreenGuideType.movieDetails:
        return const ScreenGuideData(
          badgeText: 'TITLE DETAILS',
          icon: Icons.movie_rounded,
          title: 'Streaming, Info & Logging',
          description:
              'Where to stream, cast details, ratings, and 1-tap logging.',
          highlights: [
            ScreenGuideItem(
              icon: Icons.tv_rounded,
              title: 'Where to Watch',
              description:
                  'See verified streaming platforms (Netflix, Prime Video, etc.).',
            ),
            ScreenGuideItem(
              icon: Icons.star_rounded,
              title: 'Log & Rate',
              description:
                  'Record star ratings, review notes, and watch locations.',
            ),
            ScreenGuideItem(
              icon: Icons.send_rounded,
              title: 'Suggest to Friend',
              description:
                  'Send this title directly to any friend with a personal note.',
            ),
          ],
          proTip: 'Tap the bookmark icon to save this title directly to your Watchlist.',
        );

      case ScreenGuideType.notifications:
        return const ScreenGuideData(
          badgeText: 'NOTIFICATIONS HUB',
          icon: Icons.notifications_rounded,
          title: 'Activity & Interactions',
          description:
              'Stay notified on friend suggestions, requests, and comments.',
          highlights: [
            ScreenGuideItem(
              icon: Icons.recommend_rounded,
              title: 'Movie Suggestions',
              description:
                  'Jump straight to titles your friends handpicked for you.',
            ),
            ScreenGuideItem(
              icon: Icons.person_add_rounded,
              title: 'Follow Requests & Likes',
              description:
                  'Manage follow requests and see reactions to your reviews.',
            ),
          ],
          proTip: 'Tap "Mark all read" in the top right to clear unread badges.',
        );

      case ScreenGuideType.mindlens:
        return const ScreenGuideData(
          badgeText: 'MINDLENS AI',
          icon: Icons.psychology_rounded,
          title: 'Your AI Film Companion',
          description:
              'Ask for personalized recommendations or decode complex plots.',
          highlights: [
            ScreenGuideItem(
              icon: Icons.auto_awesome_rounded,
              title: 'Personalized Queries',
              description:
                  'Describe any mood, theme, or premise to uncover matching gems.',
            ),
            ScreenGuideItem(
              icon: Icons.psychology_alt_rounded,
              title: 'Plot & Ending Analysis',
              description:
                  'Unpack confusing plot twists, endings, or hidden symbolism.',
            ),
          ],
          proTip: 'MindLens knows what you logged and won’t suggest titles you’ve seen!',
        );

      case ScreenGuideType.scanner:
        return const ScreenGuideData(
          badgeText: 'HIVE SCANNER',
          icon: Icons.qr_code_scanner_rounded,
          title: 'Instant QR Code Scanner',
          description:
              'Scan QR codes to connect with friends or open titles instantly.',
          highlights: [
            ScreenGuideItem(
              icon: Icons.person_search_rounded,
              title: 'Scan Friend Codes',
              description:
                  'Point camera at a friend’s code to follow them immediately.',
            ),
            ScreenGuideItem(
              icon: Icons.movie_rounded,
              title: 'Scan Movie Codes',
              description:
                  'Scan a title code to open its streaming and details page.',
            ),
          ],
          proTip: 'Center the QR code inside the yellow brackets for instant scanning.',
        );

      case ScreenGuideType.userProfile:
        return const ScreenGuideData(
          badgeText: 'PUBLIC PROFILE',
          icon: Icons.account_circle_rounded,
          title: 'Friend Profile Hub',
          description:
              'Explore their watch journey, reviews, and taste compatibility.',
          highlights: [
            ScreenGuideItem(
              icon: Icons.compare_arrows_rounded,
              title: 'Taste Compatibility',
              description:
                  'Tap "Compare History" to see your shared watch match score.',
            ),
            ScreenGuideItem(
              icon: Icons.send_rounded,
              title: 'Suggest a Film',
              description:
                  'Send a movie or series recommendation directly to their inbox.',
            ),
          ],
          proTip: 'Tap any movie in their history to add it straight to your Watchlist!',
        );

      case ScreenGuideType.compareHistory:
        return const ScreenGuideData(
          badgeText: 'TASTE COMPARISON',
          icon: Icons.compare_arrows_rounded,
          title: 'Viewing Taste Compatibility',
          description:
              'Compare watch history with a friend to find what to watch together.',
          highlights: [
            ScreenGuideItem(
              icon: Icons.percent_rounded,
              title: 'Compatibility Match',
              description:
                  'Calculated based on overlapping watches and rating alignment.',
            ),
            ScreenGuideItem(
              icon: Icons.done_all_rounded,
              title: 'Both Watched',
              description:
                  'Browse every title both of you have logged side by side.',
            ),
          ],
          proTip: 'Use shared recommendations to pick your next movie to watch together!',
        );
    }
  }
}

/// A clean, simple, lightweight contextual guide dialog explaining screen features.
class ScreenGuideDialog extends ConsumerWidget {
  final ScreenGuideType type;
  final String? userId;

  const ScreenGuideDialog({
    super.key,
    required this.type,
    this.userId,
  });

  /// Displays the contextual Screen Guide Dialog for the given screen type.
  static Future<void> show(
    BuildContext context,
    ScreenGuideType type, {
    String? userId,
  }) {
    HapticFeedback.lightImpact();
    return showDialog<void>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      routeSettings: RouteSettings(name: 'ScreenGuideDialog_${type.name}'),
      builder: (dialogContext) => ScreenGuideDialog(type: type, userId: userId),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ScreenGuideData.forType(type);

    return Dialog(
      backgroundColor: AppColors.surface,
      elevation: 6,
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: AppColors.border, width: 1.2),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 380,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header Row: Badge & Close ────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border, width: 0.8),
                    ),
                    child: Text(
                      data.badgeText,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                        color: AppColors.primaryDark,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppColors.textMuted, size: 20),
                    tooltip: 'Close',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // ── Scrollable Body ──────────────────────────────────────────
              Flexible(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Title & Icon ─────────────────────────────────────
                      Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.primary.withValues(alpha: 0.16),
                              border: Border.all(
                                color: AppColors.primary.withValues(alpha: 0.4),
                                width: 1.5,
                              ),
                            ),
                            child: Icon(
                              data.icon,
                              size: 20,
                              color: AppColors.primaryDark,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  data.title,
                                  style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.textPrimary,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  data.description,
                                  style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // ── Highlights List (2-3 concise items) ──────────────
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceHighest.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border, width: 0.8),
                        ),
                        child: Column(
                          children: List.generate(data.highlights.length, (index) {
                            final item = data.highlights[index];
                            final isLast = index == data.highlights.length - 1;
                            return Padding(
                              padding: EdgeInsets.only(bottom: isLast ? 0 : 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 26,
                                    height: 26,
                                    decoration: BoxDecoration(
                                      color: AppColors.surface,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: AppColors.border, width: 0.8),
                                    ),
                                    child: Icon(
                                      item.icon,
                                      size: 14,
                                      color: AppColors.primaryDark,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.title,
                                          style: const TextStyle(
                                            fontFamily: 'Inter',
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w800,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 1),
                                        Text(
                                          item.description,
                                          style: const TextStyle(
                                            fontFamily: 'Inter',
                                            fontSize: 11.5,
                                            color: AppColors.textSecondary,
                                            height: 1.25,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ),
                      ),

                      const SizedBox(height: 10),

                      // ── Pro Tip Box ──────────────────────────────────────
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.35),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 1),
                              child: Icon(
                                Icons.lightbulb_rounded,
                                size: 15,
                                color: AppColors.primaryDark,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'PRO TIP',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.5,
                                      color: AppColors.primaryDark,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    data.proTip,
                                    style: const TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // ── Action Buttons ───────────────────────────────────────────
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.textPrimary,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  Navigator.of(context, rootNavigator: true).pop();
                },
                child: const Text(
                  'Got It!',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),

              if (type == ScreenGuideType.profile && userId != null && userId!.isNotEmpty) ...[
                const SizedBox(height: 8),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.border),
                    foregroundColor: AppColors.textPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    Navigator.of(context, rootNavigator: true).pop();
                    ref.read(onboardingGuideProvider.notifier).startTour(
                          context,
                          userId: userId!,
                          isReplay: true,
                        );
                  },
                  child: const Text(
                    'Replay Full App Tour',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
