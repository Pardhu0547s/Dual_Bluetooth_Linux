import 'package:flutter/material.dart';

/// Clean minimalist dark theme matching the screenshot design system.
class AppTheme {
  AppTheme._();

  static const Color background = Color(0xFF0F1117);
  static const Color cardDark = Color(0xFF1A1D24);
  static const Color cardDarkBorder = Color(0xFF2C313E);

  static const Color cardLight = Color(0xFFF5F6F8);
  static const Color cardLightBorder = Color(0xFFE2E8F0);

  static const Color darkInset = Color(0xFF12141A);
  static const Color darkInsetBorder = Color(0xFF2D323E);

  static const Color buttonDark = Color(0xFF222630);
  static const Color buttonDarkBorder = Color(0xFF333846);

  static ThemeData get darkTheme => ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: background,
        useMaterial3: true,
        fontFamily: 'Inter',
      );
}
