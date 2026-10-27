import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'package:dazdownloader/core/settings/theme_mode_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
  });

  test('a fresh installation follows the system', () async {
    expect(await ThemeModeController.loadInitialMode(), ThemeMode.system);
  });

  test('an existing choice survives the move to three modes', () async {
    // Before this change the preference was a plain boolean. Someone who had
    // already picked a side must not be moved onto the system theme.
    for (final (dark, expected) in [
      (true, ThemeMode.dark),
      (false, ThemeMode.light),
    ]) {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      await SharedPreferencesAsync().setBool('loady.theme.dark_mode', dark);
      expect(await ThemeModeController.loadInitialMode(), expected);
    }
  });

  test('each of the three modes is stored and read back', () async {
    for (final mode in ThemeMode.values) {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      await SharedPreferencesAsync().setString('loady.theme.mode', mode.name);
      expect(await ThemeModeController.loadInitialMode(), mode);
    }
  });

  test('the new preference wins over the legacy boolean', () async {
    await SharedPreferencesAsync().setBool('loady.theme.dark_mode', true);
    await SharedPreferencesAsync().setString('loady.theme.mode', 'light');
    expect(await ThemeModeController.loadInitialMode(), ThemeMode.light);
  });

  test('an unreadable value falls back to the system theme', () async {
    await SharedPreferencesAsync().setString('loady.theme.mode', 'neon');
    expect(await ThemeModeController.loadInitialMode(), ThemeMode.system);
  });
}
