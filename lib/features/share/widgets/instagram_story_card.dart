import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/config/web_urls.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/wh_brand_logo.dart';

/// A presentation-ready 9:16 Instagram Story card for sharing a watched or logged film/show.
/// Designed with minimal text, high visual contrast, cinematic poster, pictorial star rating,
/// WatchersHive logo, and a scannable Hive QR link to view details or join.
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
  });

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

  String get _shortDisplayUrl {
    if (tmdbId != null && tmdbId! > 0) {
      final type = mediaType.toLowerCase() == 'tv' ? 'tv' : 'm';
      return 'watchershive.com/$type/$tmdbId';
    }
    return 'watchershive.com';
  }

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
          color: const Color(0xFF0F0E0D),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.6),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background Artwork Bleed (blurred cinematic backdrop)
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
                  filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          const Color(0xFF0D0B0A).withValues(alpha: 0.82),
                          const Color(0xFF141210).withValues(alpha: 0.88),
                          const Color(0xFF0D0B0A).withValues(alpha: 0.95),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ] else ...[
              // Ambient gradient mesh fallback
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF1B1713),
                      Color(0xFF0D0C0B),
                      Color(0xFF16130F),
                    ],
                  ),
                ),
              ),
            ],

            // Subtle warm honey ambient glow from top-right and bottom-left
            Positioned(
              top: -60,
              right: -60,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withValues(alpha: 0.15),
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
                  color: AppColors.primary.withValues(alpha: 0.10),
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
                    // Top Bar: WatchersHive Logo & Status Badge
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

                            // Status Pill: Just Watched / Watching
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: AppColors.primary.withValues(alpha: 0.5),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                isCompleted ? '🍿 JUST WATCHED' : '📺 WATCHING',
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.6,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),

                        // User attribution if present
                        if ((userDisplayName != null && userDisplayName!.trim().isNotEmpty) ||
                            (username != null && username!.trim().isNotEmpty)) ...[
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
                                'Logged by ${userDisplayName ?? username}',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white.withValues(alpha: 0.75),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),

                    // Center Hero: Movie Poster + Title + Pictorial Rating
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
                                color: AppColors.primary.withValues(alpha: 0.35),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.75),
                                  blurRadius: 24,
                                  offset: const Offset(0, 12),
                                ),
                                BoxShadow(
                                  color: AppColors.primary.withValues(alpha: 0.12),
                                  blurRadius: 20,
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
                                      color: const Color(0xFF1E1B17),
                                      child: const Center(
                                        child: Icon(Icons.movie_rounded, color: AppColors.primary, size: 36),
                                      ),
                                    ),
                                    errorWidget: (_, __, ___) => Container(
                                      color: const Color(0xFF1E1B17),
                                      child: const Center(
                                        child: Icon(Icons.broken_image_rounded, color: AppColors.textMuted, size: 36),
                                      ),
                                    ),
                                  )
                                else
                                  Container(
                                    color: const Color(0xFF1E1B17),
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
                                        color: Colors.white.withValues(alpha: 0.15),
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
                              color: Colors.white,
                              letterSpacing: -0.4,
                              height: 1.2,
                            ),
                          ),

                          const SizedBox(height: 10),

                          // Pictorial Rating Section
                          if (rating != null && rating! > 0) ...[
                            _buildPictorialRating(rating!),
                          ],

                          // Short Review Quote (compact, max 2 lines)
                          if (review != null && review!.trim().isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Container(
                              margin: const EdgeInsets.symmetric(horizontal: 12),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.12),
                                  width: 0.8,
                                ),
                              ),
                              child: Text(
                                '"${_cleanReviewSnippet(review!)}"',
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 11.5,
                                  fontStyle: FontStyle.italic,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white.withValues(alpha: 0.9),
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Bottom Link & QR Card ("link to join or view movie details")
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.09),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          width: 1,
                        ),
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
                            ),
                            child: QrImageView(
                              data: _movieUrl,
                              version: QrVersions.auto,
                              size: 48,
                              backgroundColor: Colors.white,
                              eyeStyle: const QrEyeStyle(
                                eyeShape: QrEyeShape.square,
                                color: Color(0xFF141210),
                              ),
                              dataModuleStyle: const QrDataModuleStyle(
                                dataModuleShape: QrDataModuleShape.square,
                                color: Color(0xFF141210),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Text & Link CTA
                          Flexible(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        'View on WatchersHive',
                                        style: TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    SizedBox(width: 4),
                                    Icon(
                                      Icons.arrow_forward_rounded,
                                      size: 12,
                                      color: AppColors.primary,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _shortDisplayUrl,
                                  style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Scan or tap to view reviews & track together',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 9,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white.withValues(alpha: 0.55),
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

  /// Builds the pictorial star rating with honey-gold glowing stars and score chip.
  Widget _buildPictorialRating(double score) {
    // Score is 0-10, normalize to 5 stars
    final fiveStarScore = (score / 2.0).clamp(0.0, 5.0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1914),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.4),
          width: 1,
        ),
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
                color: Color(0xFF141210),
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
