import 'package:flutter/material.dart';
import 'accent_palette.dart';
import 'base_theme.dart';

const Color kTransparent = Color(0x00000000);

class AppThemeTokens extends ThemeExtension<AppThemeTokens> {
  final Color backgroundPrimary;
  final Color backgroundSecondary;
  final Color textPrimary;
  final Color mutedText;
  final Color panel;
  final Color panelBorder;
  final Color card;
  final Color cardBorder;
  final Color phoneShell;
  final Color phoneShellInner;
  final Color tileText;
  final AccentPalette accent;

  const AppThemeTokens({
    required this.backgroundPrimary,
    required this.backgroundSecondary,
    required this.textPrimary,
    required this.mutedText,
    required this.panel,
    required this.panelBorder,
    required this.card,
    required this.cardBorder,
    required this.phoneShell,
    required this.phoneShellInner,
    required this.tileText,
    required this.accent,
  });

  static AppThemeTokens light(AccentPalette accent) => AppThemeTokens(
        backgroundPrimary: Color.lerp(
          BaseTheme.lightBgPrimary,
          accent.primary,
          0.05,
        )!,
        backgroundSecondary: Color.lerp(
          BaseTheme.lightBgSecondary,
          accent.secondary,
          0.07,
        )!,
        textPrimary: BaseTheme.lightText,
        mutedText: BaseTheme.lightMuted,
        panel: const Color.fromRGBO(255, 255, 255, 0.92),
        panelBorder: const Color.fromRGBO(255, 255, 255, 1.0),
        card: const Color.fromRGBO(255, 255, 255, 1.0),
        cardBorder: Color.lerp(
          const Color(0xFFCDD5F0),
          accent.primary,
          0.25,
        )!,
        phoneShell: Color.lerp(
          BaseTheme.lightPhoneShell,
          accent.primary,
          0.06,
        )!,
        phoneShellInner: Color.lerp(
          BaseTheme.lightPhoneShellInner,
          accent.primary,
          0.04,
        )!,
        tileText: const Color(0xFF182031),
        accent: accent,
      );

  static AppThemeTokens dark(AccentPalette accent) => AppThemeTokens(
        backgroundPrimary: BaseTheme.darkBgPrimary,
        backgroundSecondary: BaseTheme.darkBgSecondary,
        textPrimary: BaseTheme.darkText,
        mutedText: const Color.fromRGBO(230, 235, 255, 0.72),
        panel: const Color.fromRGBO(255, 255, 255, 0.08),
        panelBorder: const Color.fromRGBO(255, 255, 255, 0.12),
        card: const Color.fromRGBO(255, 255, 255, 0.08),
        cardBorder: const Color.fromRGBO(255, 255, 255, 0.12),
        phoneShell: BaseTheme.darkPhoneShell,
        phoneShellInner: BaseTheme.darkPhoneShellInner,
        tileText: const Color(0xFF10131B),
        accent: accent,
      );

  @override
  AppThemeTokens copyWith({
    Color? backgroundPrimary,
    Color? backgroundSecondary,
    Color? textPrimary,
    Color? mutedText,
    Color? panel,
    Color? panelBorder,
    Color? card,
    Color? cardBorder,
    Color? phoneShell,
    Color? phoneShellInner,
    Color? tileText,
    AccentPalette? accent,
  }) {
    return AppThemeTokens(
      backgroundPrimary: backgroundPrimary ?? this.backgroundPrimary,
      backgroundSecondary: backgroundSecondary ?? this.backgroundSecondary,
      textPrimary: textPrimary ?? this.textPrimary,
      mutedText: mutedText ?? this.mutedText,
      panel: panel ?? this.panel,
      panelBorder: panelBorder ?? this.panelBorder,
      card: card ?? this.card,
      cardBorder: cardBorder ?? this.cardBorder,
      phoneShell: phoneShell ?? this.phoneShell,
      phoneShellInner: phoneShellInner ?? this.phoneShellInner,
      tileText: tileText ?? this.tileText,
      accent: accent ?? this.accent,
    );
  }

  @override
  AppThemeTokens lerp(ThemeExtension<AppThemeTokens>? other, double t) {
    if (other is! AppThemeTokens) return this;
    return AppThemeTokens(
      backgroundPrimary:
          Color.lerp(backgroundPrimary, other.backgroundPrimary, t)!,
      backgroundSecondary:
          Color.lerp(backgroundSecondary, other.backgroundSecondary, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      mutedText: Color.lerp(mutedText, other.mutedText, t)!,
      panel: Color.lerp(panel, other.panel, t)!,
      panelBorder: Color.lerp(panelBorder, other.panelBorder, t)!,
      card: Color.lerp(card, other.card, t)!,
      cardBorder: Color.lerp(cardBorder, other.cardBorder, t)!,
      phoneShell: Color.lerp(phoneShell, other.phoneShell, t)!,
      phoneShellInner:
          Color.lerp(phoneShellInner, other.phoneShellInner, t)!,
      tileText: Color.lerp(tileText, other.tileText, t)!,
      accent: other.accent,
    );
  }
}

extension AppTheme on BuildContext {
  AppThemeTokens get themeTokens =>
      Theme.of(this).extension<AppThemeTokens>()!;
}