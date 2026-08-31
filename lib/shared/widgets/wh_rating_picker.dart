import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';

class WHRatingMoodInfo {
  final IconData icon;
  final Color color;
  final Color bgColor;
  final Color borderColor;
  final String text;

  const WHRatingMoodInfo({
    required this.icon,
    required this.color,
    required this.bgColor,
    required this.borderColor,
    required this.text,
  });
}

class WHRatingPicker extends StatefulWidget {
  final double rating; // 0.0 to 10.0
  final ValueChanged<double> onRatingChanged;
  final bool enabled;

  const WHRatingPicker({
    super.key,
    required this.rating,
    required this.onRatingChanged,
    this.enabled = true,
  });

  static WHRatingMoodInfo getMoodInfo(double rating) {
    if (rating <= 0) {
      return const WHRatingMoodInfo(
        icon: Icons.rate_review_rounded,
        color: AppColors.textMuted,
        bgColor: AppColors.surface,
        borderColor: AppColors.border,
        text: 'Tap or drag stars above to score',
      );
    }
    if (rating <= 2.0) {
      return WHRatingMoodInfo(
        icon: Icons.sentiment_very_dissatisfied_rounded,
        color: const Color(0xFFEF4444),
        bgColor: const Color(0xFFEF4444).withValues(alpha: 0.1),
        borderColor: const Color(0xFFEF4444).withValues(alpha: 0.3),
        text: 'Disaster / Complete Waste of Time 🗑️',
      );
    }
    if (rating <= 4.0) {
      return WHRatingMoodInfo(
        icon: Icons.sentiment_dissatisfied_rounded,
        color: const Color(0xFFF97316),
        bgColor: const Color(0xFFF97316).withValues(alpha: 0.1),
        borderColor: const Color(0xFFF97316).withValues(alpha: 0.3),
        text: 'Poor / Not Recommended 👎',
      );
    }
    if (rating <= 5.5) {
      return WHRatingMoodInfo(
        icon: Icons.sentiment_neutral_rounded,
        color: const Color(0xFFEAB308),
        bgColor: const Color(0xFFEAB308).withValues(alpha: 0.1),
        borderColor: const Color(0xFFEAB308).withValues(alpha: 0.3),
        text: 'Mediocre / Average 🍿',
      );
    }
    if (rating <= 7.0) {
      return WHRatingMoodInfo(
        icon: Icons.sentiment_satisfied_rounded,
        color: const Color(0xFF84CC16),
        bgColor: const Color(0xFF84CC16).withValues(alpha: 0.1),
        borderColor: const Color(0xFF84CC16).withValues(alpha: 0.3),
        text: 'Decent / Enjoyable 👍',
      );
    }
    if (rating <= 8.5) {
      return WHRatingMoodInfo(
        icon: Icons.sentiment_very_satisfied_rounded,
        color: const Color(0xFF10B981),
        bgColor: const Color(0xFF10B981).withValues(alpha: 0.1),
        borderColor: const Color(0xFF10B981).withValues(alpha: 0.3),
        text: 'Excellent / Highly Recommended 🔥',
      );
    }
    if (rating <= 9.5) {
      return WHRatingMoodInfo(
        icon: Icons.grade_rounded,
        color: AppColors.primary,
        bgColor: AppColors.primary.withValues(alpha: 0.12),
        borderColor: AppColors.primary.withValues(alpha: 0.4),
        text: 'Outstanding / Near Flawless 🌟',
      );
    }
    return WHRatingMoodInfo(
      icon: Icons.emoji_events_rounded,
      color: const Color(0xFFFFD700),
      bgColor: const Color(0xFFFFD700).withValues(alpha: 0.16),
      borderColor: const Color(0xFFFFD700).withValues(alpha: 0.5),
      text: 'Absolute Masterpiece / Cinematic Perfection 🏆',
    );
  }

  @override
  State<WHRatingPicker> createState() => _WHRatingPickerState();
}

class _WHRatingPickerState extends State<WHRatingPicker> {
  final GlobalKey _starRowKey = GlobalKey();

  void _updateFromPosition(double localX, double width) {
    if (!widget.enabled || width <= 0) return;
    final fraction = (localX / width).clamp(0.0, 1.0);
    // 0 to 10 scale with 0.5 steps
    final rawScore = fraction * 10.0;
    final snappedScore = (rawScore * 2).round() / 2.0;
    final clamped = snappedScore.clamp(0.5, 10.0);

    if (clamped != widget.rating) {
      HapticFeedback.selectionClick();
      widget.onRatingChanged(clamped);
    }
  }

