import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/models/user.dart';

class HoneyBadgeItem {
  final String id;
  final String name;
  final String description;
  final String emoji;
  final IconData icon;

  const HoneyBadgeItem({
    required this.id,
    required this.name,
    required this.description,
    required this.emoji,
    required this.icon,
  });
}

class HoneyBadgesDialog extends StatelessWidget {
  final User user;

  const HoneyBadgesDialog({super.key, required this.user});

  static const List<HoneyBadgeItem> standardBadges = [
    HoneyBadgeItem(
      id: 'pioneer',
      name: 'First Log',
      description: 'Log your first watch entry',
      emoji: '🎬',
      icon: Icons.play_circle_fill_rounded,
    ),
    HoneyBadgeItem(
      id: 'century_watcher',
      name: 'Century Watcher',
      description: 'Log your 100th watch entry',
      emoji: '💯',
      icon: Icons.military_tech_rounded,
    ),
    HoneyBadgeItem(
      id: 'suggestion_starter',
      name: 'Suggestion Starter',
      description: 'Complete 1 suggestion from a friend',
      emoji: '🤝',
      icon: Icons.recommend_rounded,
    ),
    HoneyBadgeItem(
      id: 'suggestion_veteran',
      name: 'Suggestion Veteran',
      description: 'Complete 100 suggestions',
      emoji: '🌟',
      icon: Icons.stars_rounded,
    ),
    HoneyBadgeItem(
      id: 'streak_10',
      name: 'Serious Watcher',
      description: 'Watch for 10 days in a row',
      emoji: '🔥',
      icon: Icons.local_fire_department_rounded,
    ),
    HoneyBadgeItem(
      id: 'streak_20',
      name: 'Jobless',
      description: 'Watch for 20 days in a row',
      emoji: '🌋',
      icon: Icons.whatshot_rounded,
    ),
    HoneyBadgeItem(
      id: 'streak_30',
      name: 'Maniac',
      description: '30-day watching streak',
      emoji: '⚡',
      icon: Icons.bolt_rounded,
    ),
  ];

  static void show(BuildContext context, User user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => HoneyBadgesDialog(user: user),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Map earned badges by ID
    final earnedMap = <String, dynamic>{};
    for (final b in user.badges) {
      if (b is Map) {
        final id = b['id']?.toString() ?? '';
        earnedMap[id] = b;
        if (id == 'first_log') {
          earnedMap['pioneer'] = b;
        }
      } else if (b is String) {
        earnedMap[b] = {'id': b};
        if (b == 'first_log') {
          earnedMap['pioneer'] = {'id': b};
        }
      }
    }

    final totalStandard = standardBadges.length;
    final earnedCount = standardBadges.where((b) => earnedMap.containsKey(b.id)).length;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.82,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.displayName != null && user.displayName!.isNotEmpty
                          ? "${user.displayName}'s Badges"
                          : 'Honey Level Badges',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$earnedCount of $totalStandard UNLOCKED',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: AppColors.primaryDark,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: 'Close',
                ),
              ],
            ),
          ),

          // Streak Banner if user has active streak
          if (user.watchStreak > 0)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.16),
                    AppColors.primary.withValues(alpha: 0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Text('🔥', style: TextStyle(fontSize: 22)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${user.watchStreak} ${user.watchStreak == 1 ? 'Day' : 'Days'} Watch Streak Active!',
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primaryDark,
                          ),
                        ),
                        const Text(
                          'Log daily watches to level up your streak badges',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          const Divider(height: 16, color: AppColors.border),

          // Badges List
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              itemCount: standardBadges.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (ctx, index) {
                final badge = standardBadges[index];
                final isEarned = earnedMap.containsKey(badge.id);
                final earnedData = earnedMap[badge.id];

                String? unlockedDateStr;
                if (earnedData is Map && earnedData['unlockedAt'] != null) {
                  try {
                    final dt = DateTime.parse(earnedData['unlockedAt'].toString());
                    unlockedDateStr = '${dt.day}/${dt.month}/${dt.year}';
                  } catch (_) {}
                }

                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isEarned
                        ? AppColors.primary.withValues(alpha: 0.08)
                        : AppColors.surfaceElevated.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isEarned
                          ? AppColors.primary.withValues(alpha: 0.35)
                          : AppColors.border.withValues(alpha: 0.5),
                      width: isEarned ? 1.2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      // Badge icon / emoji box
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: isEarned
                              ? AppColors.primary.withValues(alpha: 0.22)
                              : AppColors.border.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: isEarned
                            ? Text(badge.emoji, style: const TextStyle(fontSize: 22))
                            : const Icon(Icons.lock_outline_rounded, size: 20, color: AppColors.textSecondary),
                      ),
                      const SizedBox(width: 14),

                      // Details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    badge.name,
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: isEarned ? AppColors.textPrimary : AppColors.textSecondary,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (isEarned) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'EARNED',
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 9,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.5,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              badge.description,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 11,
                                color: isEarned ? AppColors.textSecondary : AppColors.textSecondary.withValues(alpha: 0.7),
                              ),
                            ),
                            if (unlockedDateStr != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                'Unlocked $unlockedDateStr',
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primaryDark,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // Footer info
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.border, width: 0.6)),
            ),
            alignment: Alignment.center,
            child: const Text(
              'Honey Levels • Log watches & suggestions to grow the hive',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
