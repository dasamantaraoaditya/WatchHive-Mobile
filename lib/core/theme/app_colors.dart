import 'package:flutter/material.dart';

class AppColors {
  // WatchHive Signature Web Warm Honey Palette
  static const Color primary = Color(0xFFFFB700);
  static const Color primaryLight = Color(0xFFFFDA40);
  static const Color primaryDark = Color(0xFFE59700);

  // Background palette — Warm Cream (#FFF9F0) matching Web PWA
  static const Color background = Color(0xFFFFF9F0);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceElevated = Color(0xFFFFF3E0);
  static const Color cardBg = Color(0xFFFFFFFF);
  static const Color surfaceHighest = Color(0xFFF5EFE6);

  // Text — Charcoal Black (#2D2926) matching Web PWA
  static const Color textPrimary = Color(0xFF2D2926);
  static const Color textSecondary = Color(0xFF525252);
  static const Color textMuted = Color(0xFF737373);

  // Semantic colors
  static const Color success = Color(0xFF22C55E);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF3B82F6);

  // Border
  static const Color border = Color(0xFFE5E5E5);
  static const Color borderFocused = Color(0xFFFFB700);

  // Gradient stops
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFFFFB700), Color(0xFFFF9E00)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient heroGradient = LinearGradient(
    colors: [Colors.transparent, Color(0xFFFFF9F0)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}
