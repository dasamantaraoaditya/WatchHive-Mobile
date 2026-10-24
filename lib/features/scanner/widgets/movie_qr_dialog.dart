import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/config/web_urls.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/models/user.dart';
import '../../../shared/widgets/wh_alert.dart';

/// Modal dialog that generates a QR code for a movie or TV show.
/// Enables users to scan from another device and open the exact movie details instantly.
class MovieQrDialog extends StatelessWidget {
  final int tmdbId;
  final String mediaType; // 'movie' or 'tv'
  final String title;
  final String? posterPath;
  final String? releaseYear;
  final User? suggestedByUser;
  final String? suggestedByUserId;
  final String? suggestedByUsername;

  const MovieQrDialog({
    super.key,
    required this.tmdbId,
    required this.mediaType,
    required this.title,
    this.posterPath,
    this.releaseYear,
    this.suggestedByUser,
    this.suggestedByUserId,
    this.suggestedByUsername,
  });

  static void show(
    BuildContext context, {
    required int tmdbId,
    required String mediaType,
    required String title,
    String? posterPath,
    String? releaseYear,
    User? suggestedByUser,
    String? suggestedByUserId,
    String? suggestedByUsername,
  }) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      barrierDismissible: true,
      builder: (context) => MovieQrDialog(
        tmdbId: tmdbId,
        mediaType: mediaType,
        title: title,
        posterPath: posterPath,
        releaseYear: releaseYear,
        suggestedByUser: suggestedByUser,
        suggestedByUserId: suggestedByUserId,
        suggestedByUsername: suggestedByUsername,
      ),
    );
  }

  String get _movieUrl {
    final uid = suggestedByUser?.id ?? suggestedByUserId;
    final uname = suggestedByUser?.username ?? suggestedByUsername;
    return WebUrls.movieDetails(
      mediaType,
      tmdbId,
      suggestedByUserId: uid,
      suggestedByUsername: uname,
    );
  }

  String? get _resolvedPosterUrl {
    if (posterPath == null || posterPath!.isEmpty) return null;
    if (posterPath!.startsWith('http')) return posterPath;
    return 'https://image.tmdb.org/t/p/w342$posterPath';
  }

  void _copyLink(BuildContext context) {
    Clipboard.setData(ClipboardData(text: _movieUrl));
    HapticFeedback.lightImpact();
    WHAlert.showSuccess(context, 'Movie link copied to clipboard! 📋');
  }

  void _shareMovie() {
    Share.share(
      'Check out "$title" on WatchersHive! 🎬🐝 Scan or open to track together:\n\n$_movieUrl',
      subject: 'WatchersHive: $title',
    );
  }

  @override
  Widget build(BuildContext context) {
    final isTv = mediaType.toLowerCase() == 'tv';
    final posterUrl = _resolvedPosterUrl;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 380),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.08),
                blurRadius: 36,
                spreadRadius: 2,
              ),
            ],
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
              // Header with title and close button
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 12, 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.qr_code_2_rounded,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Scan & View on Another Device',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: AppColors.textMuted, size: 22),
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              const Divider(color: AppColors.border, height: 1),

              // Main content: Movie Thumbnail, Title, and QR Code
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 18, 24, 20),
                child: Column(
                  children: [
                    // Movie preview header
                    Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: posterUrl != null
                              ? CachedNetworkImage(
                                  imageUrl: posterUrl,
                                  width: 44,
                                  height: 62,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) => _buildPosterPlaceholder(),
                                )
                              : _buildPosterPlaceholder(),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isTv
                                          ? Colors.blue.withValues(alpha: 0.15)
                                          : AppColors.primary.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      isTv ? 'SERIES' : 'MOVIE',
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: isTv ? Colors.lightBlueAccent : AppColors.primary,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                  if (releaseYear != null && releaseYear!.isNotEmpty) ...[
                                    const SizedBox(width: 8),
                                    Text(
                                      releaseYear!,
                                      style: const TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // QR Code Card (High Contrast White Container for Camera Scanning)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          QrImageView(
                            data: _movieUrl,
                            version: QrVersions.auto,
                            size: 200,
                            backgroundColor: Colors.white,
                            eyeStyle: const QrEyeStyle(
                              eyeShape: QrEyeShape.square,
                              color: Color(0xFF141419),
                            ),
                            dataModuleStyle: const QrDataModuleStyle(
                              dataModuleShape: QrDataModuleShape.square,
                              color: Color(0xFF141419),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(3),
                                decoration: const BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.movie_filter_rounded,
                                  size: 11,
                                  color: Colors.black,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'WatchersHive Cinema',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF2D2926),
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    if (suggestedByUser != null || (suggestedByUsername != null && suggestedByUsername!.isNotEmpty)) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.auto_awesome_rounded, size: 14, color: AppColors.primaryDark),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                'Scanning credits @${suggestedByUser?.username ?? suggestedByUsername} as recommender',
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primaryDark,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 18),

                    const Text(
                      'Scan this QR code with your phone camera or the WatchersHive scanner on any device to open this movie instantly.',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textMuted,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 20),

                    // Primary Action Buttons
                    Row(
                      children: [
                        // Copy Link
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.textPrimary,
                              side: const BorderSide(color: AppColors.border),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            onPressed: () => _copyLink(context),
                            icon: const Icon(Icons.copy_rounded, size: 16),
                            label: const Text(
                              'Copy Link',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Share
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              elevation: 0,
                            ),
                            onPressed: _shareMovie,
                            icon: const Icon(Icons.share_rounded, size: 16),
                            label: const Text(
                              'Share Code',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Open in-app scanner shortcut
                    SizedBox(
                      width: double.infinity,
                      child: TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.textSecondary,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        onPressed: () {
                          Navigator.of(context).pop();
                          context.push('/scanner');
                        },
                        icon: const Icon(Icons.qr_code_scanner_rounded, size: 18, color: AppColors.primary),
                        label: const Text(
                          'Open QR Scanner',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildPosterPlaceholder() {
    return Container(
      width: 44,
      height: 62,
      color: AppColors.surfaceElevated,
      child: const Icon(
        Icons.movie_rounded,
        color: AppColors.textMuted,
        size: 22,
      ),
    );
  }
}
