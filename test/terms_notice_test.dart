import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'package:dazdownloader/core/settings/terms_notice_controller.dart';
import 'package:dazdownloader/features/legal/presentation/terms_notice.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  test('a fresh installation has not accepted the notice', () async {
    expect(await TermsNoticeController.loadAccepted(), isFalse);
  });

  test('an older accepted version shows the notice again', () async {
    await SharedPreferencesAsync().setInt(
      'loady.terms.accepted_version',
      TermsNoticeController.currentVersion - 1,
    );
    expect(await TermsNoticeController.loadAccepted(), isFalse);
  });

  Widget gate({required bool accepted}) => ProviderScope(
    overrides: [
      termsNoticeProvider.overrideWith(() => TermsNoticeController(accepted)),
    ],
    child: const MaterialApp(
      home: TermsNoticeGate(child: Scaffold(body: Text('Accueil'))),
    ),
  );

  testWidgets('the notice covers the app until it is accepted', (tester) async {
    await tester.pumpWidget(gate(accepted: false));

    expect(find.text('Avant de commencer'), findsOneWidget);
    expect(find.text('Lire les conditions'), findsOneWidget);

    // Tapping the barrier must not dismiss it.
    await tester.tapAt(const Offset(5, 5));
    await tester.pump();
    expect(find.text('Avant de commencer'), findsOneWidget);

    await tester.tap(find.text('J’ai compris'));
    await tester.pumpAndSettle();

    expect(find.text('Avant de commencer'), findsNothing);
    expect(find.text('Accueil'), findsOneWidget);
    expect(await TermsNoticeController.loadAccepted(), isTrue);
  });

  testWidgets('an accepted notice is not shown', (tester) async {
    await tester.pumpWidget(gate(accepted: true));

    expect(find.text('Avant de commencer'), findsNothing);
    expect(find.text('Accueil'), findsOneWidget);
  });

  testWidgets('the notice fits a narrow phone with large text', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 560));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(gate(accepted: false));
    expect(tester.takeException(), isNull);
    expect(find.text('J’ai compris'), findsOneWidget);
  });
}
