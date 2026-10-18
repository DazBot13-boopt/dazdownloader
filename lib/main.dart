import 'dart:async' show unawaited;
import 'dart:io' show Platform;

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/ads/ads_controller.dart';
import 'core/analytics/analytics_service.dart';
import 'core/notifications/messaging_init.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final analytics = await _initAnalytics();
  await analytics.logAppOpen();
  final container = ProviderContainer(
    overrides: [analyticsServiceProvider.overrideWithValue(analytics)],
  );
  // Fire-and-forget: these inits involve permission prompts and network
  // round-trips and shouldn't gate the first frame.
  unawaited(initMessaging());
  unawaited(initAds(container));
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
