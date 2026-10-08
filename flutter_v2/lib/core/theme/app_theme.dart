import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const primary = Color(0xFF2F7D5A);
  static const primaryContainer = Color(0xFFDDEEE4);
  static const lightBackground = Color(0xFFF6FAF7);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightText = Color(0xFF173B2D);
  static const lightSecondaryText = Color(0xFF63736A);
  static const lightOutline = Color(0xFFD5E2DA);
  static const accentGold = Color(0xFFD4A95F);

  static const darkBackground = Color(0xFF101A15);
  static const darkSurface = Color(0xFF18251E);
  static const darkPrimary = Color(0xFF79C69D);
  static const darkPrimaryContainer = Color(0xFF244C38);
  static const darkText = Color(0xFFECF5EF);
  static const darkSecondaryText = Color(0xFFB5C6BB);
  static const darkOutline = Color(0xFF385244);

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
      surface: lightSurface,
    ).copyWith(
      primary: primary,
      onPrimary: Colors.white,
      primaryContainer: primaryContainer,
      onPrimaryContainer: lightText,
      secondary: accentGold,
      onSecondary: lightText,
      surface: lightSurface,
      onSurface: lightText,
      onSurfaceVariant: lightSecondaryText,
      outline: lightOutline,
      outlineVariant: lightOutline,
    );

    return _build(
      scheme: scheme,
      scaffold: lightBackground,
      card: lightSurface,
      navigation: lightSurface,
      selectedLabel: primary,
      inputFill: lightSurface,
    );
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: darkPrimary,
      brightness: Brightness.dark,
      surface: darkSurface,
    ).copyWith(
      primary: darkPrimary,
      onPrimary: const Color(0xFF0C2619),
      primaryContainer: darkPrimaryContainer,
      onPrimaryContainer: darkText,
      secondary: accentGold,
      onSecondary: const Color(0xFF2C2108),
      surface: darkSurface,
      onSurface: darkText,
      onSurfaceVariant: darkSecondaryText,
      outline: darkOutline,
      outlineVariant: darkOutline,
    );

    return _build(
      scheme: scheme,
      scaffold: darkBackground,
      card: darkSurface,
      navigation: const Color(0xFF142019),
      selectedLabel: darkPrimary,
      inputFill: const Color(0xFF132019),
    );
  }

  static ThemeData _build({
    required ColorScheme scheme,
    required Color scaffold,
    required Color card,
    required Color navigation,
    required Color selectedLabel,
    required Color inputFill,
  }) {
    final primaryText = scheme.onSurface;
    final secondaryText = scheme.onSurfaceVariant;

    return ThemeData(
      useMaterial3: true,
      brightness: scheme.brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffold,
      fontFamily: 'sans-serif',
      textTheme: TextTheme(
        headlineMedium: TextStyle(
          fontWeight: FontWeight.w800,
          color: primaryText,
        ),
        titleLarge: TextStyle(
          fontWeight: FontWeight.w800,
          color: primaryText,
        ),
        titleMedium: TextStyle(
          fontWeight: FontWeight.w700,
          color: primaryText,
        ),
        bodyLarge: TextStyle(color: primaryText),
        bodyMedium: TextStyle(color: secondaryText),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: card,
        shape: RoundedRectangleBorder(
          side: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.68),
          ),
          borderRadius: const BorderRadius.all(Radius.circular(24)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        backgroundColor: navigation,
        indicatorColor: scheme.primaryContainer,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return TextStyle(
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w800
                : FontWeight.w600,
            color: states.contains(WidgetState.selected)
                ? selectedLabel
                : secondaryText,
          );
        }),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: 0.72),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputFill,
        border: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(16)),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(16)),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(16)),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.primaryContainer.withValues(alpha: 0.55),
      ),
    );
  }
}
