import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dazdownloader/core/notifications/in_app_message.dart';

void main() {
  Future<void> pumpScreen(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      scaffoldMessengerKey: appMessengerKey,
      home: const Scaffold(body: SizedBox()),
    ),
  );

  testWidgets('shows an announcement received while the app is open', (
    tester,
  ) async {
    await pumpScreen(tester);

    showInAppMessage(title: 'Bonne année', body: 'Merci d’utiliser Loady.');
    await tester.pump();

    expect(find.text('Bonne année\nMerci d’utiliser Loady.'), findsOneWidget);
  });

  testWidgets('ignores a message without any text', (tester) async {
    await pumpScreen(tester);

    showInAppMessage(title: '  ', body: null);
    await tester.pump();

    expect(find.byType(SnackBar), findsNothing);
  });
}
