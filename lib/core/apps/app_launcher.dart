import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// An app installed on the phone, with the name and icon Android shows.
class InstalledApp {
  const InstalledApp({
    required this.packageName,
    required this.label,
    this.icon,
  });

  final String packageName;
  final String label;

  /// PNG bytes of the launcher icon, when Android could provide it.
  final Uint8List? icon;
}

/// Finds and opens other apps by their Android package name.
abstract class AppLauncher {
  /// The [packages] that are installed and can be opened, in the same order.
  Future<List<InstalledApp>> installed(List<String> packages);

  /// Opens [packageName]; false when it could not be started.
  Future<bool> launch(String packageName);
}

class AndroidAppLauncher implements AppLauncher {
  static const channel = MethodChannel('dazdownloader/apps');

  @override
  Future<List<InstalledApp>> installed(List<String> packages) async {
    try {
      final result = await channel.invokeListMethod<Map<Object?, Object?>>(
        'installed',
        {'packages': packages},
      );
      return [
        for (final app in result ?? const <Map<Object?, Object?>>[])
          InstalledApp(
            packageName: app['package']! as String,
            label: app['label']! as String,
            icon: app['icon'] as Uint8List?,
          ),
      ];
    } on PlatformException {
      return const [];
    } on MissingPluginException {
      return const [];
    }
  }

  @override
  Future<bool> launch(String packageName) async {
    try {
      return await channel.invokeMethod<bool>('launch', {
            'package': packageName,
          }) ??
          false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}

final appLauncherProvider = Provider<AppLauncher>(
  (ref) => AndroidAppLauncher(),
);
