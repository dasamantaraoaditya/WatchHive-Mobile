import 'dart:math';
import 'package:flutter/gestures.dart';
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
        icon: Icons.local_movies_rounded,
        color: AppColors.textMuted,
        bgColor: AppColors.surface,
        borderColor: AppColors.border,
        text: 'Slide checkpoints to rate movie',
      );
    }
    if (rating <= 2.0) {
      return WHRatingMoodInfo(
        icon: Icons.sentiment_very_dissatisfied_rounded,
        color: const Color(0xFFEF4444),
        bgColor: const Color(0xFFEF4444).withValues(alpha: 0.1),
        borderColor: const Color(0xFFEF4444).withValues(alpha: 0.3),
        text: 'Disaster / Complete Waste of Time',
      );
    }
    if (rating <= 4.0) {
      return WHRatingMoodInfo(
        icon: Icons.sentiment_dissatisfied_rounded,
        color: const Color(0xFFF97316),
        bgColor: const Color(0xFFF97316).withValues(alpha: 0.1),
        borderColor: const Color(0xFFF97316).withValues(alpha: 0.3),
        text: 'Poor / Not Recommended',
      );
    }
    if (rating <= 5.5) {
      return WHRatingMoodInfo(
        icon: Icons.sentiment_neutral_rounded,
        color: const Color(0xFFEAB308),
        bgColor: const Color(0xFFEAB308).withValues(alpha: 0.1),
        borderColor: const Color(0xFFEAB308).withValues(alpha: 0.3),
        text: 'Mediocre / Average',
      );
    }
    if (rating <= 7.0) {
      return WHRatingMoodInfo(
        icon: Icons.sentiment_satisfied_rounded,
        color: const Color(0xFF84CC16),
        bgColor: const Color(0xFF84CC16).withValues(alpha: 0.1),
        borderColor: const Color(0xFF84CC16).withValues(alpha: 0.3),
        text: 'Decent / Enjoyable',
      );
    }
    if (rating <= 8.5) {
      return WHRatingMoodInfo(
        icon: Icons.sentiment_very_satisfied_rounded,
        color: const Color(0xFF10B981),
        bgColor: const Color(0xFF10B981).withValues(alpha: 0.1),
        borderColor: const Color(0xFF10B981).withValues(alpha: 0.3),
        text: 'Excellent / Highly Recommended',
      );
    }
    if (rating <= 9.5) {
      return WHRatingMoodInfo(
        icon: Icons.grade_rounded,
        color: AppColors.primary,
        bgColor: AppColors.primary.withValues(alpha: 0.12),
        borderColor: AppColors.primary.withValues(alpha: 0.4),
        text: 'Outstanding / Near Flawless',
      );
    }
    return const WHRatingMoodInfo(
      icon: Icons.emoji_events_rounded,
      color: Color(0xFFBFA034), // Antique Gold matching reference image 10.0
      bgColor: Color(0xFFFBF8EE), // Warm Pearl Silk
      borderColor: Color(0xFFD8C78F), // Fine Champagne Gold & Silver border
      text: 'Absolute Masterpiece / Cinematic Perfection',
    );
  }

  @override
  State<WHRatingPicker> createState() => _WHRatingPickerState();
}

class _WHRatingPickerState extends State<WHRatingPicker> {
  bool _isInteracting = false;

