import 'package:flutter/material.dart';

class AppTheme {
  static const primary = Color(0xFF3D73FF);
  static const secondary = Color(0xFF75A3FF);
  static const accent = Color(0xFF58D8FF);
  static const success = Color(0xFF34C759);
  static const error = Color(0xFFFF3B30);

  static final light = _build(Brightness.light);
  static final dark = _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: brightness,
    ).copyWith(secondary: secondary, tertiary: accent, error: error);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: brightness == Brightness.dark
          ? const Color(0xFF0B0D12)
          : const Color(0xFFF5F7FB),
      fontFamily: 'Roboto',
      textTheme: _textTheme(brightness),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withAlpha(120),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: brightness == Brightness.dark
            ? const Color(0xFF11151D)
            : Colors.white,
        indicatorColor: scheme.primary.withAlpha(35),
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: scheme.outlineVariant.withAlpha(75)),
        ),
      ),
    );
  }

  static TextTheme _textTheme(Brightness brightness) {
    final base = brightness == Brightness.dark
        ? const Color(0xFFF5F7FF)
        : const Color(0xFF10131A);
    return TextTheme(
      displaySmall: TextStyle(
        color: base,
        fontWeight: FontWeight.w900,
        letterSpacing: -1.2,
      ),
      headlineSmall: TextStyle(
        color: base,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
      ),
      titleLarge: TextStyle(
        color: base,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.2,
      ),
      titleMedium: TextStyle(
        color: base,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.1,
      ),
      bodyLarge: TextStyle(color: base, height: 1.35),
      bodyMedium: TextStyle(color: base, height: 1.35),
    );
  }
}
