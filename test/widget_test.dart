import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dazdownloader/app.dart';
import 'package:dazdownloader/features/download/presentation/download_controller.dart';
import 'package:dazdownloader/features/download/domain/media_models.dart';

import 'support/test_media_engine.dart';

void main() {
  testWidgets('renders the home experience', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: DazDownloaderApp()));
    await tester.pumpAndSettle();

    expect(find.text('Loady'), findsOneWidget);
    expect(find.text('Analyser le lien'), findsOneWidget);
    expect(find.text('Plateformes prises en charge'), findsOneWidget);
  });

  testWidgets('analysis remains available while navigating between tabs', (
    tester,
  ) async {
    final engine = TestMediaEngine()
      ..resolveCompleter = Completer<MediaPreview>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [mediaEngineProvider.overrideWithValue(engine)],
        child: const DazDownloaderApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextField),
      'https://www.youtube.com/watch?v=test',
    );
    await tester.tap(find.text('Analyser le lien'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      find.text('Analyse du lien et des formats disponibles…'),
      findsOneWidget,
    );
    expect(engine.resolveCalls, 1);

    await tester.tap(find.text('Historique'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('Analyse').first);
    await tester.pump(const Duration(milliseconds: 500));

    expect(
      find.text('Analyse du lien et des formats disponibles…'),
      findsOneWidget,
    );
    expect(engine.resolveCalls, 1);
    await engine.events.close();
  });
}
