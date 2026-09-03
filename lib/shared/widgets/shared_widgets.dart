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
export 'wh_rating_picker.dart';
export 'wh_quick_add_fab.dart';
export 'wh_skeleton.dart';


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
    final url = posterPath != null ? ApiEndpoints.tmdbPoster(posterPath) : null;

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: url != null
          ? CachedNetworkImage(
              imageUrl: url,
              width: width,
              height: height,
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
        child: Container(width: width, height: height, color: AppColors.surfaceElevated),
      );

  Widget _placeholder() => Container(
        width: width,
        height: height,
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

  bool _isValidUrl(String? url) {
    if (url == null || url.isEmpty) return false;
    return url.startsWith('http://') || url.startsWith('https://');
  }

  @override
  Widget build(BuildContext context) {
    final resolvedUrl = ApiEndpoints.resolveAvatarUrl(imageUrl);
    if (resolvedUrl.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: CachedNetworkImageProvider(resolvedUrl),
        backgroundColor: AppColors.surfaceElevated,
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.primary.withOpacity(0.2),
      child: Text(
        (name?.isNotEmpty == true ? name![0] : '?').toUpperCase(),
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: radius * 0.8,
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
        ),
      ),
    );
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
          color: selected ? AppColors.primary.withOpacity(0.2) : AppColors.surfaceElevated,
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
