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
              'Stay up to date with what friends and fellow cinephiles are currently watching, logging, and discussing in real time.',
          highlights: [
            ScreenGuideItem(
              icon: Icons.chat_bubble_outline_rounded,
              title: 'Reviews & Watch Moments',
              description:
                  'Read authentic thoughts, star ratings, and watch tags (Cinema, Home, Netflix) from users you follow.',
            ),
            ScreenGuideItem(
              icon: Icons.auto_awesome_rounded,
              title: 'Smart Suggest Deck',
              description:
                  'Swipe through personalized title recommendations tailored to your taste by the Hive recommendation engine.',
            ),
            ScreenGuideItem(
              icon: Icons.favorite_outline_rounded,
              title: 'Like, Comment & Discuss',
              description:
                  'Engage with your cinema circle: tap to like posts, celebrate streaks, or join discussions in the comments.',
            ),
            ScreenGuideItem(
              icon: Icons.qr_code_scanner_rounded,
              title: 'Top Quick Actions',
              description:
                  'Use the top bar scanner to find friends or titles, and check the bell icon for activity updates.',
            ),
          ],
          proTip: 'Tap any poster or movie title in the feed to open its full details and streaming links.',
        );

      case ScreenGuideType.entries:
        return const ScreenGuideData(
          badgeText: 'ENTRIES & WATCHLIST',
          icon: Icons.movie_filter_rounded,
          title: 'Your Entertainment Sanctuary',
          description:
              'Manage your entire cinematic journey in one organized place — from active binges to your permanent watch diary.',
          highlights: [
            ScreenGuideItem(
              icon: Icons.play_circle_outline_rounded,
              title: 'Currently Watching',
              description:
                  'Keep track of TV series in progress, ongoing anime seasons, or partially watched films.',
            ),
            ScreenGuideItem(
              icon: Icons.check_circle_outline_rounded,
              title: 'Watched Diary & History',
              description:
                  'Your permanent viewing archive with personal ratings, completion dates, and review notes.',
            ),
            ScreenGuideItem(
              icon: Icons.bookmark_outline_rounded,
              title: 'Watchlist',
              description:
                  'Save upcoming releases and must-watch titles to watch later so you never run out of ideas.',
            ),
            ScreenGuideItem(
              icon: Icons.recommend_outlined,
              title: 'Friend Suggestions',
              description:
                  'Review recommendations sent directly to you from friends, complete with their personal notes.',
            ),
          ],
          proTip: 'Use the category filter chips at the top to filter between Movies, TV, Anime, and K-Dramas.',
        );

      case ScreenGuideType.search:
        return const ScreenGuideData(
          badgeText: 'EXPLORE & SEARCH',
          icon: Icons.search_rounded,
          title: 'Discover Movies, Shows & Friends',
          description:
              'Search our comprehensive movie and series library or find friends and fellow movie fans across WatchersHive.',
          highlights: [
            ScreenGuideItem(
              icon: Icons.movie_creation_outlined,
              title: 'Universal Media Search',
              description:
                  'Search millions of movies, TV shows, and anime by title, cast member, director, or keyword.',
            ),
            ScreenGuideItem(
              icon: Icons.group_outlined,
              title: 'Find Friends & People',
              description:
                  'Switch to the Friends & People tab or search usernames to find and follow friends on the platform.',
            ),
            ScreenGuideItem(
              icon: Icons.tune_rounded,
              title: 'Genre & Year Filters',
              description:
                  'Refine your search with genre tags and release eras to pinpoint the exact vibe you are seeking.',
            ),
            ScreenGuideItem(
              icon: Icons.add_task_rounded,
              title: 'Instant Add & Log',
              description:
                  'Add any search result straight to your Watchlist or log it as watched with a single tap.',
            ),
          ],
          proTip: 'Tap the QR scanner icon in the top right to scan a friend’s Hive code in person.',
        );

      case ScreenGuideType.rankings:
        return const ScreenGuideData(
          badgeText: 'RANKINGS & STACKS',
          icon: Icons.leaderboard_rounded,
          title: 'Curate Custom Ranked Lists',
          description:
              'Create, organize, and share your personal ordered top rankings — from All-Time Favorites to franchise tiers.',
          highlights: [
            ScreenGuideItem(
              icon: Icons.add_rounded,
              title: 'Create Stacks',
              description:
                  'Tap "New Stack" in the top right to create a customized list for any theme or genre.',
            ),
            ScreenGuideItem(
              icon: Icons.drag_indicator_rounded,
              title: 'Drag & Reorder Titles',
              description:
                  'Easily rearrange films up and down to build your definitive ordered ranking.',
            ),
            ScreenGuideItem(
              icon: Icons.public_rounded,
              title: 'Showcase on Your Profile',
              description:
                  'Publish stacks publicly to show off your taste or keep personal draft stacks private.',
            ),
            ScreenGuideItem(
              icon: Icons.share_outlined,
              title: 'Share With Friends',
              description:
                  'Share your ranked stacks with fellow movie lovers to spark friendly cinema debates.',
            ),
          ],
          proTip: 'Tap "+ New Stack" in the top right corner anytime to build your next ranked list.',
        );

      case ScreenGuideType.profile:
        return const ScreenGuideData(
          badgeText: 'PROFILE & MILESTONES',
          icon: Icons.person_rounded,
          title: 'Your Cinema Identity & Stats',
          description:
              'Your personal cinephile hub featuring your watch milestones, Honey Badges, viewing streaks, and stats.',
          highlights: [
            ScreenGuideItem(
              icon: Icons.military_tech_rounded,
              title: 'Honey Level Badges',
              description:
                  'Earn and level up badges like First Log, Century Watcher, Rewatch Master, and Hive Recommender.',
            ),
            ScreenGuideItem(
              icon: Icons.insights_rounded,
              title: 'Viewing Analytics',
              description:
                  'Track total watches, hours logged, favorite genres, and your evolving Soul Persona.',
            ),
            ScreenGuideItem(
              icon: Icons.qr_code_2_rounded,
              title: 'Hive Code (QR)',
              description:
                  'Display your custom QR code so friends nearby can scan and follow you with zero friction.',
            ),
            ScreenGuideItem(
              icon: Icons.tune_rounded,
              title: 'Preferences & Settings',
              description:
                  'Adjust your streaming providers, privacy controls, password, or notification options.',
            ),
          ],
          proTip: 'Tap any Honey Badge to view your current level progress and requirements for the next tier!',
        );

      case ScreenGuideType.movieDetails:
        return const ScreenGuideData(
          badgeText: 'TITLE DETAILS',
          icon: Icons.movie_rounded,
          title: 'Streaming, Info & Logging',
          description:
              'Everything you need to know about a title: where it streams, cast & crew, ratings, and easy logging.',
          highlights: [
            ScreenGuideItem(
              icon: Icons.tv_rounded,
              title: 'Where to Watch',
              description:
                  'Find verified streaming platforms (Netflix, Prime Video, Disney+, etc.) in your region.',
            ),
            ScreenGuideItem(
              icon: Icons.star_rounded,
              title: 'Log & Rate',
              description:
                  'Record your star rating, review notes, watch location, and whether to share to the community feed.',
            ),
            ScreenGuideItem(
              icon: Icons.send_rounded,
              title: 'Suggest to Friend',
              description:
                  'Send this movie or series directly to any friend on WatchersHive with a custom recommendation note.',
            ),
            ScreenGuideItem(
              icon: Icons.qr_code_2_rounded,
              title: 'Movie QR Code',
              description:
                  'Tap the top QR icon to show a scannable code your friends can scan to open this title instantly.',
            ),
          ],
          proTip: 'Tap the bookmark icon to save this title directly to your Watchlist for movie night.',
        );

      case ScreenGuideType.notifications:
        return const ScreenGuideData(
          badgeText: 'NOTIFICATIONS HUB',
          icon: Icons.notifications_rounded,
          title: 'Activity & Interactions',
          description:
              'Stay notified about new follow requests, friend recommendations, likes, and comments on your reviews.',
          highlights: [
            ScreenGuideItem(
              icon: Icons.person_add_rounded,
              title: 'Follow Requests',
              description:
                  'Accept or decline pending follow requests from other users to manage who sees your activity.',
            ),
            ScreenGuideItem(
              icon: Icons.recommend_rounded,
              title: 'Movie Suggestions',
              description:
                  'Jump straight to titles your friends handpicked for you, complete with their notes.',
            ),
            ScreenGuideItem(
              icon: Icons.favorite_rounded,
              title: 'Social Reactions',
              description:
                  'See who liked your reviews or replied to your discussions in real time.',
            ),
            ScreenGuideItem(
              icon: Icons.done_all_rounded,
              title: 'Mark All Read',
              description:
                  'Tap "Mark all read" in the top right corner to clear your notification badge immediately.',
            ),
          ],
          proTip: 'Tap any suggestion notification to view the title details and add it to your watchlist!',
        );

      case ScreenGuideType.mindlens:
        return const ScreenGuideData(
          badgeText: 'MINDLENS AI',
          icon: Icons.psychology_rounded,
          title: 'Your AI Film Companion',
          description:
              'Your cinematic intelligence companion powered by AI. Get hyper-personalized recommendations and decode complex plots.',
          highlights: [
            ScreenGuideItem(
              icon: Icons.auto_awesome_rounded,
              title: 'Tailored Film Queries',
              description:
                  'Describe any mood, theme, or obscure genre premise to uncover hidden gems matching your taste.',
            ),
            ScreenGuideItem(
              icon: Icons.psychology_alt_rounded,
              title: 'Plot & Ending Analysis',
              description:
                  'Ask MindLens to unpack confusing plot twists, director symbolism, or thematic subtext.',
            ),
            ScreenGuideItem(
              icon: Icons.shuffle_rounded,
              title: 'Quick Inspiration Prompts',
              description:
                  'Tap one of the prompt chips for instant recommendations without typing a whole query.',
            ),
          ],
          proTip: 'MindLens is aware of what you already logged on WatchersHive and won’t suggest movies you’ve seen!',
        );

      case ScreenGuideType.scanner:
        return const ScreenGuideData(
          badgeText: 'HIVE SCANNER',
          icon: Icons.qr_code_scanner_rounded,
          title: 'Instant QR Code Scanner',
          description:
              'Scan physical or on-screen Hive QR codes to connect with users or open movies in an instant.',
          highlights: [
            ScreenGuideItem(
              icon: Icons.person_search_rounded,
              title: 'Scan Friend Codes',
              description:
                  'Point your camera at a friend’s Hive code to view their profile, follow them, or send a request.',
            ),
            ScreenGuideItem(
              icon: Icons.movie_rounded,
              title: 'Scan Movie Codes',
              description:
                  'Scan a title QR code from another device to immediately open its streaming and details page.',
            ),
            ScreenGuideItem(
              icon: Icons.flash_on_rounded,
              title: 'Torch & Camera Flip',
              description:
                  'Use the top controls to turn on the flashlight in dark settings or switch between cameras.',
            ),
            ScreenGuideItem(
              icon: Icons.qr_code_rounded,
              title: 'Show My Hive Code',
              description:
                  'Tap the button at the bottom to quickly display your own QR code for a friend to scan.',
            ),
          ],
          proTip: 'Center the QR code inside the golden viewfinder brackets for instantaneous recognition.',
        );

      case ScreenGuideType.userProfile:
        return const ScreenGuideData(
          badgeText: 'PUBLIC PROFILE',
          icon: Icons.account_circle_rounded,
          title: 'Friend Profile Hub',
          description:
              'Explore another user’s watch journey, recent reviews, favorite ranking stacks, and compare viewing tastes.',
          highlights: [
            ScreenGuideItem(
              icon: Icons.compare_arrows_rounded,
              title: 'Taste Compatibility',
              description:
                  'Tap "Compare History" to see your shared watch percentage and movie taste compatibility score.',
            ),
            ScreenGuideItem(
              icon: Icons.person_add_rounded,
              title: 'Follow & Connect',
              description:
                  'Follow this user to see their reviews, watch locations, and ratings in your Community Feed.',
            ),
            ScreenGuideItem(
              icon: Icons.send_rounded,
              title: 'Suggest a Film',
              description:
                  'Send a film or series recommendation directly to their inbox with a personalized note.',
            ),
            ScreenGuideItem(
              icon: Icons.leaderboard_rounded,
              title: 'Curated Ranked Stacks',
              description:
                  'Browse through their public ranked stacks for curated lists and movie night inspiration.',
            ),
          ],
          proTip: 'Tap any movie in their history to add it directly to your own Watchlist!',
        );

      case ScreenGuideType.compareHistory:
        return const ScreenGuideData(
          badgeText: 'TASTE COMPARISON',
          icon: Icons.compare_arrows_rounded,
          title: 'Viewing Taste Compatibility',
          description:
              'Compare your cinematic journey with a friend using our Swarm Viewing Intelligence.',
          highlights: [
            ScreenGuideItem(
              icon: Icons.percent_rounded,
              title: 'Compatibility Match',
              description:
                  'Calculated based on overlapping watches, rating concordance, and mutual favorite genres.',
            ),
            ScreenGuideItem(
              icon: Icons.done_all_rounded,
              title: 'Both Watched',
              description:
                  'Browse every film and series both of you have logged, side by side with your respective ratings.',
            ),
            ScreenGuideItem(
              icon: Icons.recommend_rounded,
              title: 'Recommendations For You',
              description:
                  'Discover titles they loved and rated highly that you haven’t logged yet.',
            ),
          ],
          proTip: 'Use the shared comparison to find the perfect mutual movie to watch together next!',
        );
    }
  }
}

