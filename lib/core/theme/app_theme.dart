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
    final scheme =
        ColorScheme.fromSeed(
          seedColor: primary,
          brightness: brightness,
        ).copyWith(
          primary: primary,
          onPrimary: Colors.white,
          secondary: secondary,
          onSecondary: Colors.white,
          tertiary: accent,
          error: error,
          surface: dark ? const Color(0xFF0B0D12) : const Color(0xFFF6F8FC),
          surfaceContainerLowest: dark ? const Color(0xFF080A0F) : Colors.white,
          surfaceContainerLow: dark
              ? const Color(0xFF0E1118)
              : const Color(0xFFF1F4F9),
          surfaceContainer: dark
              ? const Color(0xFF121721)
              : const Color(0xFFEBEFF6),
          surfaceContainerHigh: dark
              ? const Color(0xFF171E2A)
              : const Color(0xFFE3E8F1),
          surfaceContainerHighest: dark
              ? const Color(0xFF1D2635)
              : const Color(0xFFDCE3EE),
          onSurface: dark ? const Color(0xFFF5F7FF) : const Color(0xFF10131A),
          onSurfaceVariant: dark
              ? const Color(0xFFAAB5C8)
              : const Color(0xFF536176),
          outline: dark ? const Color(0xFF3B485D) : const Color(0xFF9AA8BB),
          outlineVariant: dark
              ? const Color(0xFF273142)
              : const Color(0xFFD0D8E4),
        );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: dark
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
        fillColor: scheme.surfaceContainerHigh,
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
        backgroundColor: dark ? const Color(0xFF11151D) : Colors.white,
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
        // Soft diffuse shadow instead of a hard outline. In light mode the
        // shadow carries the depth; in dark mode a faint tinted border keeps
        // the card readable against the near-black background.
        color: dark ? const Color(0xFF11151D) : Colors.white,
        surfaceTintColor: Colors.transparent,
        shadowColor: dark
            ? Colors.black.withAlpha(140)
            : const Color(0xFF0F172A).withAlpha(24),
        elevation: dark ? 0 : 3,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: dark
              ? BorderSide(color: scheme.outlineVariant.withAlpha(60))
              : BorderSide.none,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        space: 1,
        thickness: 1,
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
