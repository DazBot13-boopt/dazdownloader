import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The edition (full or Lite) the user chose to always open for a platform,
/// remembered after "Toujours" in the choice sheet.
class PreferredApps {
  static const _prefix = 'loady.preferred_app.';

  /// Package remembered for [platform] (a `MediaPlatform.name`), if any.
  Future<String?> get(String platform) async {
    try {
      return await SharedPreferencesAsync().getString('$_prefix$platform');
    } catch (_) {
      return null;
    }
  }

  Future<void> remember(String platform, String packageName) async {
    try {
      await SharedPreferencesAsync().setString(
        '$_prefix$platform',
        packageName,
      );
    } catch (_) {
      // The choice still applies now; only remembering it is lost.
    }
  }

  Future<bool> hasAny() async {
    try {
      final keys = await SharedPreferencesAsync().getKeys();
      return keys.any((key) => key.startsWith(_prefix));
    } catch (_) {
      return false;
    }
  }

  Future<void> forgetAll() async {
    try {
      final preferences = SharedPreferencesAsync();
      final keys = await preferences.getKeys();
      await preferences.clear(
        allowList: {
          for (final key in keys)
            if (key.startsWith(_prefix)) key,
        },
      );
    } catch (_) {
      // Nothing more to do: the next tap simply keeps the old choice.
    }
  }
}

final preferredAppsProvider = Provider<PreferredApps>((ref) => PreferredApps());
