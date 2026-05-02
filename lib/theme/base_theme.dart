import 'package:flutter/material.dart';

class BaseTheme {
  static const Color darkBgPrimary = Color(0xFF08111F);
  static const Color darkBgSecondary = Color(0xFF0F1A2D);
  static const Color darkText = Color(0xFFF5F7FF);
  static const Color darkPhoneShell = Color(0xFF192131);
  static const Color darkPhoneShellInner = Color(0xFF111723);

  static const Color lightBgPrimary = Color(0xFFE2EAF8);
  static const Color lightBgSecondary = Color(0xFFFFFFFF);
  static const Color lightText = Color(0xFF1A1D26);
  static const Color lightMuted = Color(0xFF66708A);
  static const Color lightPhoneShell = Color(0xFFDFE7FB);
  static const Color lightPhoneShellInner = Color(0xFFEEF3FF);

  static final ThemeData dark = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: darkBgPrimary,
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: darkText),
      bodyMedium: TextStyle(color: darkText),
      bodySmall: TextStyle(color: darkText),
      titleMedium: TextStyle(color: darkText),
      titleSmall: TextStyle(color: darkText),
    ),
    cardTheme: const CardThemeData(
      color: darkBgSecondary,
    ),
  );

  static final ThemeData light = ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: lightBgPrimary,
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: lightText),
      bodyMedium: TextStyle(color: lightText),
      bodySmall: TextStyle(color: lightText),
      titleMedium: TextStyle(color: lightText),
      titleSmall: TextStyle(color: lightText),
    ),
    cardTheme: const CardThemeData(
      color: lightBgSecondary,
    ),
  );
}