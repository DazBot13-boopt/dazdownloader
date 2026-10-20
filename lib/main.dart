import 'dart:async' show unawaited;
import 'dart:io' show Platform;

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/analytics/analytics_service.dart';
import 'core/notifications/messaging_init.dart';
import 'core/settings/theme_mode_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final results = await Future.wait<Object>([
    _initAnalytics(),
    ThemeModeController.loadInitialMode(),
  ]);
  final analytics = results[0] as AnalyticsService;
  final initialThemeMode = results[1] as ThemeMode;
  await analytics.logAppOpen();
  final container = ProviderContainer(
    overrides: [
      analyticsServiceProvider.overrideWithValue(analytics),
      themeModeProvider.overrideWith(() => ThemeModeController(initialThemeMode)),
    ],
  );
  // Fire-and-forget: FCM init involves a permission prompt and network
  // round-trips and shouldn't gate the first frame.
  unawaited(initMessaging());
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const DazDownloaderApp(),
    ),
  );
}

Future<AnalyticsService> _initAnalytics() async {
  // Firebase is only wired for Android; the web preview and iOS stubs ship
  // without a config and we don't want Firebase.initializeApp to throw there.
  if (kIsWeb || !Platform.isAndroid) {
    return const NoopAnalyticsService();
  }
  try {
    await Firebase.initializeApp();
    return FirebaseAnalyticsService(FirebaseAnalytics.instance);
  } catch (error, stack) {
    debugPrint('Firebase init failed, analytics disabled: $error\n$stack');
    return const NoopAnalyticsService();
  }
}
