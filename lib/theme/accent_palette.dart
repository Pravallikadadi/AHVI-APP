import 'package:flutter/material.dart';

import 'profile_theme.dart';

class AccentPalette {
  final Color primary;
  final Color secondary;
  final Color tertiary;

  const AccentPalette({
    required this.primary,
    required this.secondary,
    required this.tertiary,
  });
}

AccentPalette getAccentPalette(ProfileTheme theme) {
  switch (theme) {
    case ProfileTheme.coolBlue:
      return const AccentPalette(
        primary: Color(0xFF6B91FF),
        secondary: Color(0xFF8D7DFF),
        tertiary: Color(0xFF04D7C8),
      );
    case ProfileTheme.sunsetPop:
      return const AccentPalette(
        primary: Color(0xFFFF9E66),
        secondary: Color(0xFFFFD86E),
        tertiary: Color(0xFFFF8EC7),
      );
    case ProfileTheme.futureCandy:
      return const AccentPalette(
        primary: Color(0xFFFF8EC7),
        secondary: Color(0xFF8D7DFF),
        tertiary: Color(0xFF04D7C8),
      );
  }
}
