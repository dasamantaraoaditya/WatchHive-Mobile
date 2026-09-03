import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/theme/app_colors.dart';

/// Base Shimmer Wrapper following WatchHive signature warm honey theme
class WHSkeleton extends StatelessWidget {
  final Widget child;

  const WHSkeleton({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFECE6DC),
      highlightColor: const Color(0xFFF9F6F0),
      period: const Duration(milliseconds: 1400),
      child: child,
    );
  }
}

/// Primitive skeleton placeholder box
class WHSkeletonBox extends StatelessWidget {
  final double? width;
  final double? height;
  final double borderRadius;
  final BoxShape shape;

  const WHSkeletonBox({
    super.key,
    this.width,
    this.height,
    this.borderRadius = 8,
    this.shape = BoxShape.rectangle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFECE6DC),
        shape: shape,
        borderRadius: shape == BoxShape.circle ? null : BorderRadius.circular(borderRadius),
      ),
    );
  }
}

/// Skeleton for 2-column WHEntryGridCard
class WHSkeletonCard extends StatelessWidget {
  const WHSkeletonCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Poster Placeholder
          const Expanded(
            child: WHSkeletonBox(
              width: double.infinity,
              height: double.infinity,
              borderRadius: 0,
            ),
          ),
          // Footer Metadata
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: const [
                WHSkeletonBox(width: 14, height: 14, borderRadius: 4),
                SizedBox(width: 6),
                WHSkeletonBox(width: 70, height: 12, borderRadius: 4),
                Spacer(),
                WHSkeletonBox(width: 16, height: 16, borderRadius: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 2-Column Grid of Skeleton Cards (for Entries, Watchlist, Suggestions, Profile)
class WHSkeletonGrid extends StatelessWidget {
  final int itemCount;
  final EdgeInsetsGeometry padding;

  const WHSkeletonGrid({
    super.key,
    this.itemCount = 6,
    this.padding = const EdgeInsets.fromLTRB(16, 16, 16, 100),
  });

  @override
  Widget build(BuildContext context) {
    return WHSkeleton(
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: padding,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: 0.63,
        ),
        itemCount: itemCount,
        itemBuilder: (_, __) => const WHSkeletonCard(),
      ),
    );
  }
}

/// Skeleton for Movie & TV Show Details Screen
class WHSkeletonMovieDetails extends StatelessWidget {
  const WHSkeletonMovieDetails({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: WHSkeleton(
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Hero Backdrop + Poster Header
              Stack(
                clipBehavior: Clip.none,
                children: [
                  // Backdrop
                  Container(
                    height: 280,
                    width: double.infinity,
                    color: const Color(0xFFECE6DC),
                  ),
                  // Back Button Placeholder
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.3),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                  // Floating Poster & Main Info
                  Positioned(
                    bottom: -30,
                    left: 16,
                    right: 16,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // Poster
                        Container(
                          width: 90,
                          height: 135,
                          decoration: BoxDecoration(
                            color: const Color(0xFFECE6DC),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.white, width: 2.5),
                          ),
                        ),
                        const SizedBox(width: 14),
                        // Title, Year, Genres
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              WHSkeletonBox(width: 180, height: 20, borderRadius: 6),
                              SizedBox(height: 8),
                              WHSkeletonBox(width: 100, height: 14, borderRadius: 4),
                              SizedBox(height: 8),
                              Row(
                                children: [
                                  WHSkeletonBox(width: 50, height: 18, borderRadius: 6),
                                  SizedBox(width: 6),
                                  WHSkeletonBox(width: 50, height: 18, borderRadius: 6),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 48),

              // 2. Action Bar Placeholder (Watchlist + Log Watch + Suggest + Rank)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: const [
                          Expanded(child: WHSkeletonBox(height: 44, borderRadius: 14)),
                          SizedBox(width: 10),
                          Expanded(child: WHSkeletonBox(height: 44, borderRadius: 14)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: const [
                          Expanded(child: WHSkeletonBox(height: 42, borderRadius: 14)),
                          SizedBox(width: 10),
                          Expanded(child: WHSkeletonBox(height: 42, borderRadius: 14)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // 3. Overview Paragraph Placeholder
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    WHSkeletonBox(width: 100, height: 18, borderRadius: 4),
                    SizedBox(height: 12),
                    WHSkeletonBox(width: double.infinity, height: 13, borderRadius: 4),
                    SizedBox(height: 6),
                    WHSkeletonBox(width: double.infinity, height: 13, borderRadius: 4),
                    SizedBox(height: 6),
                    WHSkeletonBox(width: 220, height: 13, borderRadius: 4),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // 4. Cast Carousel Placeholder
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const WHSkeletonBox(width: 130, height: 18, borderRadius: 4),
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 100,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: 5,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (_, __) => Column(
                          children: const [
                            WHSkeletonBox(width: 60, height: 60, shape: BoxShape.circle),
                            SizedBox(height: 8),
                            WHSkeletonBox(width: 50, height: 10, borderRadius: 4),
                          ],
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
    );
  }
}

/// Skeleton for TV Season Episodes
class WHSkeletonEpisodeList extends StatelessWidget {
  final int count;

  const WHSkeletonEpisodeList({super.key, this.count = 4});

  @override
  Widget build(BuildContext context) {
    return WHSkeleton(
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: count,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, __) => Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              const WHSkeletonBox(width: 90, height: 56, borderRadius: 10),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    WHSkeletonBox(width: 140, height: 14, borderRadius: 4),
                    SizedBox(height: 6),
                    WHSkeletonBox(width: 80, height: 11, borderRadius: 4),
                    SizedBox(height: 6),
                    WHSkeletonBox(width: double.infinity, height: 10, borderRadius: 4),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Skeleton for Community Feed Screen
class WHSkeletonFeed extends StatelessWidget {
  final int itemCount;

  const WHSkeletonFeed({super.key, this.itemCount = 3});

  @override
  Widget build(BuildContext context) {
    return WHSkeleton(
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
        physics: const NeverScrollableScrollPhysics(),
        itemCount: itemCount,
        separatorBuilder: (_, __) => const SizedBox(height: 16),
        itemBuilder: (_, __) => Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User header
              Row(
                children: const [
                  WHSkeletonBox(width: 40, height: 40, shape: BoxShape.circle),
                  SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      WHSkeletonBox(width: 120, height: 14, borderRadius: 4),
                      SizedBox(height: 4),
                      WHSkeletonBox(width: 70, height: 10, borderRadius: 4),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // Poster / Backdrop Placeholder
              const WHSkeletonBox(width: double.infinity, height: 160, borderRadius: 14),
              const SizedBox(height: 12),
              // Review lines
              const WHSkeletonBox(width: double.infinity, height: 12, borderRadius: 4),
              const SizedBox(height: 6),
              const WHSkeletonBox(width: 200, height: 12, borderRadius: 4),
            ],
          ),
        ),
      ),
    );
  }
}

/// Skeleton for Profile Screen
class WHSkeletonProfile extends StatelessWidget {
  const WHSkeletonProfile({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: WHSkeleton(
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: Column(
            children: [
              // Top App Bar Placeholder
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      WHSkeletonBox(width: 36, height: 36, shape: BoxShape.circle),
                      WHSkeletonBox(width: 100, height: 18, borderRadius: 6),
                      WHSkeletonBox(width: 36, height: 36, shape: BoxShape.circle),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Avatar
              const WHSkeletonBox(width: 88, height: 88, shape: BoxShape.circle),
              const SizedBox(height: 14),

              // Name & Username
              const WHSkeletonBox(width: 160, height: 20, borderRadius: 6),
              const SizedBox(height: 8),
              const WHSkeletonBox(width: 90, height: 13, borderRadius: 4),
              const SizedBox(height: 12),

              // Bio
              const WHSkeletonBox(width: 240, height: 12, borderRadius: 4),
              const SizedBox(height: 18),

              // Stats Row (Followers, Following, Entries)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: const [
                    WHSkeletonBox(width: 80, height: 50, borderRadius: 12),
                    WHSkeletonBox(width: 80, height: 50, borderRadius: 12),
                    WHSkeletonBox(width: 80, height: 50, borderRadius: 12),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // Action Buttons Row (Follow / Edit, Compare)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: const [
                    Expanded(child: WHSkeletonBox(height: 40, borderRadius: 12)),
                    SizedBox(width: 10),
                    Expanded(child: WHSkeletonBox(height: 40, borderRadius: 12)),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Tabs Row Placeholder
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: const [
                    Expanded(child: WHSkeletonBox(height: 36, borderRadius: 10)),
                    SizedBox(width: 8),
                    Expanded(child: WHSkeletonBox(height: 36, borderRadius: 10)),
                    SizedBox(width: 8),
                    Expanded(child: WHSkeletonBox(height: 36, borderRadius: 10)),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Grid cards
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: 0.63,
                  ),
                  itemCount: 4,
                  itemBuilder: (_, __) => const WHSkeletonCard(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
