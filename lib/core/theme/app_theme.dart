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
    final dark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: brightness,
    ).copyWith(
      primary: primary,
      onPrimary: Colors.white,
      secondary: secondary,
      onSecondary: Colors.white,
      tertiary: accent,
      error: error,
      surface: dark ? const Color(0xFF0B0E14) : const Color(0xFFF7F9FD),
      surfaceContainerLowest: dark ? const Color(0xFF090C12) : Colors.white,
      surfaceContainerLow: dark ? const Color(0xFF111722) : const Color(0xFFF0F4FA),
      surfaceContainer: dark ? const Color(0xFF151D2A) : const Color(0xFFEAF0F8),
      surfaceContainerHigh: dark ? const Color(0xFF1A2433) : const Color(0xFFE3EAF4),
      surfaceContainerHighest: dark ? const Color(0xFF222E40) : const Color(0xFFDCE5F1),
      onSurface: dark ? const Color(0xFFF5F7FC) : const Color(0xFF111827),
      onSurfaceVariant: dark ? const Color(0xFFAAB7CC) : const Color(0xFF5B687D),
      outline: dark ? const Color(0xFF45536A) : const Color(0xFF9BAAC0),
      outlineVariant: dark ? const Color(0xFF2A3648) : const Color(0xFFD6DFEA),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: dark ? const Color(0xFF0B0E14) : const Color(0xFFF7F9FD),
      fontFamily: 'Roboto',
      textTheme: _textTheme(brightness),
      appBarTheme: AppBarTheme(
        backgroundColor: dark ? const Color(0xFF0B0E14) : const Color(0xFFF7F9FD),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: -.3,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHigh,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(17),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(17),
          borderSide: BorderSide(color: scheme.outlineVariant.withAlpha(90)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(17),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 17, vertical: 16),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: dark ? const Color(0xFF10151E) : Colors.white,
        indicatorColor: primary.withAlpha(dark ? 48 : 28),
        elevation: 0,
        labelTextStyle: const WidgetStatePropertyAll(
          TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      cardTheme: CardThemeData(
        color: dark ? const Color(0xFF121923) : Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(19),
          side: BorderSide(color: scheme.outlineVariant.withAlpha(100)),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        space: 1,
        thickness: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  static TextTheme _textTheme(Brightness brightness) {
    final base = brightness == Brightness.dark
        ? const Color(0xFFF5F7FC)
        : const Color(0xFF111827);
    return TextTheme(
      displaySmall: TextStyle(color: base, fontWeight: FontWeight.w900, letterSpacing: -1.2),
      headlineMedium: TextStyle(color: base, fontWeight: FontWeight.w900, letterSpacing: -.9),
      headlineSmall: TextStyle(color: base, fontWeight: FontWeight.w800, letterSpacing: -.55),
      titleLarge: TextStyle(color: base, fontWeight: FontWeight.w800, letterSpacing: -.25),
      titleMedium: TextStyle(color: base, fontWeight: FontWeight.w700, letterSpacing: -.1),
      titleSmall: TextStyle(color: base, fontWeight: FontWeight.w700),
      bodyLarge: TextStyle(color: base, height: 1.4),
      bodyMedium: TextStyle(color: base, height: 1.4),
      bodySmall: TextStyle(color: base, height: 1.4),
    );
  }
}
