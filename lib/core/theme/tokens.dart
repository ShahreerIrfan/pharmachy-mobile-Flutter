// lib/core/theme/tokens.dart
// Architecture Decision: ADR-0007, ADR-0008 & ADR-0024

import 'package:flutter/material.dart';

class AppTokens {
  // Neutral Surfaces
  static const Color surfaceBackground = Color(0xFFF8F9FA);
  static const Color cardSurface = Color(0xFFFFFFFF);
  static const Color borderSubtle = Color(0xFFE5E7EB);

  // Semantic Primary & Status Colors
  static const Color primaryTeal = Color(0xFF0D9488);
  static const Color primaryTealDark = Color(0xFF0F766E);
  static const Color successGreen = Color(0xFF16A34A);
  static const Color warningAmber = Color(0xFFD97706);
  static const Color dangerRed = Color(0xFFDC2626);

  // Text Hierarchy
  static const Color textPrimary = Color(0xFF1F2937);
  static const Color textMuted = Color(0xFF6B7280);

  // 8-Point Grid Spacing
  static const double space4 = 4.0;
  static const double space8 = 8.0;
  static const double space12 = 12.0;
  static const double space16 = 16.0;
  static const double space24 = 24.0;
  static const double space32 = 32.0;

  // Touch Ergonomics & Radii
  static const double minTouchTarget = 44.0;
  static const double cardRadius = 12.0;
  static const double buttonRadius = 8.0;

  // Typography Styles
  static const TextStyle titleLarge = TextStyle(
    fontSize: 22.0,
    fontWeight: FontWeight.w700,
    color: textPrimary,
    letterSpacing: -0.5,
  );

  static const TextStyle titleMedium = TextStyle(
    fontSize: 16.0,
    fontWeight: FontWeight.w600,
    color: textPrimary,
  );

  static const TextStyle bodyRegular = TextStyle(
    fontSize: 14.0,
    fontWeight: FontWeight.w400,
    color: textPrimary,
  );

  static const TextStyle captionMuted = TextStyle(
    fontSize: 12.0,
    fontWeight: FontWeight.w500,
    color: textMuted,
  );

  static const TextStyle kpiValue = TextStyle(
    fontSize: 20.0,
    fontWeight: FontWeight.w700,
    color: primaryTeal,
  );
}
