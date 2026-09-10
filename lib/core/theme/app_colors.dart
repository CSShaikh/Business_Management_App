import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ===========================================================================
  // PRIMARY
  // ===========================================================================

  static const Color primary = Color(0xFF2563EB);
  static const Color primaryDark = Color(0xFF1D4ED8);
  static const Color primaryLight = Color(0xFF60A5FA);

  // ===========================================================================
  // SECONDARY
  // ===========================================================================

  static const Color secondary = Color(0xFF7C3AED);

  // Purple
  // Kept separate from secondary so screens can explicitly use AppColors.purple.
  static const Color purple = Color(0xFF7C3AED);

  // ===========================================================================
  // SEMANTIC COLORS
  // ===========================================================================

  static const Color success = Color(0xFF16A34A);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFDC2626);
  static const Color info = Color(0xFF0284C7);

  // ===========================================================================
  // LIGHT THEME
  // ===========================================================================

  static const Color lightBackground = Color(0xFFF8FAFC);
  static const Color lightSurface = Colors.white;
  static const Color lightCard = Colors.white;
  static const Color lightBorder = Color(0xFFE2E8F0);

  // ===========================================================================
  // DARK THEME
  // ===========================================================================

  static const Color darkBackground = Color(0xFF0F172A);
  static const Color darkSurface = Color(0xFF1E293B);
  static const Color darkCard = Color(0xFF1E293B);
  static const Color darkBorder = Color(0xFF334155);

  // ===========================================================================
  // TEXT - LIGHT
  // ===========================================================================

  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF64748B);

  // ===========================================================================
  // TEXT - DARK
  // ===========================================================================

  static const Color darkTextPrimary = Color(0xFFF8FAFC);
  static const Color darkTextSecondary = Color(0xFF94A3B8);
}
