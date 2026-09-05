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
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Poster Placeholder
          Expanded(
            child: WHSkeletonBox(
              width: double.infinity,
              height: double.infinity,
              borderRadius: 0,
            ),
          ),
          // Footer Metadata
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
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
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
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
                  child: const Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: WHSkeletonBox(height: 44, borderRadius: 14)),
                          SizedBox(width: 10),
                          Expanded(child: WHSkeletonBox(height: 44, borderRadius: 14)),
                        ],
                      ),
                      SizedBox(height: 10),
                      Row(
                        children: [
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
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                        itemBuilder: (_, __) => const Column(
                          children: [
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
          child: const Row(
            children: [
              WHSkeletonBox(width: 90, height: 56, borderRadius: 10),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
        shrinkWrap: true,
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
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User header
              Row(
                children: [
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
              SizedBox(height: 14),
              // Poster / Backdrop Placeholder
              WHSkeletonBox(width: double.infinity, height: 160, borderRadius: 14),
              SizedBox(height: 12),
              // Review lines
              WHSkeletonBox(width: double.infinity, height: 12, borderRadius: 4),
              SizedBox(height: 6),
              WHSkeletonBox(width: 200, height: 12, borderRadius: 4),
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
              const SafeArea(
                bottom: false,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
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
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    WHSkeletonBox(width: 80, height: 50, borderRadius: 12),
                    WHSkeletonBox(width: 80, height: 50, borderRadius: 12),
                    WHSkeletonBox(width: 80, height: 50, borderRadius: 12),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // Action Buttons Row (Follow / Edit, Compare)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Expanded(child: WHSkeletonBox(height: 40, borderRadius: 12)),
                    SizedBox(width: 10),
                    Expanded(child: WHSkeletonBox(height: 40, borderRadius: 12)),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Tabs Row Placeholder
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
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

/// Skeleton for Comments Sheet
class WHSkeletonCommentsList extends StatelessWidget {
  final int count;
  const WHSkeletonCommentsList({super.key, this.count = 4});

  @override
  Widget build(BuildContext context) {
    return WHSkeleton(
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        physics: const NeverScrollableScrollPhysics(),
        itemCount: count,
        separatorBuilder: (_, __) => const SizedBox(height: 18),
        itemBuilder: (_, __) => const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            WHSkeletonBox(width: 32, height: 32, shape: BoxShape.circle),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      WHSkeletonBox(width: 90, height: 13, borderRadius: 4),
                      SizedBox(width: 6),
                      WHSkeletonBox(width: 36, height: 10, borderRadius: 4),
                    ],
                  ),
                  SizedBox(height: 6),
                  WHSkeletonBox(width: double.infinity, height: 12, borderRadius: 4),
                  SizedBox(height: 5),
                  WHSkeletonBox(width: 180, height: 12, borderRadius: 4),
                  SizedBox(height: 8),
                  WHSkeletonBox(width: 36, height: 10, borderRadius: 4),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Skeleton for MindLens AI Screen
class WHSkeletonMindLens extends StatelessWidget {
  const WHSkeletonMindLens({super.key});

  @override
  Widget build(BuildContext context) {
    return WHSkeleton(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        physics: const NeverScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero AI Persona Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.border),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      WHSkeletonBox(width: 120, height: 24, borderRadius: 12),
                      WHSkeletonBox(width: 60, height: 20, borderRadius: 10),
                    ],
                  ),
                  SizedBox(height: 16),
                  WHSkeletonBox(width: 200, height: 22, borderRadius: 6),
                  SizedBox(height: 10),
                  WHSkeletonBox(width: double.infinity, height: 13, borderRadius: 4),
                  SizedBox(height: 6),
                  WHSkeletonBox(width: 240, height: 13, borderRadius: 4),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 2x2 Stats Grid
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.5,
              children: List.generate(
                4,
                (_) => Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          WHSkeletonBox(width: 28, height: 28, shape: BoxShape.circle),
                          WHSkeletonBox(width: 32, height: 14, borderRadius: 6),
                        ],
                      ),
                      SizedBox(height: 10),
                      WHSkeletonBox(width: 50, height: 18, borderRadius: 4),
                      SizedBox(height: 4),
                      WHSkeletonBox(width: 80, height: 11, borderRadius: 4),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Frequency / Taste Analytics Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      WHSkeletonBox(width: 140, height: 16, borderRadius: 6),
                      WHSkeletonBox(width: 60, height: 22, borderRadius: 10),
                    ],
                  ),
                  SizedBox(height: 20),
                  WHSkeletonBox(width: double.infinity, height: 140, borderRadius: 12),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Highlights Carousel Title + Row
            const WHSkeletonBox(width: 150, height: 16, borderRadius: 6),
            const SizedBox(height: 12),
            SizedBox(
              height: 130,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 3,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (_, __) => Container(
                  width: 110,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: WHSkeletonBox(width: double.infinity, height: double.infinity, borderRadius: 0)),
                      Padding(
                        padding: EdgeInsets.all(8),
                        child: WHSkeletonBox(width: 70, height: 10, borderRadius: 4),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Skeleton for Rankings & Stacks Screen
class WHSkeletonRankings extends StatelessWidget {
  const WHSkeletonRankings({super.key});

  @override
  Widget build(BuildContext context) {
    return WHSkeleton(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        physics: const NeverScrollableScrollPhysics(),
        children: [
          // Horizontal Stack Pills Carousel
          const Row(
            children: [
              WHSkeletonBox(width: 90, height: 34, borderRadius: 12),
              SizedBox(width: 8),
              WHSkeletonBox(width: 110, height: 34, borderRadius: 12),
              SizedBox(width: 8),
              WHSkeletonBox(width: 85, height: 34, borderRadius: 12),
            ],
          ),

          const SizedBox(height: 16),

          // Active Stack Hero Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    WHSkeletonBox(width: 160, height: 20, borderRadius: 6),
                    WHSkeletonBox(width: 60, height: 22, borderRadius: 10),
                  ],
                ),
                SizedBox(height: 10),
                WHSkeletonBox(width: double.infinity, height: 12, borderRadius: 4),
                SizedBox(height: 6),
                WHSkeletonBox(width: 180, height: 12, borderRadius: 4),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Ranked items
          const WHSkeletonRankedItemList(itemCount: 4),
        ],
      ),
    );
  }
}

/// Skeleton list of ranked item cards
class WHSkeletonRankedItemList extends StatelessWidget {
  final int itemCount;
  const WHSkeletonRankedItemList({super.key, this.itemCount = 4});

  @override
  Widget build(BuildContext context) {
    return WHSkeleton(
      child: Column(
        children: List.generate(
          itemCount,
          (_) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: const Row(
                children: [
                  WHSkeletonBox(width: 28, height: 28, borderRadius: 8),
                  SizedBox(width: 12),
                  WHSkeletonBox(width: 48, height: 68, borderRadius: 8),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        WHSkeletonBox(width: 140, height: 14, borderRadius: 4),
                        SizedBox(height: 8),
                        Row(
                          children: [
                            WHSkeletonBox(width: 40, height: 16, borderRadius: 6),
                            SizedBox(width: 6),
                            WHSkeletonBox(width: 45, height: 16, borderRadius: 6),
                          ],
                        ),
                      ],
                    ),
                  ),
                  WHSkeletonBox(width: 18, height: 18, borderRadius: 4),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Skeleton for Compare Taste Screen
class WHSkeletonCompare extends StatelessWidget {
  const WHSkeletonCompare({super.key});

  @override
  Widget build(BuildContext context) {
    return WHSkeleton(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        physics: const NeverScrollableScrollPhysics(),
        child: Column(
          children: [
            // Top Hero Card (VS Avatars + Match % + Stats)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.border),
              ),
              child: const Column(
                children: [
                  // Dual Avatars + VS
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      WHSkeletonBox(width: 54, height: 54, shape: BoxShape.circle),
                      SizedBox(width: 16),
                      WHSkeletonBox(width: 32, height: 32, shape: BoxShape.circle),
                      SizedBox(width: 16),
                      WHSkeletonBox(width: 54, height: 54, shape: BoxShape.circle),
                    ],
                  ),
                  SizedBox(height: 16),
                  // Match % Pill
                  WHSkeletonBox(width: 110, height: 26, borderRadius: 13),
                  SizedBox(height: 16),
                  // 3-Column Stats Box
                  Row(
                    children: [
                      Expanded(child: WHSkeletonBox(height: 52, borderRadius: 12)),
                      SizedBox(width: 8),
                      Expanded(child: WHSkeletonBox(height: 52, borderRadius: 12)),
                      SizedBox(width: 8),
                      Expanded(child: WHSkeletonBox(height: 52, borderRadius: 12)),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 3 Segmented Filter Tabs
            const Row(
              children: [
                Expanded(child: WHSkeletonBox(height: 38, borderRadius: 12)),
                SizedBox(width: 8),
                Expanded(child: WHSkeletonBox(height: 38, borderRadius: 12)),
                SizedBox(width: 8),
                Expanded(child: WHSkeletonBox(height: 38, borderRadius: 12)),
              ],
            ),

            const SizedBox(height: 16),

            // Comparison Items
            ...List.generate(
              3,
              (_) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Row(
                    children: [
                      WHSkeletonBox(width: 54, height: 78, borderRadius: 10),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            WHSkeletonBox(width: 140, height: 14, borderRadius: 4),
                            SizedBox(height: 8),
                            WHSkeletonBox(width: 60, height: 16, borderRadius: 6),
                            SizedBox(height: 10),
                            Row(
                              children: [
                                WHSkeletonBox(width: 70, height: 18, borderRadius: 6),
                                SizedBox(width: 8),
                                WHSkeletonBox(width: 70, height: 18, borderRadius: 6),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Skeleton for User Lists (Followers, Following, Compare Picker, Friend Search)
class WHSkeletonUserList extends StatelessWidget {
  final int count;
  final EdgeInsetsGeometry padding;

  const WHSkeletonUserList({
    super.key,
    this.count = 5,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  });

  @override
  Widget build(BuildContext context) {
    return WHSkeleton(
      child: ListView.separated(
        shrinkWrap: true,
        padding: padding,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: count,
        separatorBuilder: (_, __) => const SizedBox(height: 14),
        itemBuilder: (_, __) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: const Row(
            children: [
              WHSkeletonBox(width: 42, height: 42, shape: BoxShape.circle),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    WHSkeletonBox(width: 110, height: 14, borderRadius: 4),
                    SizedBox(height: 5),
                    WHSkeletonBox(width: 70, height: 11, borderRadius: 4),
                  ],
                ),
              ),
              WHSkeletonBox(width: 68, height: 30, borderRadius: 15),
            ],
          ),
        ),
      ),
    );
  }
}

/// Skeleton for Media Search Results (Quick Add, Currently Watching, Suggest Media)
class WHSkeletonMediaSearchList extends StatelessWidget {
  final int count;
  const WHSkeletonMediaSearchList({super.key, this.count = 5});

  @override
  Widget build(BuildContext context) {
    return WHSkeleton(
      child: ListView.separated(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        physics: const NeverScrollableScrollPhysics(),
        itemCount: count,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, __) => Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: const Row(
            children: [
              WHSkeletonBox(width: 44, height: 64, borderRadius: 8),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    WHSkeletonBox(width: 140, height: 14, borderRadius: 4),
                    SizedBox(height: 6),
                    Row(
                      children: [
                        WHSkeletonBox(width: 46, height: 16, borderRadius: 6),
                        SizedBox(width: 6),
                        WHSkeletonBox(width: 36, height: 12, borderRadius: 4),
                      ],
                    ),
                    SizedBox(height: 6),
                    WHSkeletonBox(width: double.infinity, height: 10, borderRadius: 4),
                  ],
                ),
              ),
              SizedBox(width: 8),
              WHSkeletonBox(width: 24, height: 24, shape: BoxShape.circle),
            ],
          ),
        ),
      ),
    );
  }
}

/// Horizontal skeleton for Suggested Users in SearchScreen
class WHSkeletonSuggestedUsersHorizontal extends StatelessWidget {
  const WHSkeletonSuggestedUsersHorizontal({super.key});

  @override
  Widget build(BuildContext context) {
    return WHSkeleton(
      child: SizedBox(
        height: 148,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 4,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (_, __) => Container(
            width: 110,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                WHSkeletonBox(width: 44, height: 44, shape: BoxShape.circle),
                SizedBox(height: 8),
                WHSkeletonBox(width: 70, height: 12, borderRadius: 4),
                SizedBox(height: 4),
                WHSkeletonBox(width: 50, height: 10, borderRadius: 4),
                SizedBox(height: 10),
                WHSkeletonBox(width: 65, height: 22, borderRadius: 11),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Skeleton for AddToStackSheet stack list
class WHSkeletonStackList extends StatelessWidget {
  final int count;
  const WHSkeletonStackList({super.key, this.count = 3});

  @override
  Widget build(BuildContext context) {
    return WHSkeleton(
      child: ListView.separated(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        physics: const NeverScrollableScrollPhysics(),
        itemCount: count,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, __) => Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: const Row(
            children: [
              WHSkeletonBox(width: 36, height: 36, borderRadius: 10),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    WHSkeletonBox(width: 120, height: 14, borderRadius: 4),
                    SizedBox(height: 4),
                    WHSkeletonBox(width: 60, height: 11, borderRadius: 4),
                  ],
                ),
              ),
              WHSkeletonBox(width: 18, height: 18, shape: BoxShape.circle),
            ],
          ),
        ),
      ),
    );
  }
}

/// Skeleton footer for pagination load-more in feed
class WHSkeletonFeedFooter extends StatelessWidget {
  const WHSkeletonFeedFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return WHSkeleton(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: const Row(
          children: [
            WHSkeletonBox(width: 36, height: 36, shape: BoxShape.circle),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  WHSkeletonBox(width: 120, height: 13, borderRadius: 4),
                  SizedBox(height: 5),
                  WHSkeletonBox(width: 80, height: 10, borderRadius: 4),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Skeleton for Profile Analytics & Stats View
class WHSkeletonProfileStats extends StatelessWidget {
  const WHSkeletonProfileStats({super.key});

  @override
  Widget build(BuildContext context) {
    return WHSkeleton(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 3 Summary Cards
          const Row(
            children: [
              Expanded(child: WHSkeletonBox(height: 70, borderRadius: 16)),
              SizedBox(width: 10),
              Expanded(child: WHSkeletonBox(height: 70, borderRadius: 16)),
              SizedBox(width: 10),
              Expanded(child: WHSkeletonBox(height: 70, borderRadius: 16)),
            ],
          ),
          const SizedBox(height: 16),
          // Media Breakdown Card Placeholder
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                WHSkeletonBox(width: 120, height: 14, borderRadius: 4),
                SizedBox(height: 14),
                WHSkeletonBox(width: double.infinity, height: 12, borderRadius: 6),
                SizedBox(height: 14),
                Row(
                  children: [
                    WHSkeletonBox(width: 80, height: 12, borderRadius: 4),
                    Spacer(),
                    WHSkeletonBox(width: 80, height: 12, borderRadius: 4),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Genre Chart Container Placeholder
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                WHSkeletonBox(width: 130, height: 14, borderRadius: 4),
                SizedBox(height: 16),
                WHSkeletonBox(width: double.infinity, height: 100, borderRadius: 10),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

