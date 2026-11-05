import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/models/entry.dart';
import '../../../shared/widgets/shared_widgets.dart';

/// A compact, elegant social proof strip displayed on the Movie Details screen
/// when one or more friends have watched/reviewed the title.
///
/// Features an overlapping avatar stack (max 3 displayed + "+N" badge if >3 friends),
/// friendly summary copy, and tap affordance to open the full reviews modal sheet.
class FriendsWatchedBar extends StatelessWidget {
  final List<Entry> friendsEntries;
  final String movieTitle;
  final VoidCallback onTap;

  const FriendsWatchedBar({
    super.key,
    required this.friendsEntries,
    required this.movieTitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (friendsEntries.isEmpty) return const SizedBox.shrink();

    final count = friendsEntries.length;
    final displayEntries = friendsEntries.take(3).toList();
    final remainingCount = count - 3;

    // Calculate average rating among friends who provided a rating
    final ratedEntries = friendsEntries.where((e) => e.rating != null && e.rating! > 0).toList();
    final double? avgRating = ratedEntries.isNotEmpty
        ? ratedEntries.map((e) => e.rating!).reduce((a, b) => a + b) / ratedEntries.length
        : null;

    final primaryText = _buildPrimaryText(count, friendsEntries);
    final secondaryText = _buildSecondaryText(count, friendsEntries);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                // Overlapping Avatar Stack (Max 3 + Optional '+N' Badge)
                _buildAvatarStack(displayEntries, remainingCount),
                const SizedBox(width: 12),

                // Friend Summary Texts
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        primaryText,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (secondaryText != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          secondaryText,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textMuted,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Trailing Pill: Avg Rating or "Reviews" + Chevron
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (avgRating != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star_rounded, size: 13, color: AppColors.primaryDark),
                            const SizedBox(width: 3),
                            Text(
                              avgRating.toStringAsFixed(1),
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primaryDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                    ],
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: AppColors.primary,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarStack(List<Entry> displayEntries, int remainingCount) {
    const double avatarRadius = 14;
    const double overlapOffset = 18.0;

    final itemsCount = displayEntries.length + (remainingCount > 0 ? 1 : 0);
    final totalWidth = 28.0 + (itemsCount - 1) * overlapOffset;

    return SizedBox(
      width: totalWidth,
      height: 32,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.centerLeft,
        children: [
          for (int i = 0; i < displayEntries.length; i++)
            Positioned(
              left: i * overlapOffset,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.surfaceElevated, width: 2),
                ),
                child: WHAvatar(
                  imageUrl: displayEntries[i].user?.profilePictureUrl,
                  name: displayEntries[i].user?.displayName ?? displayEntries[i].user?.username,
                  radius: avatarRadius,
                ),
              ),
            ),
          if (remainingCount > 0)
            Positioned(
              left: displayEntries.length * overlapOffset,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary,
                  border: Border.all(color: AppColors.surfaceElevated, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    '+$remainingCount',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _buildPrimaryText(int count, List<Entry> entries) {
    if (count == 1) {
      final name = entries.first.user?.displayName ?? entries.first.user?.username ?? 'A friend';
      return '$name watched this';
    }
    if (count == 2) {
      final name1 = entries[0].user?.displayName ?? entries[0].user?.username ?? 'Friend 1';
      final name2 = entries[1].user?.displayName ?? entries[1].user?.username ?? 'Friend 2';
      return '$name1 & $name2 watched this';
    }
    return 'Watched by $count friends';
  }

  String? _buildSecondaryText(int count, List<Entry> entries) {
    if (count <= 2) {
      final hasReviews = entries.any((e) => e.review != null && e.review!.trim().isNotEmpty);
      return hasReviews ? 'Tap to view friend reviews' : 'Tap to view details';
    }
    final name1 = entries[0].user?.displayName ?? entries[0].user?.username ?? 'Friend';
    final name2 = entries[1].user?.displayName ?? entries[1].user?.username ?? 'Friend';
    final remaining = count - 2;
    return '$name1, $name2 & $remaining other${remaining > 1 ? 's' : ''}';
  }
}
