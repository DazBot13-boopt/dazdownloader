import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final themeModeProvider = NotifierProvider<ThemeModeController, ThemeMode>(
  () => ThemeModeController(ThemeMode.light),
);

class ThemeModeController extends Notifier<ThemeMode> {
  ThemeModeController(this.initialMode);

  final ThemeMode initialMode;
  static const _darkModeKey = 'loady.theme.dark_mode';

  static Future<ThemeMode> loadInitialMode() async {
    try {
      final dark = await SharedPreferencesAsync().getBool(_darkModeKey);
      return dark == true ? ThemeMode.dark : ThemeMode.light;
    } catch (_) {
      return ThemeMode.light;
    }
  }

  @override
  ThemeMode build() => initialMode;

  Future<void> setDarkMode(bool enabled) async {
    state = enabled ? ThemeMode.dark : ThemeMode.light;
    try {
      await SharedPreferencesAsync().setBool(_darkModeKey, enabled);
    } catch (_) {
      // Keep the current session usable if preferences cannot be written.
    }
  }
}
