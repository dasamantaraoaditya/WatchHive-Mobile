import 'package:flutter/material.dart';

class AppColors {
  // Primary brand palette — amber/honey
  static const Color primary = Color(0xFFF5A623);
  static const Color primaryLight = Color(0xFFFFBF47);
  static const Color primaryDark = Color(0xFFD4891A);

  // Background palette — deep slate
  static const Color background = Color(0xFF0F0F14);
  static const Color surface = Color(0xFF1A1A24);
  static const Color surfaceElevated = Color(0xFF222233);
  static const Color surfaceHighest = Color(0xFF2A2A3A);

  // Text
  static const Color textPrimary = Color(0xFFF1F1F5);
  static const Color textSecondary = Color(0xFFAAAAAF);
  static const Color textMuted = Color(0xFF6B6B7A);

  // Semantic colors
  static const Color success = Color(0xFF4CAF50);
  static const Color error = Color(0xFFEF5350);
  static const Color warning = Color(0xFFFFA726);
  static const Color info = Color(0xFF42A5F5);

  // Border
  static const Color border = Color(0xFF2E2E3E);
  static const Color borderFocused = Color(0xFFF5A623);

  // Gradient stops
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFFF5A623), Color(0xFFFF6B35)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient heroGradient = LinearGradient(
    colors: [Colors.transparent, Color(0xFF0F0F14)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}