  void _handleSliderTouch(Offset localPosition, double totalWidth) {
    if (!widget.enabled || totalWidth <= 0) return;

    const margin = 18.0;
    final trackWidth = totalWidth - 2 * margin;
    if (trackWidth <= 0) return;

    final relativeX = (localPosition.dx - margin).clamp(0.0, trackWidth);
    final progress = relativeX / trackWidth;
    final rawScore = progress * 10.0;

    // 0.1 decimal precision
    final snappedScore = (rawScore * 10).round() / 10.0;
    final clamped = snappedScore.clamp(0.0, 10.0);

    if (clamped != widget.rating) {
      final intTenth = (clamped * 10).round();
      if (intTenth % 10 == 0) {
        HapticFeedback.mediumImpact();
      } else if (intTenth % 5 == 0) {
        HapticFeedback.lightImpact();
      } else {
        HapticFeedback.selectionClick();
      }
      widget.onRatingChanged(clamped);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rating = widget.rating;
    final mood = WHRatingPicker.getMoodInfo(rating);

    return Container(
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: rating > 0
              ? mood.color.withValues(alpha: 0.35)
              : AppColors.border,
          width: rating > 0 ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
          if (rating >= 8.5)
            BoxShadow(
              color: mood.color.withValues(alpha: 0.18),
              blurRadius: 22,
              offset: const Offset(0, 3),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── 1. Top Score Header (Icon + Big Score + Reset) ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  AnimatedScale(
                    scale: _isInteracting ? 1.15 : 1.0,
                    duration: const Duration(milliseconds: 160),
                    curve: Curves.easeOutBack,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: rating > 0
                            ? mood.color.withValues(alpha: 0.15)
                            : AppColors.surface,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: rating > 0
                              ? mood.color.withValues(alpha: 0.35)
                              : AppColors.border,
                        ),
                      ),
                      child: Icon(
                        mood.icon,
                        size: 20,
                        color: rating > 0 ? mood.color : AppColors.textMuted,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      AnimatedScale(
                        scale: _isInteracting ? 1.06 : 1.0,
                        duration: const Duration(milliseconds: 160),
                        curve: Curves.easeOutBack,
                        child: Text(
                          rating > 0 ? rating.toStringAsFixed(1) : '—.—',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                            color: rating > 0
                                ? mood.color
                                : AppColors.textMuted,
                            letterSpacing: -1.0,
                          ),
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
                ],
              ),
              if (rating > 0)
                GestureDetector(
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    widget.onRatingChanged(0.0);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: Colors.red.withValues(alpha: 0.25)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.clear_rounded,
                            size: 13, color: Colors.redAccent),
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
          ),

          const SizedBox(height: 14),

          // ── 2. Movie Checkpoint Horizontal Slider Bar ──
          LayoutBuilder(
            builder: (context, constraints) {
              final totalWidth = constraints.maxWidth;
              return RawGestureDetector(
                behavior: HitTestBehavior.opaque,
                gestures: <Type, GestureRecognizerFactory>{
                  _SliderGestureRecognizer:
                      GestureRecognizerFactoryWithHandlers<
                          _SliderGestureRecognizer>(
                    () => _SliderGestureRecognizer(),
                    (_SliderGestureRecognizer instance) {
                      instance
                        ..onSliderStart = () {
                          if (!widget.enabled) return;
                          setState(() => _isInteracting = true);
                        }
                        ..onSliderTouch = (pos) {
                          _handleSliderTouch(pos, totalWidth);
                        }
                        ..onSliderEnd = () {
                          if (!widget.enabled) return;
                          setState(() => _isInteracting = false);
                        };
                    },
                  ),
                },
                child: SizedBox(
                  width: totalWidth,
                  height: 72,
                  child: CustomPaint(
                    size: Size(totalWidth, 72),
                    painter: _MovieCheckpointSliderPainter(
                      rating: rating,
                      moodColor: mood.color,
                      isRated: rating > 0,
                      isInteracting: _isInteracting,
                    ),
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 12),

          // ── 3. Cinephile Mood Sentiment Banner ──
          AnimatedContainer(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: mood.bgColor,
              borderRadius: BorderRadius.circular(12),
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
                      color: rating > 0
                          ? AppColors.textPrimary
                          : AppColors.textMuted,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // ── 4. Quick Snap Presets Header & Action Cue ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(3.5),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.touch_app_rounded,
                      size: 12,
                      color: AppColors.primaryDark,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'QUICK SNAP PRESETS',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
              const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.bolt_rounded,
                    size: 12,
                    color: AppColors.textMuted,
                  ),
                  SizedBox(width: 2),
                  Text(
                    'Tap to set instantly',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 8),

          // ── Contained In-Box Quick Snap Presets ──
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.border.withValues(alpha: 0.7),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildPresetChip('2.0', '🗑️', 'Flop', 2.0, const Color(0xFFEF4444)),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: _buildPresetChip('5.0', '🍿', 'Mid', 5.0, const Color(0xFFEAB308)),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: _buildPresetChip('7.0', '👍', 'Good', 7.0, const Color(0xFF84CC16)),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: _buildPresetChip('8.5', '🔥', 'Great', 8.5, const Color(0xFF10B981)),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: _buildPresetChip('10.0', '🏆', 'Epic', 10.0, const Color(0xFFBFA034)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetChip(
    String score,
    String emoji,
    String label,
    double target,
    Color chipColor,
  ) {
    final isSelected = (widget.rating - target).abs() < 0.05;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.mediumImpact();
          widget.onRatingChanged(target);
        },
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
          decoration: BoxDecoration(
            color: isSelected
                ? chipColor.withValues(alpha: 0.18)
                : AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? chipColor : AppColors.border.withValues(alpha: 0.8),
              width: isSelected ? 1.6 : 1.0,
            ),
            boxShadow: [
              if (isSelected)
                BoxShadow(
                  color: chipColor.withValues(alpha: 0.28),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                )
              else
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isSelected)
                    Padding(
                      padding: const EdgeInsets.only(right: 2),
                      child: Container(
                        padding: const EdgeInsets.all(1.5),
                        decoration: BoxDecoration(
                          color: chipColor,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          size: 7,
                          color: Colors.white,
                        ),
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.only(right: 2),
                      child: Text(
                        emoji,
                        style: const TextStyle(fontSize: 10),
                      ),
                    ),
                  Text(
                    score,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
                      color: isSelected ? chipColor : AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 9.5,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected ? chipColor : AppColors.textSecondary,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MovieCheckpoint {
  final double score;
  final String label;
  final String sublabel;
  final Color color;

  const _MovieCheckpoint({
    required this.score,
    required this.label,
    required this.sublabel,
    required this.color,
  });
}

class _MovieCheckpointSliderPainter extends CustomPainter {
  final double rating; // 0.0 to 10.0
  final Color moodColor;
  final bool isRated;
  final bool isInteracting;

  const _MovieCheckpointSliderPainter({
    required this.rating,
    required this.moodColor,
    required this.isRated,
    required this.isInteracting,
  });

  static const List<_MovieCheckpoint> checkpoints = [
    _MovieCheckpoint(
      score: 0.0,
      label: '0',
      sublabel: 'Start',
      color: AppColors.textMuted,
    ),
    _MovieCheckpoint(
      score: 2.0,
      label: '2 🗑️',
      sublabel: 'Flop',
      color: Color(0xFFEF4444),
    ),
    _MovieCheckpoint(
      score: 4.0,
      label: '4 👎',
      sublabel: 'Skip',
      color: Color(0xFFF97316),
    ),
    _MovieCheckpoint(
      score: 6.0,
      label: '6 🍿',
      sublabel: 'Decent',
      color: Color(0xFF84CC16),
    ),
    _MovieCheckpoint(
      score: 8.0,
      label: '8 🔥',
      sublabel: 'Hit',
      color: Color(0xFF10B981),
    ),
    _MovieCheckpoint(
      score: 10.0,
      label: '10 🏆',
      sublabel: 'Epic',
      color: Color(0xFFBFA034),
    ),
  ];

  static List<Color> _getArcColors(double rating) {
    if (rating <= 2.0) {
      return const [
        Color(0xFFB91C1C), // Deep Crimson
        Color(0xFFEF4444), // Vibrant Red
        Color(0xFFF87171), // Coral Red
      ];
    } else if (rating <= 4.0) {
      return const [
        Color(0xFFC2410C), // Deep Rust
        Color(0xFFF97316), // Fiery Orange
        Color(0xFFFB923C), // Sunburst Orange
      ];
    } else if (rating <= 5.5) {
      return const [
        Color(0xFFB45309), // Dark Amber
        Color(0xFFEAB308), // Warm Honey
        Color(0xFFFDE047), // Soft Gold
      ];
    } else if (rating <= 7.0) {
      return const [
        Color(0xFF4D7C0F), // Olive Lime
        Color(0xFF84CC16), // Vibrant Lime
        Color(0xFFA3E635), // Bright Green
      ];
    } else if (rating <= 8.5) {
      return const [
        Color(0xFF047857), // Deep Emerald
        Color(0xFF10B981), // Jade Green
        Color(0xFF34D399), // Mint Luster
      ];
    } else if (rating <= 9.5) {
      return const [
        Color(0xFFD97706), // Deep Amber Gold
        Color(0xFFFFB700), // Signature Honey Gold
        Color(0xFFFFDA40), // Radiant Sunbeam
      ];
    } else {
      // 9.6 - 10.0: Epic Champagne Gold, Platinum Silver & White (exact match to reference)
      return const [
        Color(0xFFB5A67C), // Brushed Warm Silver-Bronze
        Color(0xFFDCD2AE), // Champagne Silver
        Color(0xFFFFFFFF), // Brilliant Platinum White Sheen
        Color(0xFFF9E8A2), // Luminous Pale Gold
        Color(0xFFDEBC52), // Warm Radiant Gold
        Color(0xFFBFA034), // Rich Antique Gold
      ];
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    const margin = 18.0;
    const startX = margin;
    final endX = size.width - margin;
    final trackWidth = endX - startX;
    if (trackWidth <= 0) return;

    final progress = (rating / 10.0).clamp(0.0, 1.0);
    final thumbX = startX + progress * trackWidth;

    final arcColors = _getArcColors(rating);
    final glowColor = (rating > 9.5) ? const Color(0xFFBFA034) : moodColor;
    const trackY = 48.0;
    const trackHeight = 8.0;
    final trackRect = Rect.fromLTRB(
        startX, trackY - trackHeight / 2, endX, trackY + trackHeight / 2);

    // ── 1. Checkpoint Badges Above Track ──
    for (int i = 0; i < checkpoints.length; i++) {
      final cp = checkpoints[i];
      final cpX = startX + (cp.score / 10.0) * trackWidth;
      final isReached = isRated && (rating >= cp.score);
      final isSelectedCp = isRated && ((rating - cp.score).abs() < 0.2);

      // Label (Number + Emoji or text)
      final labelSpan = TextSpan(
        text: cp.label,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: isSelectedCp ? 11.0 : 10.0,
          fontWeight: isReached ? FontWeight.w900 : FontWeight.w600,
          color: isReached
              ? cp.color
              : AppColors.textMuted.withValues(alpha: 0.55),
        ),
      );
      final labelTp = TextPainter(
        text: labelSpan,
        textDirection: TextDirection.ltr,
      )..layout();

      // Sublabel (Movie verdict: Start, Flop, Skip, Decent, Hit, Epic)
      final subSpan = TextSpan(
        text: cp.sublabel,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 8.5,
          fontWeight: isReached ? FontWeight.w800 : FontWeight.w500,
          color: isReached
              ? cp.color.withValues(alpha: 0.9)
              : AppColors.textMuted.withValues(alpha: 0.4),
        ),
      );
      final subTp = TextPainter(
        text: subSpan,
        textDirection: TextDirection.ltr,
      )..layout();

      // Paint label & sublabel centered over cpX with edge clamping
      final labelWidth = max(labelTp.width, subTp.width);
      double drawX = cpX - labelWidth / 2;
      if (i == 0) {
        drawX = max(0.0, cpX - 4.0);
      } else if (i == checkpoints.length - 1) {
        drawX = min(size.width - labelWidth, cpX - labelWidth + 4.0);
      }

      labelTp.paint(canvas, Offset(drawX + (labelWidth - labelTp.width) / 2, 0));
      subTp.paint(canvas, Offset(drawX + (labelWidth - subTp.width) / 2, 14));

      // Connector Stem to Track Node
      final stemPaint = Paint()
        ..color = isReached
            ? cp.color.withValues(alpha: 0.5)
            : AppColors.border.withValues(alpha: 0.3)
        ..strokeWidth = isReached ? 1.2 : 0.8;
      canvas.drawLine(Offset(cpX, 26), Offset(cpX, trackY - 7), stemPaint);
    }

    // ── 2. Inactive Track Groove ──
    final inactivePaint = Paint()
      ..color = isInteracting
          ? AppColors.border.withValues(alpha: 0.7)
          : AppColors.border.withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(trackRect, const Radius.circular(4)),
      inactivePaint,
    );

    // ── 3. Active Progress Track with Dynamic Gradient & Glow ──
    if (isRated && rating > 0.0) {
      final activeRect = Rect.fromLTRB(
        startX,
        trackY - (isInteracting ? 5.0 : 4.5),
        thumbX,
        trackY + (isInteracting ? 5.0 : 4.5),
      );

      // Glow Underlay
      final glowPaint = Paint()
        ..color = glowColor.withValues(alpha: isInteracting ? 0.45 : 0.25)
        ..maskFilter =
            MaskFilter.blur(BlurStyle.normal, isInteracting ? 10 : 6);
      canvas.drawRRect(
        RRect.fromRectAndRadius(activeRect, const Radius.circular(5)),
        glowPaint,
      );

      // Active Gradient Track
      final activePaint = Paint()
        ..shader = LinearGradient(
          colors: arcColors,
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ).createShader(Rect.fromLTRB(
            startX, activeRect.top, max(thumbX, startX + 1.0), activeRect.bottom))
        ..style = PaintingStyle.fill;
      canvas.drawRRect(
        RRect.fromRectAndRadius(activeRect, const Radius.circular(5)),
        activePaint,
      );
    }

    // ── 4. Checkpoint Nodes on the Track ──
    for (final cp in checkpoints) {
      final cpX = startX + (cp.score / 10.0) * trackWidth;
      final isReached = isRated && (rating >= cp.score);
      final isSelectedCp = isRated && ((rating - cp.score).abs() < 0.2);

      // Outer Checkpoint Node Ring
      final nodeRingPaint = Paint()
        ..color = isReached
            ? cp.color
            : AppColors.border.withValues(alpha: 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = isSelectedCp ? 2.2 : (isReached ? 1.6 : 1.2);
      canvas.drawCircle(Offset(cpX, trackY), 5.5, nodeRingPaint);

      // Inner Center Dot
      final nodeDotPaint = Paint()
        ..color = isReached
            ? cp.color
            : AppColors.surfaceElevated
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(cpX, trackY), 2.5, nodeDotPaint);

      // Checkpoint Glow if reached
      if (isReached && isSelectedCp) {
        final nodeGlow = Paint()
          ..color = cp.color.withValues(alpha: 0.5)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
        canvas.drawCircle(Offset(cpX, trackY), 7.0, nodeGlow);
      }
    }

    // ── 5. Active Thumb Knob & Interactive Needle ──
    if (isRated && rating > 0.0) {
      // Precision Vertical Guideline into Checkpoint when interacting
      if (isInteracting) {
        final needlePaint = Paint()
          ..color = glowColor.withValues(alpha: 0.8)
          ..strokeWidth = 1.5;
        canvas.drawLine(
            Offset(thumbX, 26), Offset(thumbX, trackY - 8), needlePaint);

        final pointerPath = Path()
          ..moveTo(thumbX, 36)
          ..lineTo(thumbX - 3.5, 30)
          ..lineTo(thumbX + 3.5, 30)
          ..close();
        canvas.drawPath(pointerPath, Paint()..color = glowColor);
      }

      final double glowR = isInteracting ? 18.0 : 13.0;
      final double ringR = isInteracting ? 11.5 : 9.5;
      final double coreR = isInteracting ? 6.0 : 5.0;

      // Thumb Outer Glow
      final thumbGlow = Paint()
        ..color = glowColor.withValues(alpha: isInteracting ? 0.75 : 0.5)
        ..maskFilter =
            MaskFilter.blur(BlurStyle.normal, isInteracting ? 9 : 5);
      canvas.drawCircle(Offset(thumbX, trackY), glowR, thumbGlow);

      // Thumb White Ring
      final thumbRing = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(thumbX, trackY), ringR, thumbRing);

      // Thumb Inner Core
      final thumbCore = Paint()
        ..color = glowColor
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(thumbX, trackY), coreR, thumbCore);
    } else {
      // Inactive starting nub at 0.0 position
      final startThumb = Paint()
        ..color = isInteracting
            ? AppColors.primary.withValues(alpha: 0.8)
            : AppColors.textMuted.withValues(alpha: 0.4)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(const Offset(startX, trackY), 6.0, startThumb);
    }
  }

  @override
  bool shouldRepaint(covariant _MovieCheckpointSliderPainter oldDelegate) {
    return oldDelegate.rating != rating ||
        oldDelegate.moodColor != moodColor ||
        oldDelegate.isRated != isRated ||
        oldDelegate.isInteracting != isInteracting;
  }
}

/// Dedicated gesture recognizer for the horizontal slider that immediately claims
/// exclusive pointer ownership in the Flutter Gesture Arena.
///
/// This completely isolates the slider horizontal drag from parent vertical
/// scroll views (such as SingleChildScrollView). While the user touches or slides
/// horizontally, the parent page will NOT scroll. As soon as the pointer is
/// released or cancelled, normal scrolling resumes everywhere.
class _SliderGestureRecognizer extends OneSequenceGestureRecognizer {
  _SliderGestureRecognizer();

  ValueChanged<Offset>? onSliderTouch;
  VoidCallback? onSliderStart;
  VoidCallback? onSliderEnd;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    startTrackingPointer(event.pointer, event.transform);
    resolve(GestureDisposition.accepted);
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event is PointerDownEvent) {
      onSliderStart?.call();
      onSliderTouch?.call(event.localPosition);
    } else if (event is PointerMoveEvent) {
      onSliderTouch?.call(event.localPosition);
    } else if (event is PointerUpEvent || event is PointerCancelEvent) {
      stopTrackingPointer(event.pointer);
      onSliderEnd?.call();
    }
  }

  @override
  String get debugDescription => 'slider_gesture_recognizer';

  @override
  void didStopTrackingLastPointer(int pointer) {}

  @override
  void dispose() {
    onSliderTouch = null;
    onSliderStart = null;
    onSliderEnd = null;
    super.dispose();
  }
}
