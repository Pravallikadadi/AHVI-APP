import 'package:flutter/material.dart';

import 'accent_palette.dart';

LinearGradient mainBackground(
  AccentPalette accent, {
  required bool isDark,
}) {
  return LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: isDark
        ? const [Color(0xFF0F1A2D), Color(0xFF08111F)]
        : const [Color(0xFFFFFFFF), Color(0xFFEEF3FF)],
  );
}

RadialGradient glowPrimary(AccentPalette accent) {
  return RadialGradient(
    colors: [
      accent.primary.withValues(alpha: 0.35),
      Colors.transparent,
    ],
    stops: const [0.0, 1.0],
  );
}

RadialGradient glowSecondary(AccentPalette accent) {
  return RadialGradient(
    colors: [
      accent.tertiary.withValues(alpha: 0.35),
      Colors.transparent,
    ],
    stops: const [0.0, 1.0],
  );
}

RadialGradient glowTertiary(AccentPalette accent) {
  return RadialGradient(
    colors: [
      accent.secondary.withValues(alpha: 0.35),
      Colors.transparent,
    ],
    stops: const [0.0, 1.0],
  );
}
