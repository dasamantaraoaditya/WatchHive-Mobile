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
        icon: Icons.speed_rounded,
        color: AppColors.textMuted,
        bgColor: AppColors.surface,
        borderColor: AppColors.border,
        text: 'Turn radial dial or tap to score',
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
      color: const Color(0xFFC5A038), // Golden Silver (Champagne Gold & Platinum Silver)
      bgColor: const Color(0xFFC5A038).withValues(alpha: 0.14),
      borderColor: const Color(0xFFC5A038).withValues(alpha: 0.45),
      text: 'Absolute Masterpiece / Cinematic Perfection 🏆',
    );
  }

  @override
  State<WHRatingPicker> createState() => _WHRatingPickerState();
}

class _WHRatingPickerState extends State<WHRatingPicker> {
  final GlobalKey _dialKey = GlobalKey();
  bool _isInteracting = false;

  void _handleDialTouch(Offset localPosition, Size size) {
    if (!widget.enabled || size.width <= 0 || size.height <= 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final dx = localPosition.dx - center.dx;
    final dy = localPosition.dy - center.dy;
    final distance = sqrt(dx * dx + dy * dy);

    // Ignore taps inside innermost dead-center hub
    if (distance < 24) return;

    double angle = atan2(dy, dx);
    if (angle < 0) {
      angle += 2 * pi;
    }

    const startAngle = 135.0 * (pi / 180.0);
    const sweepAngle = 270.0 * (pi / 180.0);

    double angleFromStart = angle - startAngle;
    if (angleFromStart < 0) {
      angleFromStart += 2 * pi;
    }

    double progress;
    if (angleFromStart > sweepAngle) {
      // Finger is in the bottom gap (90 degree opening)
      const gapMidpoint = sweepAngle + (2 * pi - sweepAngle) / 2;
      if (angleFromStart < gapMidpoint) {
        progress = 1.0;
      } else {
        progress = 0.0;
      }
    } else {
      progress = (angleFromStart / sweepAngle).clamp(0.0, 1.0);
    }

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

  void _adjustRating(double delta) {
    if (!widget.enabled) return;
    final newScore = ((widget.rating + delta) * 10).round() / 10.0;
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: rating > 0
              ? mood.color.withValues(alpha: 0.35)
              : AppColors.border,
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
              color: mood.color.withValues(alpha: 0.18),
              blurRadius: 24,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Radial Dial (Interactive Gauge with 0.1 Decimal Precision & Isolated Drag) ──
          RawGestureDetector(
            behavior: HitTestBehavior.opaque,
            gestures: <Type, GestureRecognizerFactory>{
              _DialGestureRecognizer:
                  GestureRecognizerFactoryWithHandlers<_DialGestureRecognizer>(
                () => _DialGestureRecognizer(),
                (_DialGestureRecognizer instance) {
                  instance
                    ..onDialStart = () {
                      if (!widget.enabled) return;
                      setState(() => _isInteracting = true);
                    }
                    ..onDialTouch = (pos) {
                      _handleDialTouch(pos, const Size(220, 220));
                    }
                    ..onDialEnd = () {
                      if (!widget.enabled) return;
                      setState(() => _isInteracting = false);
                    };
                },
              ),
            },
            child: SizedBox(
              key: _dialKey,
              width: 220,
              height: 220,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: const Size(220, 220),
                    painter: _RadialDialPainter(
                      rating: rating,
                      moodColor: mood.color,
                      isRated: rating > 0,
                      isInteracting: _isInteracting,
                    ),
                  ),

                  // Center Display Hub
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedScale(
                        scale: _isInteracting ? 1.15 : 1.0,
                        duration: const Duration(milliseconds: 160),
                        curve: Curves.easeOutBack,
                        child: Icon(
                          mood.icon,
                          size: 30,
                          color: rating > 0 ? mood.color : AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 6),
                      AnimatedScale(
                        scale: _isInteracting ? 1.08 : 1.0,
                        duration: const Duration(milliseconds: 160),
                        curve: Curves.easeOutBack,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              rating > 0 ? rating.toStringAsFixed(1) : '—.—',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 40,
                                fontWeight: FontWeight.w900,
                                color: rating > 0
                                    ? mood.color
                                    : AppColors.textMuted,
                                letterSpacing: -1.2,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Text(
                              '/ 10',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 14),

          // ── Precision Stepper Controls (-0.5, -0.1, +0.1, +0.5) ──
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _StepPill(
                label: '-0.5',
                enabled: widget.enabled && rating > 0.0,
                onTap: () => _adjustRating(-0.5),
              ),
              const SizedBox(width: 8),
              _StepPill(
                label: '-0.1',
                enabled: widget.enabled && rating > 0.0,
                onTap: () => _adjustRating(-0.1),
              ),
              const SizedBox(width: 16),
              _StepPill(
                label: '+0.1',
                enabled: widget.enabled && rating < 10.0,
                onTap: () => _adjustRating(0.1),
              ),
              const SizedBox(width: 8),
              _StepPill(
                label: '+0.5',
                enabled: widget.enabled && rating < 10.0,
                onTap: () => _adjustRating(0.5),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ── Quick-Select Preset Chips ──
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildPresetChip('5.0', '🍿 5.0 Avg', 5.0),
                const SizedBox(width: 8),
                _buildPresetChip('7.0', '👍 7.0 Good', 7.0),
                const SizedBox(width: 8),
                _buildPresetChip('8.5', '🔥 8.5 Great', 8.5),
                const SizedBox(width: 8),
                _buildPresetChip('10.0', '🏆 10.0 Epic', 10.0),
                if (rating > 0) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      widget.onRatingChanged(0.0);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Colors.red.withValues(alpha: 0.25)),
                      ),
                      child: const Row(
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
        ],
      ),
    );
  }

  Widget _buildPresetChip(String score, String label, double target) {
    final isSelected = widget.rating == target;
    final isEpic = target >= 10.0;
    final highlightColor = isEpic ? const Color(0xFFC5A038) : AppColors.primary;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onRatingChanged(target);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? highlightColor.withValues(alpha: 0.2)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? highlightColor : AppColors.border,
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
                color: isSelected ? highlightColor : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RadialDialPainter extends CustomPainter {
  final double rating; // 0.0 to 10.0
  final Color moodColor;
  final bool isRated;
  final bool isInteracting;

  const _RadialDialPainter({
    required this.rating,
    required this.moodColor,
    required this.isRated,
    required this.isInteracting,
  });

  static const double startAngle = 135.0 * (pi / 180.0);
  static const double sweepAngle = 270.0 * (pi / 180.0);

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
      // 9.6 - 10.0: Epic Golden Silver (Platinum Silver & Champagne Gold)
      return const [
        Color(0xFFBBA773), // Antique Bronze-Gold
        Color(0xFFE2D5B5), // Champagne Gold
        Color(0xFFFFFFFF), // Platinum Silver Flash
        Color(0xFFFFDF73), // Sunlit Gold
        Color(0xFFD4E0EC), // Shimmering Liquid Silver
      ];
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 18.0;

    final arcColors = _getArcColors(rating);
    final glowColor = (rating > 9.5) ? const Color(0xFFC5A038) : moodColor;

    // 1. Inactive Track (Subtle dark honey groove)
    final trackPaint = Paint()
      ..color = isInteracting
          ? AppColors.border.withValues(alpha: 0.65)
          : AppColors.border.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12.0
      ..strokeCap = StrokeCap.round;

    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawArc(rect, startAngle, sweepAngle, false, trackPaint);

    // 2. Dial Ticks (Every 1.0 unit = 11 ticks, with 0.5 sub-ticks)
    final tickPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i <= 20; i++) {
      final tickAngle = startAngle + (i / 20.0) * sweepAngle;
      final isMajor = (i % 2 == 0);
      final tickLength = isMajor ? (isInteracting ? 7.5 : 6.0) : 3.5;
      final innerRadius = radius - (isMajor ? 14.0 : 12.0);
      final outerRadius = innerRadius + tickLength;

      final p1 = Offset(
        center.dx + innerRadius * cos(tickAngle),
        center.dy + innerRadius * sin(tickAngle),
      );
      final p2 = Offset(
        center.dx + outerRadius * cos(tickAngle),
        center.dy + outerRadius * sin(tickAngle),
      );

      final tickScore = i / 2.0;
      final isPassed = isRated && (tickScore <= rating);

      tickPaint.color = isPassed
          ? glowColor.withValues(alpha: isMajor ? 0.95 : 0.65)
          : AppColors.textMuted.withValues(alpha: isMajor ? 0.35 : 0.18);
      tickPaint.strokeWidth = isMajor ? 2.0 : 1.0;

      canvas.drawLine(p1, p2, tickPaint);
    }

    // 3. Active Progress Arc
    if (isRated && rating > 0.0) {
      final activeProgress = (rating / 10.0).clamp(0.0, 1.0);
      final activeSweep = activeProgress * sweepAngle;

      // Dynamic Arc Glow Underlay matching current score & mood
      final glowPaint = Paint()
        ..color = glowColor.withValues(alpha: isInteracting ? 0.40 : 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = isInteracting ? 22.0 : 18.0
        ..strokeCap = StrokeCap.round
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, isInteracting ? 12 : 8);
      canvas.drawArc(rect, startAngle, activeSweep, false, glowPaint);

      // Dynamic Arc Stroke matching current score & mood
      final activePaint = Paint()
        ..shader = SweepGradient(
          startAngle: startAngle,
          endAngle: startAngle + activeSweep + 0.001,
          colors: arcColors,
        ).createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = isInteracting ? 13.5 : 12.0
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(rect, startAngle, activeSweep, false, activePaint);

      // 4. Indicator Thumb (Knob at active arc tip)
      final thumbAngle = startAngle + activeSweep;
      final thumbCenter = Offset(
        center.dx + radius * cos(thumbAngle),
        center.dy + radius * sin(thumbAngle),
      );

      final double glowR = isInteracting ? 20.0 : 13.0;
      final double ringR = isInteracting ? 12.5 : 10.0;
      final double coreR = isInteracting ? 6.5 : 5.5;

      // Thumb Outer Glow
      final thumbGlow = Paint()
        ..color = glowColor.withValues(alpha: isInteracting ? 0.75 : 0.55)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, isInteracting ? 10 : 6);
      canvas.drawCircle(thumbCenter, glowR, thumbGlow);

      // Thumb Outer Ring
      final thumbRing = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawCircle(thumbCenter, ringR, thumbRing);

      // Thumb Inner Core
      final thumbCore = Paint()
        ..color = glowColor
        ..style = PaintingStyle.fill;
      canvas.drawCircle(thumbCenter, coreR, thumbCore);
    } else {
      // Inactive starting nub at 0.0 position
      final thumbCenter = Offset(
        center.dx + radius * cos(startAngle),
        center.dy + radius * sin(startAngle),
      );
      final startThumb = Paint()
        ..color = isInteracting
            ? AppColors.primary.withValues(alpha: 0.8)
            : AppColors.textMuted.withValues(alpha: 0.4)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(thumbCenter, isInteracting ? 8.0 : 6.0, startThumb);
    }
  }

  @override
  bool shouldRepaint(covariant _RadialDialPainter oldDelegate) {
    return oldDelegate.rating != rating ||
        oldDelegate.moodColor != moodColor ||
        oldDelegate.isRated != isRated ||
        oldDelegate.isInteracting != isInteracting;
  }
}

class _StepPill extends StatelessWidget {
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  const _StepPill({
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: enabled
                ? AppColors.surface
                : AppColors.surface.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: enabled
                  ? AppColors.primary.withValues(alpha: 0.35)
                  : AppColors.border,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: enabled
                  ? AppColors.primary
                  : AppColors.textMuted.withValues(alpha: 0.3),
            ),
          ),
        ),
      ),
    );
  }
}

