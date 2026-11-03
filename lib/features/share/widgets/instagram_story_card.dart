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
      child: Container(
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

            // Content Canvas (9:16 layout)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Top Bar: WatchersHive Logo & Context-Aware Status Badge
                    Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // WatchersHive Brand
                            const Flexible(
                              child: WHBrandLogo(
                                logoSize: 22,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(width: 8),

                            // Context-Specific Status Pill
                            _buildStatusPill(),
                          ],
                        ),

                        // User attribution if relevant to mode
                        if (_shouldShowAttribution) ...[
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (userAvatarUrl != null && userAvatarUrl!.trim().isNotEmpty) ...[
                                CircleAvatar(
                                  radius: 9,
                                  backgroundImage: CachedNetworkImageProvider(
                                    ApiEndpoints.resolveAvatarUrl(userAvatarUrl),
                                  ),
                                  backgroundColor: AppColors.surface,
                                ),
                                const SizedBox(width: 6),
                              ],
                              Text(
                                _attributionText,
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),

                    // Center Hero: Movie Poster + Title + Rating / In-Progress Pill
                    Flexible(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Movie Poster Card
                          Container(
                            constraints: const BoxConstraints(
                              maxWidth: 165,
                              maxHeight: 245,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: AppColors.primary.withValues(alpha: 0.65),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF2D2926).withValues(alpha: 0.22),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                                BoxShadow(
                                  color: AppColors.primary.withValues(alpha: 0.25),
                                  blurRadius: 18,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Stack(
                              children: [
                                if (posterUrl != null)
                                  CachedNetworkImage(
                                    imageUrl: posterUrl,
                                    fit: BoxFit.cover,
                                    placeholder: (_, __) => Container(
                                      color: AppColors.surfaceHighest,
                                      child: const Center(
                                        child: Icon(Icons.movie_rounded, color: AppColors.primary, size: 36),
                                      ),
                                    ),
                                    errorWidget: (_, __, ___) => Container(
                                      color: AppColors.surfaceHighest,
                                      child: const Center(
                                        child: Icon(Icons.broken_image_rounded, color: AppColors.textMuted, size: 36),
                                      ),
                                    ),
                                  )
                                else
                                  Container(
                                    color: AppColors.surfaceHighest,
                                    child: const Center(
                                      child: Icon(Icons.movie_rounded, color: AppColors.primary, size: 48),
                                    ),
                                  ),

                                // Media Type & Year Badge
                                Positioned(
                                  top: 8,
                                  left: 8,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.75),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: Colors.white.withValues(alpha: 0.2),
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
                                        fontSize: 9,
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

                          const SizedBox(height: 16),

                          // Clean, Bold Movie Title
                          Text(
                            title,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 21,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textPrimary,
                              letterSpacing: -0.4,
                              height: 1.2,
                            ),
                          ),

                          const SizedBox(height: 10),

                          // Context-Aware Middle Content
                          _buildCenterDetails(),

                          // Short Review Quote (compact, only for logged watches)
                          if (shareMode == StoryShareMode.logged &&
                              review != null &&
                              review!.trim().isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Container(
                              margin: const EdgeInsets.symmetric(horizontal: 12),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
                              child: Text(
                                '"${_cleanReviewSnippet(review!)}"',
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 11.5,
                                  fontStyle: FontStyle.italic,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Bottom Link & QR Card (Clean URL without ugly numeric IDs)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.45),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.07),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Scannable Hive QR Code
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: AppColors.border,
                                width: 0.8,
                              ),
                            ),
                            child: QrImageView(
                              data: _movieUrl,
                              version: QrVersions.auto,
                              size: 48,
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
                          const SizedBox(width: 12),

                          // Text & Link CTA (clean watchershive.com domain)
                          Flexible(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        _bottomCtaHeading,
                                        style: const TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w900,
                                          color: AppColors.textPrimary,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(
                                      Icons.arrow_forward_rounded,
                                      size: 13,
                                      color: AppColors.primaryDark,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _shortDisplayUrl,
                                  style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.primaryDark,
                                    letterSpacing: 0.2,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  'Scan QR to view & track',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 9,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.textMuted,
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
          ],
        ),
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
    switch (shareMode) {
      case StoryShareMode.logged:
        return 'Logged by $name';
      case StoryShareMode.watching:
        return 'Watching now: $name';
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
