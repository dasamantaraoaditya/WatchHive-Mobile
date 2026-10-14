import 'package:flutter/material.dart';

/// Renders authentic, crisp, high-resolution vector logos for movie watch platforms
/// (Netflix, Disney+ Hotstar, Prime Video, JioCinema, YouTube, Apple TV+, Cinema, Home, On the Go).
class PlatformBrandLogo extends StatelessWidget {
  final String platform;
  final double size;
  final bool isSelected;

  const PlatformBrandLogo({
    super.key,
    required this.platform,
    this.size = 20,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final name = platform.trim().toLowerCase();

    if (name.contains('netflix')) {
      return _buildLogoContainer(
        bgColor: Colors.black,
        child: CustomPaint(
          size: Size(size * 0.72, size * 0.8),
          painter: const _NetflixNPainter(),
        ),
      );
    }

    if (name.contains('hotstar') || name.contains('disney')) {
      return _buildLogoContainer(
        bgColor: const Color(0xFF071026),
        child: CustomPaint(
          size: Size(size * 0.85, size * 0.85),
          painter: const _HotstarPainter(),
        ),
      );
    }

    if (name.contains('prime') || name.contains('amazon')) {
      return _buildLogoContainer(
        bgColor: const Color(0xFF00050D),
        child: CustomPaint(
          size: Size(size * 0.85, size * 0.85),
          painter: const _PrimePainter(),
        ),
      );
    }

    if (name.contains('jiocinema') || name.contains('jio')) {
      return _buildLogoContainer(
        bgColor: const Color(0xFFD80064),
        child: CustomPaint(
          size: Size(size * 0.85, size * 0.85),
          painter: const _JioCinemaPainter(),
        ),
      );
    }

    if (name.contains('youtube')) {
      return _buildLogoContainer(
        bgColor: Colors.black,
        child: CustomPaint(
          size: Size(size * 0.9, size * 0.65),
          painter: const _YouTubePainter(),
        ),
      );
    }

    if (name.contains('apple')) {
      return _buildLogoContainer(
        bgColor: const Color(0xFF1C1C1E),
        child: CustomPaint(
          size: Size(size * 0.85, size * 0.85),
          painter: const _AppleTvPainter(),
        ),
      );
    }

    if (name.contains('cinema') || name.contains('theater')) {
      return _buildLogoContainer(
        bgColor: const Color(0xFFB71C1C),
        child: Icon(Icons.theaters_rounded, size: size * 0.72, color: const Color(0xFFFFD700)),
      );
    }

    if (name.contains('home') || name.contains('couch') || name.contains('living')) {
      return _buildLogoContainer(
        bgColor: const Color(0xFFF59E0B),
        child: Icon(Icons.chair_rounded, size: size * 0.72, color: Colors.white),
      );
    }

    if (name.contains('mobile') || name.contains('go') || name.contains('flight')) {
      return _buildLogoContainer(
        bgColor: const Color(0xFF0284C7),
        child: Icon(Icons.smartphone_rounded, size: size * 0.72, color: Colors.white),
      );
    }

    // Generic fallback
    return Icon(
      Icons.location_on_rounded,
      size: size * 0.8,
      color: isSelected ? const Color(0xFFFFB700) : Colors.white70,
    );
  }

  Widget _buildLogoContainer({required Color bgColor, required Widget child}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(size * 0.24),
        border: Border.all(
          color: isSelected ? const Color(0xFFFFB700) : Colors.white.withValues(alpha: 0.15),
          width: isSelected ? 1.5 : 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: bgColor.withValues(alpha: isSelected ? 0.45 : 0.2),
            blurRadius: isSelected ? 6 : 3,
            offset: const Offset(0, 1.5),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: child,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Custom Painters for Pixel-Perfect Brand Logos
// ─────────────────────────────────────────────────────────────────────────────

class _NetflixNPainter extends CustomPainter {
  const _NetflixNPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final barWidth = w * 0.30;
    final leftBarRect = Rect.fromLTWH(0, 0, barWidth, h);
    final rightBarRect = Rect.fromLTWH(w - barWidth, 0, barWidth, h);

    final darkRedPaint = Paint()..color = const Color(0xFFB81D24);
    final brightRedPaint = Paint()..color = const Color(0xFFE50914);

    // Left and right dark red pillars
    canvas.drawRect(leftBarRect, darkRedPaint);
    canvas.drawRect(rightBarRect, darkRedPaint);

    // Diagonal sash path
    final diagonalPath = Path()
      ..moveTo(0, 0)
      ..lineTo(barWidth, 0)
      ..lineTo(w, h)
      ..lineTo(w - barWidth, h)
      ..close();

    // Subtle shadow to create 3D ribbon depth
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.45)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2);
    canvas.save();
    canvas.translate(-0.4, 0);
    canvas.drawPath(diagonalPath, shadowPaint);
    canvas.restore();

    // Draw bright red diagonal ribbon
    canvas.drawPath(diagonalPath, brightRedPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _HotstarPainter extends CustomPainter {
  const _HotstarPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Disney swoosh arc across top
    final arcPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round;

    final arcPath = Path()
      ..moveTo(w * 0.12, h * 0.65)
      ..cubicTo(w * 0.22, h * 0.22, w * 0.62, h * 0.18, w * 0.88, h * 0.28);
    canvas.drawPath(arcPath, arcPaint);

    // Hotstar sparkling 4-point golden star at top-right
    final starCenterX = w * 0.76;
    final starCenterY = h * 0.30;
    final starPaint = Paint()..color = const Color(0xFFFFB300);

    final starPath = Path()
      ..moveTo(starCenterX, starCenterY - h * 0.22)
      ..lineTo(starCenterX + w * 0.07, starCenterY - h * 0.05)
      ..lineTo(starCenterX + w * 0.20, starCenterY)
      ..lineTo(starCenterX + w * 0.07, starCenterY + h * 0.05)
      ..lineTo(starCenterX, starCenterY + h * 0.22)
      ..lineTo(starCenterX - w * 0.07, starCenterY + h * 0.05)
      ..lineTo(starCenterX - w * 0.20, starCenterY)
      ..lineTo(starCenterX - w * 0.07, starCenterY - h * 0.05)
      ..close();
    canvas.drawPath(starPath, starPaint);
    canvas.drawCircle(Offset(starCenterX, starCenterY), 0.7, Paint()..color = Colors.white);

    // "D" shape at bottom left
    final dPaint = Paint()..color = Colors.white;
    final dRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.14, h * 0.52, w * 0.32, h * 0.38),
      const Radius.circular(2.5),
    );
    canvas.drawRRect(dRect, dPaint);

    final cutoutRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.22, h * 0.60, w * 0.14, h * 0.22),
      const Radius.circular(1.2),
    );
    canvas.drawRRect(cutoutRect, Paint()..color = const Color(0xFF071026));