/// Dedicated gesture recognizer for the radial dial that immediately claims
/// exclusive pointer ownership in the Flutter Gesture Arena.
///
/// This completely isolates the dial rotation/sliding interaction from parent
/// scroll views (such as SingleChildScrollView). While the user touches or
/// rotates the dial, the parent page will NOT scroll. As soon as the pointer is
/// released or cancelled, normal scrolling resumes everywhere.
class _DialGestureRecognizer extends OneSequenceGestureRecognizer {
  _DialGestureRecognizer();

  ValueChanged<Offset>? onDialTouch;
  VoidCallback? onDialStart;
  VoidCallback? onDialEnd;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    startTrackingPointer(event.pointer, event.transform);
    resolve(GestureDisposition.accepted);
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event is PointerDownEvent) {
      onDialStart?.call();
      onDialTouch?.call(event.localPosition);
    } else if (event is PointerMoveEvent) {
      onDialTouch?.call(event.localPosition);
    } else if (event is PointerUpEvent || event is PointerCancelEvent) {
      stopTrackingPointer(event.pointer);
      onDialEnd?.call();
    }
  }

  @override
  String get debugDescription => 'dial_gesture_recognizer';

  @override
  void didStopTrackingLastPointer(int pointer) {}

  @override
  void dispose() {
    onDialTouch = null;
    onDialStart = null;
    onDialEnd = null;
    super.dispose();
  }
}

