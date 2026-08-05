import 'package:flutter/material.dart';

/// Centralized design system for Dual Audio Hub.
/// Ensures consistent look and feel across all platforms.
class AppTheme {
  AppTheme._();

  // ─── Core Colors ───────────────────────────────────────────
  static const Color background = Color(0xFF080B12);
  static const Color surface = Color(0xFF0F1320);
  static const Color surfaceLight = Color(0xFF161B2E);
  static const Color surfaceBorder = Color(0x1AFFFFFF);

  static const Color accent = Color(0xFF00D4FF);
  static const Color accentAlt = Color(0xFF6C63FF);
  static const Color accentGradientStart = Color(0xFF00D4FF);
  static const Color accentGradientEnd = Color(0xFF6C63FF);

  static const Color success = Color(0xFF00E676);
  static const Color error = Color(0xFFFF5252);
  static const Color warning = Color(0xFFFFAB40);

  static const Color textPrimary = Color(0xFFF0F0F5);
  static const Color textSecondary = Color(0xFF8B8FA3);
  static const Color textMuted = Color(0xFF555A70);

  // ─── Gradients ─────────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accentGradientStart, accentGradientEnd],
  );

  static const LinearGradient activeGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF00E676), Color(0xFF00C853)],
  );

  static const LinearGradient dangerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFF5252), Color(0xFFD50000)],
  );

  static const RadialGradient backgroundGlow = RadialGradient(
    center: Alignment(-0.6, -0.7),
    radius: 1.4,
    colors: [Color(0x1200D4FF), Color(0x086C63FF), Color(0x00080B12)],
  );

  // ─── Typography ────────────────────────────────────────────
  static const String fontFamily = 'Inter';

  static const TextStyle headingLg = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: textPrimary,
    letterSpacing: -0.8,
    height: 1.2,
  );

  static const TextStyle headingMd = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: textPrimary,
    letterSpacing: -0.4,
  );

  static const TextStyle headingSm = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: textPrimary,
    letterSpacing: -0.2,
  );

  static const TextStyle bodyMd = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: textSecondary,
    height: 1.5,
  );

  static const TextStyle bodySm = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: textMuted,
    letterSpacing: 0.3,
  );

  static const TextStyle label = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: textMuted,
    letterSpacing: 1.0,
  );

  static const TextStyle mono = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    fontFamily: 'JetBrains Mono',
    color: textSecondary,
  );

  // ─── Decorations ───────────────────────────────────────────
  static BoxDecoration cardDecoration({bool isActive = false}) {
    return BoxDecoration(
      color: surface.withOpacity(0.7),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: isActive ? accent.withOpacity(0.3) : surfaceBorder,
        width: isActive ? 1.5 : 1,
      ),
      boxShadow: [
        BoxShadow(
          color: isActive ? accent.withOpacity(0.08) : Colors.black.withOpacity(0.3),
          blurRadius: isActive ? 24 : 16,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }

  static BoxDecoration glassDecoration() {
    return BoxDecoration(
      color: surfaceLight.withOpacity(0.5),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: surfaceBorder),
    );
  }

  // ─── ThemeData ─────────────────────────────────────────────
  static ThemeData get darkTheme => ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: background,
    useMaterial3: true,
    colorScheme: const ColorScheme.dark(
      primary: accent,
      secondary: accentAlt,
      surface: surface,
      error: error,
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: accent,
      inactiveTrackColor: surfaceLight,
      thumbColor: accent,
      overlayColor: accent.withOpacity(0.12),
      trackHeight: 4,
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
      overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: surface,
      contentTextStyle: bodyMd.copyWith(color: textPrimary),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
