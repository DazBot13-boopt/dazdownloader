import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final themeModeProvider = NotifierProvider<ThemeModeController, ThemeMode>(
  () => ThemeModeController(ThemeMode.system),
);

class ThemeModeController extends Notifier<ThemeMode> {
  ThemeModeController(this.initialMode);

  final ThemeMode initialMode;
  static const _modeKey = 'loady.theme.mode';

  /// Installations from before the three-way choice stored a plain boolean.
  static const _legacyDarkModeKey = 'loady.theme.dark_mode';

  static Future<ThemeMode> loadInitialMode() async {
    try {
      final preferences = SharedPreferencesAsync();
      final stored = await preferences.getString(_modeKey);
      for (final mode in ThemeMode.values) {
        if (mode.name == stored) return mode;
      }
      // Someone who already picked a side keeps it. Only an installation that
      // never chose follows the system, which is what the old subtitle
      // promised without ever doing it.
      final legacy = await preferences.getBool(_legacyDarkModeKey);
      if (legacy == null) return ThemeMode.system;
      return legacy ? ThemeMode.dark : ThemeMode.light;
    } catch (_) {
      return ThemeMode.system;
    }
  }

  @override
  ThemeMode build() => initialMode;

  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    try {
      await SharedPreferencesAsync().setString(_modeKey, mode.name);
    } catch (_) {
      // Keep the current session usable if preferences cannot be written.
    }
  }
}
