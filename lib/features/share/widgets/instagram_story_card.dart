import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/config/web_urls.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/wh_brand_logo.dart';

/// Contextual modes for generating Instagram Story cards:
/// - [logged]: User completed/logged a watch (shows '🍿 JUST WATCHED', user rating, review)
/// - [watching]: User currently watching (shows '📺 CURRENTLY WATCHING', in progress pill, NO rating)
/// - [general]: Unlogged/movie share (shows '🎬 DISCOVER', TMDB community rating, clean recommendation)
enum StoryShareMode {
  logged,
  watching,
  general,
}

/// A presentation-ready 9:16 Instagram Story card for sharing films and shows.
/// Designed with minimal text, high visual contrast, cinematic poster, pictorial star rating,
/// WatchersHive brand aesthetic, and a scannable Hive QR link.
class InstagramStoryCard extends StatelessWidget {
  final String title;
  final String? posterPath;
  final String? backdropPath;
  final double? rating;
  final String? review;
  final int? tmdbId;
  final String mediaType;
  final String? releaseYear;
  final String? userDisplayName;
  final String? username;
  final String? userAvatarUrl;
  final List<String>? watchBuddies;
  final bool isCompleted;
  final StoryShareMode shareMode;

  const InstagramStoryCard({
    super.key,
    required this.title,
    this.posterPath,
    this.backdropPath,
    this.rating,
    this.review,
    this.tmdbId,
    this.mediaType = 'movie',
    this.releaseYear,
    this.userDisplayName,
    this.username,
    this.userAvatarUrl,
    this.watchBuddies,
    this.isCompleted = true,
    StoryShareMode? shareMode,
  }) : shareMode = shareMode ?? (isCompleted ? StoryShareMode.logged : StoryShareMode.watching);

  String get _movieUrl {
    if (tmdbId != null && tmdbId! > 0) {
      return WebUrls.movieDetails(
        mediaType,
        tmdbId!,
        suggestedByUsername: username,
        source: 'story',
      );
    }
    return WebUrls.baseUrl;
  }

  /// Clean branded URL without ugly internal numeric IDs
  String get _shortDisplayUrl => 'watchershive.com';

  String? get _resolvedPosterUrl {
    if (posterPath == null || posterPath!.trim().isEmpty) return null;
    return ApiEndpoints.tmdbPoster(posterPath);
  }

  String? get _resolvedBackdropUrl {
    final path = backdropPath ?? posterPath;
    if (path == null || path.trim().isEmpty) return null;
    return ApiEndpoints.tmdbBackdrop(path);
  }

  @override
  Widget build(BuildContext context) {
    final posterUrl = _resolvedPosterUrl;
    final backdropUrl = _resolvedBackdropUrl;
    final isTv = mediaType.toLowerCase() == 'tv';

    return AspectRatio(
      aspectRatio: 9 / 16,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cardHeight = constraints.maxHeight.isFinite ? constraints.maxHeight : 568.8;

          // Instagram Story Standard UI/UX Safe Zones:
          // Top Safe Margin: ~13.8% of canvas height (e.g. ~78 pt on 568.8 pt canvas, ~88 pt on 640 pt canvas)
          // completely clears Instagram's native top overlay: status bar, story progress segments,
          // user profile picture, account handle, and the close 'X' button.
          // Bottom Safe Margin: ~11.8% of canvas height (e.g. ~67 pt on 568.8 pt canvas, ~75 pt on 640 pt canvas)
          // completely clears Instagram's native bottom "Send message..." reply bar and reaction icons.
          final topSafeMargin = cardHeight * 0.138;
          final bottomSafeMargin = cardHeight * 0.118;
          final hasReview = shareMode == StoryShareMode.logged &&
              review != null &&
              review!.trim().isNotEmpty;

          return Container(
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.18),
                  blurRadius: 20,
                  spreadRadius: 1,
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Background Artwork Bleed (blurred warm cinematic backdrop)
                if (backdropUrl != null) ...[
                  Positioned.fill(
                    child: CachedNetworkImage(
                      imageUrl: backdropUrl,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                  Positioned.fill(
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              const Color(0xFFFFFDF8).withValues(alpha: 0.88),
                              const Color(0xFFFFF9F0).withValues(alpha: 0.93),
                              const Color(0xFFFFF4E0).withValues(alpha: 0.97),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  // Ambient warm honey cream gradient mesh fallback
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0xFFFFFDF7),
                          Color(0xFFFFF9F0),
                          Color(0xFFFFF3DE),
                        ],
                      ),
                    ),
                  ),
                ],

