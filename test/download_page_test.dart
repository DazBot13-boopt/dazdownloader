import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dazdownloader/features/download/domain/media_engine.dart';
import 'package:dazdownloader/features/download/presentation/download_controller.dart';
import 'package:dazdownloader/features/download/presentation/download_page.dart';

import 'support/test_media_engine.dart';

void main() {
  testWidgets(
    'download button drives progress, saved result and file opening',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 932));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final engine = TestMediaEngine();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [mediaEngineProvider.overrideWithValue(engine)],
          child: MaterialApp(
            home: DownloadPage(url: testPreview.sourceUrl.toString()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Vidéo de test'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('720p · MP4'), 250);
      expect(find.text('720p · MP4'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Télécharger'), 250);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Télécharger'));
      await tester.pump();
      engine.emit(percent: 100);
      await tester.pump();
      expect(find.text('Téléchargement terminé'), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      engine.downloadCompleter!.complete(testDownload);
      await tester.pumpAndSettle();
      expect(find.text('Téléchargement terminé'), findsOneWidget);
      await tester.ensureVisible(find.text('Ouvrir le fichier'));
      await tester.tap(find.text('Ouvrir le fichier'));
      await tester.pump();
      expect(engine.opened, isTrue);
      await tester.pumpWidget(const SizedBox());
      await engine.events.close();
    },
  );

  testWidgets('a restored link is never analyzed again on its own', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final engine = TestMediaEngine()
      ..persistedTransfer = TransferSnapshot(
        taskId: 'native-download',
        state: 'completed',
        url: testPreview.sourceUrl,
        result: testDownload,
      );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [mediaEngineProvider.overrideWithValue(engine)],
        child: MaterialApp(
          home: DownloadPage(
            url: testPreview.sourceUrl.toString(),
            restored: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(engine.resolveCalls, 0);
    expect(find.text('Dernière analyse'), findsOneWidget);
    expect(find.text('Téléchargement terminé'), findsOneWidget);

    // The engine only runs again when the user explicitly asks for it.
    await tester.ensureVisible(find.text('Réessayer l’analyse'));
    await tester.tap(find.text('Réessayer l’analyse'));
    await tester.pumpAndSettle();
    expect(engine.resolveCalls, 1);

    await tester.pumpWidget(const SizedBox());
    await engine.events.close();
  });
}
