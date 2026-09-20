import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const primary = Color(0xFF1F7A4C);
  static const surface = Color(0xFFF7F9F7);
  static const text = Color(0xFF172033);

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
      surface: surface,
    );

    return _build(
      scheme: scheme,
      scaffold: surface,
    );
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.dark,
    );

    return _build(
      scheme: scheme,
      scaffold: const Color(0xFF101512),
    );
  }

  static ThemeData _build({
    required ColorScheme scheme,
    required Color scaffold,
  }) {
    final isDark = scheme.brightness == Brightness.dark;
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
        color: isDark ? const Color(0xFF18201B) : scheme.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(24)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        backgroundColor: isDark ? const Color(0xFF151C18) : scheme.surface,
        indicatorColor: primary.withValues(alpha: isDark ? 0.28 : 0.12),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return TextStyle(
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w800
                : FontWeight.w600,
            color: states.contains(WidgetState.selected)
                ? (isDark ? const Color(0xFF8FDCAD) : primary)
                : secondaryText,
          );
        }),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: 0.7),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: isDark,
        fillColor: isDark ? const Color(0xFF131A16) : null,
      ),
    );
  }
}
