import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dazdownloader/app.dart';
import 'package:dazdownloader/core/update/update_checker.dart';
import 'package:dazdownloader/features/history/data/download_history.dart';

class _FakeUpdateChecker implements UpdateChecker {
  _FakeUpdateChecker(this.result);

  final UpdateCheckResult result;
  String? dismissed;

  @override
  Future<UpdateCheckResult> check({bool force = false}) async => result;

  @override
  Future<void> dismiss(String version) async => dismissed = version;
}

void main() {
  group('isNewerVersion', () {
    test('detects a higher major, minor or patch', () {
      expect(isNewerVersion('2.0.0', '1.13.0'), isTrue);
      expect(isNewerVersion('1.14.0', '1.13.0'), isTrue);
      expect(isNewerVersion('1.13.1', '1.13.0'), isTrue);
      // Numeric, not alphabetical: 1.10 is after 1.9.
      expect(isNewerVersion('1.10.0', '1.9.0'), isTrue);
    });

    test('ignores the same or an older version', () {
      expect(isNewerVersion('1.13.0', '1.13.0'), isFalse);
      expect(isNewerVersion('1.12.9', '1.13.0'), isFalse);
      expect(isNewerVersion('0.9.0', '1.13.0'), isFalse);
    });

    test('accepts a tag prefix and a build suffix', () {
      expect(isNewerVersion('v1.14.0', '1.13.0+34'), isTrue);
      expect(isNewerVersion('1.13.0+35', '1.13.0+34'), isFalse);
    });

    test('never treats an unparsable version as newer', () {
      expect(isNewerVersion('', '1.13.0'), isFalse);
      expect(isNewerVersion('latest', '1.13.0'), isFalse);
      expect(isNewerVersion('1.14', '1.13.0'), isFalse);
      expect(isNewerVersion('2.0.0', 'inconnue'), isFalse);
    });
  });

  group('home update card', () {
    setUp(() {
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

    Future<void> pumpHome(WidgetTester tester, UpdateChecker checker) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [updateCheckerProvider.overrideWithValue(checker)],
          child: const DazDownloaderApp(),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('offers a newer version and hides it on "Plus tard"', (
      tester,
    ) async {
      final checker = _FakeUpdateChecker(
        const UpdateCheckResult(UpdateCheckOutcome.available, '9.9.9'),
      );
      await pumpHome(tester, checker);

      expect(find.text('Loady 9.9.9 est disponible'), findsOneWidget);
      expect(find.text('Télécharger'), findsOneWidget);

      await tester.tap(find.text('Plus tard'));
      await tester.pumpAndSettle();

      expect(find.text('Loady 9.9.9 est disponible'), findsNothing);
      expect(checker.dismissed, '9.9.9');
    });

    for (final outcome in [
      UpdateCheckOutcome.upToDate,
      UpdateCheckOutcome.failed,
      UpdateCheckOutcome.unsupported,
    ]) {
      testWidgets('shows nothing when the check is ${outcome.name}', (
        tester,
      ) async {
        await pumpHome(tester, _FakeUpdateChecker(UpdateCheckResult(outcome)));

        expect(find.textContaining('est disponible'), findsNothing);
        expect(find.text('Analyser le lien'), findsOneWidget);
      });
    }
  });
}
