import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'package:dazdownloader/app.dart';
import 'package:dazdownloader/core/apps/app_launcher.dart';
import 'package:dazdownloader/core/apps/preferred_apps.dart';
import 'package:dazdownloader/features/download/domain/media_models.dart';
import 'package:dazdownloader/features/history/data/download_history.dart';

class _FakeLauncher implements AppLauncher {
  _FakeLauncher(this.labels);

  /// Installed packages and their names.
  final Map<String, String> labels;
  final launched = <String>[];

  @override
  Future<List<InstalledApp>> installed(List<String> packages) async => [
    for (final name in packages)
      if (labels.containsKey(name))
        InstalledApp(packageName: name, label: labels[name]!),
  ];

  @override
  Future<bool> launch(String packageName) async {
    launched.add(packageName);
    return true;
  }
}

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          DownloadHistory.channel,
          (call) async => call.method == 'history' ? <dynamic>[] : null,
        );
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(DownloadHistory.channel, null);
  });

  Future<void> tapPlatform(
    WidgetTester tester,
    _FakeLauncher launcher,
    String label,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appLauncherProvider.overrideWithValue(launcher)],
        child: const DazDownloaderApp(),
      ),
    );
    await tester.pumpAndSettle();
    final card = find.text(label);
    await tester.ensureVisible(card);
    await tester.tap(card);
    await tester.pumpAndSettle();
  }

  testWidgets('a single installed app opens directly', (tester) async {
    final launcher = _FakeLauncher({'com.twitter.android': 'X'});
    await tapPlatform(tester, launcher, 'X');

    expect(find.text('Ouvrir X avec :'), findsNothing);
    expect(launcher.launched, ['com.twitter.android']);
  });

  testWidgets('both editions installed: asks which one to open', (
    tester,
  ) async {
    final launcher = _FakeLauncher({
      'com.instagram.android': 'Instagram',
      'com.instagram.lite': 'Instagram Lite',
    });
    await tapPlatform(tester, launcher, 'Instagram');

    expect(find.text('Ouvrir Instagram avec :'), findsOneWidget);
    expect(launcher.launched, isEmpty);

    await tester.tap(find.text('Instagram Lite'));
    await tester.pumpAndSettle();
    expect(launcher.launched, isEmpty, reason: 'waits for once or always');

    await tester.tap(find.text('Une seule fois'));
    await tester.pumpAndSettle();
    expect(launcher.launched, ['com.instagram.lite']);

    // "Une seule fois" remembers nothing: the next tap asks again.
    await tester.tap(find.text('Instagram'));
    await tester.pumpAndSettle();
    expect(find.text('Ouvrir Instagram avec :'), findsOneWidget);
  });

  testWidgets('"Toujours" opens the chosen edition directly next time', (
    tester,
  ) async {
    final launcher = _FakeLauncher({
      'com.zhiliaoapp.musically': 'TikTok',
      'com.zhiliaoapp.musically.go': 'TikTok Lite',
    });
    await tapPlatform(tester, launcher, 'TikTok');
    await tester.tap(find.text('TikTok Lite'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Toujours'));
    await tester.pumpAndSettle();
    expect(launcher.launched, ['com.zhiliaoapp.musically.go']);

    await tester.tap(find.text('TikTok'));
    await tester.pumpAndSettle();
    expect(find.text('Ouvrir TikTok avec :'), findsNothing);
    expect(launcher.launched, [
      'com.zhiliaoapp.musically.go',
      'com.zhiliaoapp.musically.go',
    ]);

    // Forgetting the choice in Réglages brings the question back.
    await PreferredApps().forgetAll();
    await tester.tap(find.text('TikTok'));
    await tester.pumpAndSettle();
    expect(find.text('Ouvrir TikTok avec :'), findsOneWidget);
  });

  testWidgets('dismissing the choice opens nothing', (tester) async {
    final launcher = _FakeLauncher({
      'com.facebook.katana': 'Facebook',
      'com.facebook.lite': 'Facebook Lite',
    });
    await tapPlatform(tester, launcher, 'Facebook');
    expect(find.text('Ouvrir Facebook avec :'), findsOneWidget);

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.text('Ouvrir Facebook avec :'), findsNothing);
    expect(launcher.launched, isEmpty);
  });

  test('the manifest lets Loady see every platform app', () {
    // Since Android 11 a package missing from <queries> looks uninstalled.
    final manifest = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync();
    for (final platform in MediaPlatform.values) {
      for (final name in platform.appPackages) {
        expect(
          manifest,
          contains('<package android:name="$name"/>'),
          reason: '$name (${platform.label})',
        );
      }
    }
  });
}
