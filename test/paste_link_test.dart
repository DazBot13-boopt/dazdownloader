import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dazdownloader/app.dart';
import 'package:dazdownloader/core/routing/app_router.dart';

void main() {
  testWidgets(
    'pasting is idle and native initialization failures stay visible',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 932));
      final messenger = tester.binding.defaultBinaryMessenger;
      const methods = MethodChannel('dazdownloader/media');
      const events = MethodChannel('dazdownloader/media/progress');
      const url = 'https://www.youtube.com/watch?v=test';
      const message =
          'Le moteur Android n’a pas pu démarrer (ExceptionInInitializerError). '
          'Envoyez une capture de ce message avec le modèle du téléphone.';
      var resolveCalls = 0;

      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.getData') return {'text': ' $url '};
        return null;
      });
      messenger.setMockMethodCallHandler(events, (_) async => null);
      messenger.setMockMethodCallHandler(methods, (call) async {
        if (call.method == 'update') {
          return {'engineVersion': '2026.10.14'};
        }
        expect(call.method, 'resolve');
        expect(call.arguments['url'], url);
        resolveCalls++;
        throw PlatformException(
          code: 'engine_initialization',
          message: message,
        );
      });
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        messenger.setMockMethodCallHandler(SystemChannels.platform, null);
        messenger.setMockMethodCallHandler(methods, null);
        messenger.setMockMethodCallHandler(events, null);
        appRouter.go('/');
        await tester.binding.setSurfaceSize(null);
      });

      appRouter.go('/');
      await tester.pumpWidget(const ProviderScope(child: DazDownloaderApp()));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byTooltip('Coller le lien'));
      await tester.tap(find.byTooltip('Coller le lien'));
      await tester.pumpAndSettle();

      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        url,
      );
      expect(resolveCalls, 0);
      expect(find.text('Analyser le lien'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.ensureVisible(find.text('Analyser le lien'));
      await tester.tap(find.text('Analyser le lien'));
      await tester.pumpAndSettle();

      expect(resolveCalls, 1);
      expect(find.text(message), findsOneWidget);
      expect(find.text('Téléchargement terminé'), findsNothing);
      expect(tester.takeException(), isNull);

      await tester.ensureVisible(
        find.text('Redémarrer le moteur et réessayer'),
      );
      await tester.tap(find.text('Redémarrer le moteur et réessayer'));
      await tester.pumpAndSettle();
      expect(resolveCalls, 2);
      expect(find.text(message), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant({TargetPlatform.android}),
  );
}