/// Reusable contextual guide dialog explaining a specific screen’s features.
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
      barrierColor: Colors.black.withValues(alpha: 0.65),
      routeSettings: RouteSettings(name: 'ScreenGuideDialog_${type.name}'),
      builder: (dialogContext) => ScreenGuideDialog(type: type, userId: userId),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ScreenGuideData.forType(type);

    return Dialog(
      backgroundColor: AppColors.surface,
      elevation: 8,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: AppColors.border, width: 1.2),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 440,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header Row: Badge & Close Button
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border, width: 0.8),
                    ),
                    child: Text(
                      data.badgeText,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: AppColors.primaryDark,
                      ),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppColors.textMuted, size: 22),
                    tooltip: 'Close',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
                  ),
                ],
              ),
            ),

            const Divider(height: 1, thickness: 1, color: AppColors.border),

            // Scrollable Content
            Flexible(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Column(
                  children: [
                    // Hero Icon Emblem
                    Container(
                      width: 62,
                      height: 62,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primary.withValues(alpha: 0.3),
                            AppColors.primaryLight.withValues(alpha: 0.15),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.6),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.2),
                            blurRadius: 14,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Icon(
                        data.icon,
                        size: 30,
                        color: AppColors.primaryDark,
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Title
                    Text(
                      data.title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.3,
                        height: 1.25,
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Description
                    Text(
                      data.description,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        height: 1.45,
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Highlights List Container
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceHighest.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        children: List.generate(data.highlights.length, (index) {
                          final item = data.highlights[index];
                          final isLast = index == data.highlights.length - 1;
                          return Padding(
                            padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 34,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    color: AppColors.surface,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: AppColors.border, width: 0.8),
                                  ),
                                  child: Icon(
                                    item.icon,
                                    size: 18,
                                    color: AppColors.primaryDark,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.title,
                                        style: const TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        item.description,
                                        style: const TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 12,
                                          color: AppColors.textSecondary,
                                          height: 1.35,
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

                    const SizedBox(height: 12),

                    // Pro Tip Box
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.4),
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
                              size: 18,
                              color: AppColors.primaryDark,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'PRO TIP',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.6,
                                    color: AppColors.primaryDark,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  data.proTip,
                                  style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                    height: 1.35,
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

            const Divider(height: 1, thickness: 1, color: AppColors.border),

            // Bottom Action Area
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: const Color(0xFF2D2926),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
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
                          fontSize: 14.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),

                  // Optional: If viewing Profile guide, offer full app tour replay
                  if (type == ScreenGuideType.profile && (userId != null && userId!.isNotEmpty)) ...[
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () {
                        Navigator.of(context, rootNavigator: true).pop();
                        ref.read(onboardingGuideProvider.notifier).startTour(
                              context,
                              userId: userId!,
                              isReplay: true,
                            );
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.textMuted,
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      ),
                      icon: const Icon(Icons.replay_rounded, size: 15, color: AppColors.textMuted),
                      label: const Text(
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
          ],
        ),
      ),
    );
  }
}