                // Warm honey ambient glow orbs
                Positioned(
                  top: -60,
                  right: -60,
                  child: Container(
                    width: 220,
                    height: 220,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary.withValues(alpha: 0.22),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -80,
                  left: -80,
                  child: Container(
                    width: 240,
                    height: 240,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primaryLight.withValues(alpha: 0.18),
                    ),
                  ),
                ),

                // Content Canvas (positioned strictly within Instagram Story Safe Zones)
                Padding(
                  padding: EdgeInsets.fromLTRB(16, topSafeMargin, 16, bottomSafeMargin),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Top Bar: Elevated Frosted WatchersHive Brand & Context Status
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.95),
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(
                                color: AppColors.primary.withValues(alpha: 0.45),
                                width: 1.2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.06),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // WatchersHive Brand Logo & Name
                                const Flexible(
                                  child: WHBrandLogo(
                                    logoSize: 22,
                                    fontSize: 15.5,
                                  ),
                                ),
                                const SizedBox(width: 8),

                                // Context-Specific Status Pill
                                _buildStatusPill(),
                              ],
                            ),
                          ),

                          // User attribution if relevant to mode
                          if (_shouldShowAttribution) ...[
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (userAvatarUrl != null && userAvatarUrl!.trim().isNotEmpty) ...[
                                  CircleAvatar(
                                    radius: 8.5,
                                    backgroundImage: CachedNetworkImageProvider(
                                      ApiEndpoints.resolveAvatarUrl(userAvatarUrl),
                                    ),
                                    backgroundColor: AppColors.surface,
                                  ),
                                  const SizedBox(width: 5),
                                ],
                                Flexible(
                                  child: Text(
                                    _attributionText,
                                    style: const TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textSecondary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),

                    // Center Hero: Big Movie Banner + Good-Length Poster + Title + Ratings & Review in the bottom
                    Expanded(
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.center,
                          child: SizedBox(
                            width: 320,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // 🎬 Cinematic Showcase: Big Movie Banner + Overlapping Good-Length Poster
                                Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    // 1. Bigger Banner of the Movie (Prominent backdrop landscape)
                                    Container(
                                      width: double.infinity,
                                      height: 135,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(18),
                                        border: Border.all(
                                          color: AppColors.primary.withValues(alpha: 0.55),
                                          width: 1.4,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.18),
                                            blurRadius: 18,
                                            offset: const Offset(0, 8),
                                          ),
                                          BoxShadow(
                                            color: AppColors.primary.withValues(alpha: 0.15),
                                            blurRadius: 12,
                                          ),
                                        ],
                                      ),
                                      clipBehavior: Clip.antiAlias,
                                      child: Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          if (backdropUrl != null)
                                            CachedNetworkImage(
                                              imageUrl: backdropUrl,
                                              fit: BoxFit.cover,
                                              placeholder: (_, __) => Container(
                                                color: const Color(0xFF23201D),
                                                child: const Center(
                                                  child: Icon(Icons.movie_rounded, color: AppColors.primary, size: 36),
                                                ),
                                              ),
                                              errorWidget: (_, __, ___) => Container(
                                                color: const Color(0xFF23201D),
                                                child: const Center(
                                                  child: Icon(Icons.movie_rounded, color: AppColors.primary, size: 36),
                                                ),
                                              ),
                                            )
                                          else
                                            Container(
                                              decoration: const BoxDecoration(
                                                gradient: LinearGradient(
                                                  begin: Alignment.topLeft,
                                                  end: Alignment.bottomRight,
                                                  colors: [Color(0xFF2D2926), Color(0xFF1B1917)],
                                                ),
                                              ),
                                              child: const Center(
                                                child: Icon(Icons.movie_rounded, color: AppColors.primary, size: 40),
                                              ),
                                            ),

                                          // Ambient Gradient Scrim to guarantee badge readability & depth
                                          Container(
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                begin: Alignment.topCenter,
                                                end: Alignment.bottomCenter,
                                                colors: [
                                                  Colors.black.withValues(alpha: 0.25),
                                                  Colors.transparent,
                                                  Colors.black.withValues(alpha: 0.70),
                                                ],
                                                stops: const [0.0, 0.4, 1.0],
                                              ),
                                            ),
                                          ),

                                          // Media Type & Year Badge
                                          Positioned(
                                            top: 10,
                                            right: 10,
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                                              decoration: BoxDecoration(
                                                color: Colors.black.withValues(alpha: 0.75),
                                                borderRadius: BorderRadius.circular(6),
                                                border: Border.all(
                                                  color: Colors.white.withValues(alpha: 0.3),
                                                  width: 0.8,
                                                ),
                                              ),
                                              child: Text(
                                                [
                                                  isTv ? 'SERIES' : 'MOVIE',
                                                  if (releaseYear != null && releaseYear!.isNotEmpty) releaseYear!,
                                                ].join(' • '),
                                                style: const TextStyle(
                                                  fontFamily: 'Inter',
                                                  fontSize: 9.5,
                                                  fontWeight: FontWeight.w800,
                                                  letterSpacing: 0.5,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    // 2. Good-Length Poster (Overlapping the banner at bottom-left)
                                    Positioned(
                                      left: 14,
                                      bottom: -32,
                                      child: Container(
                                        width: 76,
                                        height: 114, // Exact 2:3 vertical aspect ratio
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: Colors.white,
                                            width: 2.2,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withValues(alpha: 0.35),
                                              blurRadius: 14,
                                              offset: const Offset(0, 6),
                                            ),
                                            BoxShadow(
                                              color: AppColors.primary.withValues(alpha: 0.30),
                                              blurRadius: 10,
                                            ),
                                          ],
                                        ),
                                        clipBehavior: Clip.antiAlias,
                                        child: posterUrl != null
                                            ? CachedNetworkImage(
                                                imageUrl: posterUrl,
                                                fit: BoxFit.cover,
                                                placeholder: (_, __) => Container(
                                                  color: AppColors.surfaceHighest,
                                                  child: const Center(
                                                    child: Icon(Icons.movie_rounded, color: AppColors.primary, size: 28),
                                                  ),
                                                ),
                                                errorWidget: (_, __, ___) => Container(
                                                  color: AppColors.surfaceHighest,
                                                  child: const Center(
                                                    child: Icon(Icons.broken_image_rounded, color: AppColors.textMuted, size: 28),
                                                  ),
                                                ),
                                              )
                                            : Container(
                                                color: AppColors.surfaceHighest,
                                                child: const Center(
                                                  child: Icon(Icons.movie_rounded, color: AppColors.primary, size: 36),
                                                ),
                                              ),
                                      ),
                                    ),
                                  ],
                                ),

                                // Spacing to account for poster overlap
                                const SizedBox(height: 38),

                                // Clean, Bold Movie Title
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  child: Text(
                                    title,
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 20,
                                      fontWeight: FontWeight.w900,
                                      color: AppColors.textPrimary,
                                      letterSpacing: -0.4,
                                      height: 1.2,
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 8),

                                // Context-Aware Middle Content (Ratings in the bottom)
                                _buildCenterDetails(),

                                // Short Review Quote (compact, only for logged watches)
                                if (hasReview) ...[
                                  const SizedBox(height: 8),
                                  Container(
                                    margin: const EdgeInsets.symmetric(horizontal: 10),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.95),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: AppColors.primary.withValues(alpha: 0.35),
                                        width: 1,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.05),
                                          blurRadius: 10,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Icon(
                                          Icons.format_quote_rounded,
                                          size: 15,
                                          color: AppColors.primaryDark,
                                        ),
                                        const SizedBox(width: 5),
                                        Flexible(
                                          child: Text(
                                            '"${_cleanReviewSnippet(review!)}"',
                                            textAlign: TextAlign.left,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontFamily: 'Inter',
                                              fontSize: 11,
                                              fontStyle: FontStyle.italic,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.textPrimary,
                                              height: 1.25,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Bottom Link & QR Card (High-Conversion WatchersHive App Discovery Card)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.55),
                          width: 1.4,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          // Scannable Hive QR Code
                          Container(
                            padding: const EdgeInsets.all(3.5),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(9),
                              border: Border.all(
                                color: AppColors.primary.withValues(alpha: 0.45),
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withValues(alpha: 0.12),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                            child: QrImageView(
                              data: _movieUrl,
                              version: QrVersions.auto,
                              size: 46,
                              backgroundColor: Colors.white,
                              eyeStyle: const QrEyeStyle(
                                eyeShape: QrEyeShape.square,
                                color: Color(0xFF2D2926),
                              ),
                              dataModuleStyle: const QrDataModuleStyle(
                                dataModuleShape: QrDataModuleShape.square,
                                color: Color(0xFF2D2926),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),

                          // Text & CTA details
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.hive_rounded,
                                      size: 13,
                                      color: AppColors.primaryDark,
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        _bottomCtaHeading,
                                        style: const TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w900,
                                          color: AppColors.textPrimary,
                                          letterSpacing: -0.2,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),

                                // High-Contrast Action Pill (Golden Contrast Rule: Charcoal text on Honey Gold)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    borderRadius: BorderRadius.circular(6),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.primaryDark.withValues(alpha: 0.25),
                                        blurRadius: 4,
                                        offset: const Offset(0, 1),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          _shortDisplayUrl,
                                          style: const TextStyle(
                                            fontFamily: 'Inter',
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w900,
                                            color: Color(0xFF262626), // Charcoal Black per Golden Contrast Rule
                                            letterSpacing: 0.2,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      const Icon(
                                        Icons.arrow_forward_rounded,
                                        size: 11,
                                        color: Color(0xFF262626),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 3),

                                const Text(
                                  'Tap Link sticker or scan QR to view on WatchersHive',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textMuted,
                                    letterSpacing: 0.1,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
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
            ],
          ),
        );
      },
    ),
  );
}

  /// Builds the top-right contextual pill depending on shareMode
  Widget _buildStatusPill() {
    final String label;
    final Color bg;
    final Color border;
    final Color text;

    switch (shareMode) {
      case StoryShareMode.logged:
        label = '🍿 JUST WATCHED';
        bg = const Color(0xFFFFF3D6);
        border = const Color(0xFFE59700);
        text = const Color(0xFF995700);
        break;
      case StoryShareMode.watching:
        label = '📺 WATCHING';
        bg = const Color(0xFFFEF3C7);
        border = const Color(0xFFF59E0B);
        text = const Color(0xFFB45309);
        break;
      case StoryShareMode.general:
        label = '🎬 DISCOVER';
        bg = Colors.white;
        border = AppColors.border;
        text = AppColors.textSecondary;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 9.5,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.6,
          color: text,
        ),
      ),
    );
  }

  bool get _shouldShowAttribution {
    if (shareMode == StoryShareMode.general) {
      return (userDisplayName != null && userDisplayName!.trim().isNotEmpty) ||
          (username != null && username!.trim().isNotEmpty);
    }
    return (userDisplayName != null && userDisplayName!.trim().isNotEmpty) ||
        (username != null && username!.trim().isNotEmpty);
  }

  String get _attributionText {
    final name = userDisplayName ?? username;
    final hasBuddies = watchBuddies != null && watchBuddies!.isNotEmpty;
    final buddiesText = hasBuddies ? ' with ${watchBuddies!.join(', ')}' : '';

    switch (shareMode) {
      case StoryShareMode.logged:
        return 'Logged by $name$buddiesText';
      case StoryShareMode.watching:
        return 'Watching now: $name$buddiesText';
      case StoryShareMode.general:
        return 'Shared via WatchersHive';
    }
  }

  String get _bottomCtaHeading {
    switch (shareMode) {
      case StoryShareMode.logged:
        return 'View on WatchersHive';
      case StoryShareMode.watching:
        return 'Join on WatchersHive';
      case StoryShareMode.general:
        return 'Check out on WatchersHive';
    }
  }

  /// Builds context-aware center detail widget:
  /// - Logged: Pictorial 5-star rating with personal score
  /// - Watching: In-progress status pill (NO personal rating)
  /// - General: TMDB community score pill (clearly labeled as community score)
  Widget _buildCenterDetails() {
    switch (shareMode) {
      case StoryShareMode.logged:
        if (rating != null && rating! > 0) {
          return _buildPictorialRating(rating!);
        }
        return const SizedBox.shrink();

      case StoryShareMode.watching:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.6),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.play_circle_fill_rounded, color: AppColors.primary, size: 16),
              SizedBox(width: 6),
              Flexible(
                child: Text(
                  'Started Watching',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: 0.3,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );

      case StoryShareMode.general:
        if (rating != null && rating! > 0) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.border,
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.star_rounded, color: AppColors.primary, size: 16),
                const SizedBox(width: 5),
                Text(
                  '${rating!.toStringAsFixed(1)} TMDB Rating',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          );
        }
        return const SizedBox.shrink();
    }
  }

  /// Builds the pictorial star rating with honey-gold glowing stars and score chip.
  Widget _buildPictorialRating(double score) {
    // Score is 0-10, normalize to 5 stars
    final fiveStarScore = (score / 2.0).clamp(0.0, 5.0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.55),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 5-Star Pictorial Visualization
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(5, (index) {
              final starIndex = index + 1;
              if (fiveStarScore >= starIndex) {
                return const Icon(
                  Icons.star_rounded,
                  color: AppColors.primary,
                  size: 18,
                );
              } else if (fiveStarScore >= starIndex - 0.5) {
                return const Icon(
                  Icons.star_half_rounded,
                  color: AppColors.primary,
                  size: 18,
                );
              } else {
                return Icon(
                  Icons.star_outline_rounded,
                  color: AppColors.primary.withValues(alpha: 0.35),
                  size: 18,
                );
              }
            }),
          ),
          const SizedBox(width: 8),

          // Numeric Rating Chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '${score.toStringAsFixed(1)} / 10',
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 10.5,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _cleanReviewSnippet(String raw) {
    final clean = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (clean.length > 90) {
      return '${clean.substring(0, 87)}...';
    }
    return clean;
  }
}
