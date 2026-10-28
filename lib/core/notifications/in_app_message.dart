import 'package:flutter/material.dart';

/// Lets code outside the widget tree, such as the Firebase message listener,
/// show a message in whichever screen is open.
final appMessengerKey = GlobalKey<ScaffoldMessengerState>();

/// Shows an announcement received while the app is open. Android only
/// displays push notifications by itself when the app is in the background.
void showInAppMessage({String? title, String? body}) {
  final text = [title, body]
      .whereType<String>()
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .join('\n');
  final messenger = appMessengerKey.currentState;
  if (text.isEmpty || messenger == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(text),
        duration: const Duration(seconds: 8),
        showCloseIcon: true,
      ),
    );
}