    // "+" sign
    final plusPaint = Paint()
      ..color = const Color(0xFF00D2D3)
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(w * 0.52, h * 0.66), Offset(w * 0.52, h * 0.76), plusPaint);
    canvas.drawLine(Offset(w * 0.47, h * 0.71), Offset(w * 0.57, h * 0.71), plusPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PrimePainter extends CustomPainter {
  const _PrimePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Amazon smile arrow in cyan
    final arrowPaint = Paint()
      ..color = const Color(0xFF00A8E8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round;

    final smilePath = Path()
      ..moveTo(w * 0.15, h * 0.76)
      ..quadraticBezierTo(w * 0.5, h * 0.94, w * 0.85, h * 0.72);
    canvas.drawPath(smilePath, arrowPaint);

    // Arrowhead tip
    final headPath = Path()
      ..moveTo(w * 0.76, h * 0.82)
      ..lineTo(w * 0.86, h * 0.72)
      ..lineTo(w * 0.75, h * 0.64);
    canvas.drawPath(headPath, arrowPaint);

    // Centered play triangle in white
    final playPath = Path()
      ..moveTo(w * 0.38, h * 0.32)
      ..lineTo(w * 0.65, h * 0.48)
      ..lineTo(w * 0.38, h * 0.64)
      ..close();
    canvas.drawPath(playPath, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _JioCinemaPainter extends CustomPainter {
  const _JioCinemaPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Translucent circle ring
    canvas.drawCircle(
      Offset(w * 0.5, h * 0.5),
      w * 0.38,
      Paint()..color = Colors.white.withValues(alpha: 0.22),
    );

    // Sharp white play button
    final playPath = Path()
      ..moveTo(w * 0.42, h * 0.32)
      ..lineTo(w * 0.66, h * 0.5)
      ..lineTo(w * 0.42, h * 0.68)
      ..close();
    canvas.drawPath(playPath, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _YouTubePainter extends CustomPainter {
  const _YouTubePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Red pill
    final redRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, w, h),
      const Radius.circular(3),
    );
    canvas.drawRRect(redRect, Paint()..color = const Color(0xFFFF0000));

    // White play triangle
    final playPath = Path()
      ..moveTo(w * 0.38, h * 0.28)
      ..lineTo(w * 0.68, h * 0.5)
      ..lineTo(w * 0.38, h * 0.72)
      ..close();
    canvas.drawPath(playPath, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _AppleTvPainter extends CustomPainter {
  const _AppleTvPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Apple body
    canvas.drawCircle(Offset(w * 0.32, h * 0.55), w * 0.22, Paint()..color = Colors.white);

    // Leaf
    final leaf = Path()
      ..moveTo(w * 0.32, h * 0.25)
      ..quadraticBezierTo(w * 0.42, h * 0.25, w * 0.38, h * 0.35)
      ..quadraticBezierTo(w * 0.28, h * 0.35, w * 0.32, h * 0.25);
    canvas.drawPath(leaf, Paint()..color = Colors.white);

    // "tv+" text
    final textPainter = TextPainter(
      text: const TextSpan(
        text: 'tv+',
        style: TextStyle(
          color: Colors.white,
          fontSize: 7.5,
          fontWeight: FontWeight.w900,
          fontFamily: 'Inter',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(canvas, Offset(w * 0.54, h * 0.32));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
