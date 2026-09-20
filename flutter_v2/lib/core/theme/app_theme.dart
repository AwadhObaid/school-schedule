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

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: surface,
      fontFamily: 'sans-serif',
      textTheme: const TextTheme(
        headlineMedium: TextStyle(fontWeight: FontWeight.w800, color: text),
        titleLarge: TextStyle(fontWeight: FontWeight.w800, color: text),
        titleMedium: TextStyle(fontWeight: FontWeight.w700, color: text),
        bodyLarge: TextStyle(color: text),
        bodyMedium: TextStyle(color: Color(0xFF5D6675)),
      ),
      cardTheme: const CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(24)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        indicatorColor: primary.withValues(alpha: 0.12),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return TextStyle(
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w800
                : FontWeight.w600,
            color: states.contains(WidgetState.selected)
                ? primary
                : const Color(0xFF536071),
          );
        }),
      ),
    );
  }
}
