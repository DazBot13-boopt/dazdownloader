import 'dart:io' show Platform;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'in_app_message.dart';

/// Topic every device subscribes to so a single Firebase Console broadcast
/// reaches the whole fleet without maintaining a token registry.
const _broadcastTopic = 'all';

/// Wires Firebase Cloud Messaging on Android. No-op on web/iOS so the
/// non-Android builds don't crash on the missing config.
Future<void> initMessaging() async {
  if (kIsWeb || !Platform.isAndroid) return;
  try {
    final messaging = FirebaseMessaging.instance;

    // Android 13+ requires an explicit opt-in via POST_NOTIFICATIONS.
    // On older versions this returns authorized immediately.
    final settings = await messaging.requestPermission();
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      return;
    }

    await messaging.subscribeToTopic(_broadcastTopic);

    // Foreground messages: Firebase does not auto-display the system
    // notification while the app is in the foreground, so the announcement
    // is shown inside the app instead.
    FirebaseMessaging.onMessage.listen((message) {
      final notification = message.notification;
      showInAppMessage(title: notification?.title, body: notification?.body);
    });

    FirebaseMessaging.onBackgroundMessage(_backgroundHandler);
  } catch (error, stack) {
    debugPrint('FCM init failed: $error\n$stack');
  }
}

@pragma('vm:entry-point')
Future<void> _backgroundHandler(RemoteMessage message) async {
  // Must be top-level (dart:isolate rules). Firebase displays the system
  // notification from the message's `notification` payload automatically
  // when the app is backgrounded — nothing to do here for broadcast pushes.
}
