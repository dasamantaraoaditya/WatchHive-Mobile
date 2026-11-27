import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/theme/app_colors.dart';
import '../../core/api/api_endpoints.dart';
export 'wh_alert.dart';
export 'wh_button.dart';
export 'wh_text_field.dart';
export 'wh_logo_header.dart';
export 'wh_brand_logo.dart';
export 'wh_app_logo_loader.dart';
export 'wh_rating_picker.dart';
export 'wh_quick_add_fab.dart';
export 'wh_skeleton.dart';
export 'wh_bee_loader.dart';
export 'wh_filter_bar.dart';
export 'wh_google_button.dart';
export 'ugc_moderation_dialog.dart';


class TMDBPosterImage extends StatelessWidget {
  final String? posterPath;
  final double width;
  final double height;
  final double borderRadius;

  const TMDBPosterImage({
    super.key,
    required this.posterPath,
    this.width = 80,
    this.height = 120,
    this.borderRadius = 8,
  });

  @override
  Widget build(BuildContext context) {
    final cleanPath = (posterPath != null &&
            posterPath!.trim().isNotEmpty &&
            posterPath != 'null' &&
            posterPath != 'undefined')
        ? posterPath!.trim()
        : null;
    final url = cleanPath != null ? ApiEndpoints.tmdbPoster(cleanPath) : '';
    final hasValidUrl = url.isNotEmpty;

    final memW = width.isFinite && !width.isNaN && width > 0
        ? (width * 3).toInt().clamp(60, 600)
        : 600;
    final memH = height.isFinite && !height.isNaN && height > 0
        ? (height * 3).toInt().clamp(90, 900)
        : 900;

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: hasValidUrl
          ? CachedNetworkImage(
              imageUrl: url,
              width: width,
              height: height,
              memCacheWidth: memW,
              memCacheHeight: memH,
              maxWidthDiskCache: 600,
              maxHeightDiskCache: 900,
              fit: BoxFit.cover,
              placeholder: (context, url) => _shimmer(),
              errorWidget: (context, url, error) => _placeholder(),
            )
          : _placeholder(),
    );
  }

  Widget _shimmer() => Shimmer.fromColors(
        baseColor: AppColors.surfaceElevated,
        highlightColor: AppColors.surfaceHighest,
        child: Container(
          width: width.isFinite ? width : null,
          height: height.isFinite ? height : null,
          color: AppColors.surfaceElevated,
        ),
      );

  Widget _placeholder() => Container(
        width: width.isFinite ? width : null,
        height: height.isFinite ? height : null,
        color: AppColors.surfaceElevated,
        child: const Center(
          child: Icon(Icons.movie_creation_outlined, color: AppColors.textMuted, size: 28),
        ),
      );
}

class WHAvatar extends StatelessWidget {
  final String? imageUrl;
  final String? name;
  final double radius;

  const WHAvatar({super.key, this.imageUrl, this.name, this.radius = 20});

  Widget _buildFallback() {
    return CircleAvatar(
      radius: radius.isFinite ? radius : 20,
      backgroundColor: AppColors.primary.withValues(alpha: 0.2),
      child: Text(
        (name?.isNotEmpty == true ? name![0] : '?').toUpperCase(),
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: (radius.isFinite ? radius : 20) * 0.8,
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final resolvedUrl = ApiEndpoints.resolveAvatarUrl(imageUrl);
    if (resolvedUrl.isNotEmpty) {
      final pixelSize = radius.isFinite && !radius.isNaN && radius > 0
          ? (radius * 4).toInt().clamp(64, 256)
          : 128;
      return CachedNetworkImage(
        imageUrl: resolvedUrl,
        memCacheWidth: pixelSize,
        memCacheHeight: pixelSize,
        maxWidthDiskCache: 256,
        maxHeightDiskCache: 256,
        imageBuilder: (context, imageProvider) => CircleAvatar(
          radius: radius.isFinite ? radius : 20,
          backgroundImage: imageProvider,
          backgroundColor: AppColors.surfaceElevated,
        ),
        placeholder: (context, url) => _buildFallback(),
        errorWidget: (context, url, error) => _buildFallback(),
      );
    }
    return _buildFallback();
  }
}

class WHChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  const WHChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withValues(alpha: 0.2) : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? AppColors.primary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class WHRatingStars extends StatelessWidget {
  final double? rating;
  final double size;

  const WHRatingStars({super.key, this.rating, this.size = 14});

  @override
  Widget build(BuildContext context) {
    if (rating == null) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.star_rounded, color: AppColors.primary, size: size),
        const SizedBox(width: 3),
        Text(
          rating!.toStringAsFixed(1),
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: size - 2,
            fontWeight: FontWeight.w600,
            color: AppColors.primary,
          ),
        ),
      ],
    );
  }
}