  void _adjustRating(double delta) {
    if (!widget.enabled) return;
    final newScore = ((widget.rating + delta) * 2).round() / 2.0;
    final clamped = newScore.clamp(0.0, 10.0);
    if (clamped != widget.rating) {
      HapticFeedback.lightImpact();
      widget.onRatingChanged(clamped);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rating = widget.rating;
    final mood = WHRatingPicker.getMoodInfo(rating);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: rating > 0 ? AppColors.primary.withValues(alpha: 0.35) : AppColors.border,
          width: rating > 0 ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
          if (rating >= 8.5)
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.12),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Top Row: Score Display + Steppers + Reset ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Decrement Button (-0.5)
              _StepButton(
                icon: Icons.remove_rounded,
                tooltip: '-0.5',
                enabled: widget.enabled && rating > 0,
                onTap: () => _adjustRating(-0.5),
              ),

              // Center Score Card
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: rating > 0 ? AppColors.primary.withValues(alpha: 0.6) : AppColors.border,
                    width: 1.5,
                  ),
                  boxShadow: [
                    if (rating > 0)
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.18),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Icon(
                      Icons.star_rounded,
                      size: 24,
                      color: rating > 0 ? AppColors.primary : AppColors.textMuted,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      rating > 0 ? rating.toStringAsFixed(1) : '—.—',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: rating > 0 ? AppColors.primary : AppColors.textMuted,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      '/ 10',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),

              // Increment Button (+0.5)
              _StepButton(
                icon: Icons.add_rounded,
                tooltip: '+0.5',
                enabled: widget.enabled && rating < 10.0,
                onTap: () => _adjustRating(0.5),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // ── Interactive 5-Star Row (Gesture-Driven Fractional Fill) ──
          GestureDetector(
            onHorizontalDragUpdate: (details) {
              final box = _starRowKey.currentContext?.findRenderObject() as RenderBox?;
              if (box != null) {
                final localPos = box.globalToLocal(details.globalPosition);
                _updateFromPosition(localPos.dx, box.size.width);
              }
            },
            onTapDown: (details) {
              final box = _starRowKey.currentContext?.findRenderObject() as RenderBox?;
              if (box != null) {
                final localPos = box.globalToLocal(details.globalPosition);
                _updateFromPosition(localPos.dx, box.size.width);
              }
            },
            child: Container(
              key: _starRowKey,
              color: Colors.transparent,
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  // Each star spans 2.0 points (0..2, 2..4, 4..6, 6..8, 8..10)
                  final starFloor = index * 2.0;
                  final starScore = rating - starFloor;

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: _buildFractionalStar(starScore),
                  );
                }),
              ),
            ),
          ),

          const SizedBox(height: 14),

          // ── Quick-Select Preset Chips ──
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildPresetChip('5.0', '🍿 Avg', 5.0),
                const SizedBox(width: 8),
                _buildPresetChip('7.0', '👍 Good', 7.0),
                const SizedBox(width: 8),
                _buildPresetChip('8.5', '🔥 Great', 8.5),
                const SizedBox(width: 8),
                _buildPresetChip('10.0', '🏆 Masterpiece', 10.0),
                if (rating > 0) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      widget.onRatingChanged(0.0);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.withValues(alpha: 0.25)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.clear_rounded, size: 13, color: Colors.redAccent),
                          SizedBox(width: 4),
                          Text(
                            'Reset',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.redAccent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── Cinephile Mood Sentiment Banner ──
          AnimatedContainer(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: mood.bgColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: mood.borderColor, width: 1.2),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(mood.icon, color: mood.color, size: 18),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    mood.text,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: rating > 0 ? AppColors.textPrimary : AppColors.textMuted,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFractionalStar(double fillAmount) {
    // fillAmount: < 0 (empty), 0.5..1.0 (half), >= 1.5 (full)
    IconData iconData;
    Color iconColor;

    if (fillAmount >= 1.5) {
      iconData = Icons.star_rounded;
      iconColor = AppColors.primary;
    } else if (fillAmount >= 0.5) {
      iconData = Icons.star_half_rounded;
      iconColor = AppColors.primary;
    } else {
      iconData = Icons.star_outline_rounded;
      iconColor = AppColors.textMuted.withValues(alpha: 0.35);
    }

    return AnimatedScale(
      scale: fillAmount >= 0.5 ? 1.08 : 1.0,
      duration: const Duration(milliseconds: 160),
      child: Icon(
        iconData,
        size: 38,
        color: iconColor,
        shadows: fillAmount >= 0.5
            ? [
                Shadow(
                  color: AppColors.primary.withValues(alpha: 0.4),
                  blurRadius: 10,
                ),
              ]
            : null,
      ),
    );
  }

  Widget _buildPresetChip(String score, String label, double target) {
    final isSelected = widget.rating == target;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onRatingChanged(target);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.2) : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool enabled;
  final VoidCallback onTap;

  const _StepButton({
    required this.icon,
    required this.tooltip,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: enabled ? AppColors.surface : AppColors.surface.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: enabled ? AppColors.primary.withValues(alpha: 0.35) : AppColors.border,
              ),
            ),
            child: Icon(
              icon,
              size: 22,
              color: enabled ? AppColors.primary : AppColors.textMuted.withValues(alpha: 0.3),
            ),
          ),
        ),
      ),
    );
  }
}
