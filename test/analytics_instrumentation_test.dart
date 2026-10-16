import 'package:dazdownloader/core/analytics/analytics_service.dart';
import 'package:dazdownloader/features/download/domain/media_engine.dart';
import 'package:dazdownloader/features/download/presentation/download_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_media_engine.dart';

class _RecordingAnalytics implements AnalyticsService {
  final events = <String>[];

  @override
  Future<void> logAppOpen() async => events.add('app_open');

  @override
  Future<void> logUrlAnalyzed({required String host, bool restored = false}) async =>
      events.add('url_analyzed:$host:restored=$restored');

  @override
  Future<void> logAnalyzeFailed({String? reason}) async =>
      events.add('url_analyze_failed:${reason ?? ''}');

  @override
  Future<void> logDownloadStarted({required String host, String? format}) async =>
      events.add('download_started:$host:$format');

  @override
  Future<void> logDownloadSuccess({
    required String host,
    String? format,
    int? bytes,
  }) async => events.add('download_success:$host:$format:$bytes');

  @override
  Future<void> logDownloadFailed({String? reason}) async =>
      events.add('download_failed:${reason ?? ''}');

  @override
  Future<void> logEngineUpdate({required bool success}) async =>
      events.add('engine_update:$success');
}

void main() {
  late TestMediaEngine engine;
  late _RecordingAnalytics analytics;
  late ProviderContainer container;
  late DownloadController controller;

  setUp(() {
    engine = TestMediaEngine();
    analytics = _RecordingAnalytics();
    container = ProviderContainer(
      overrides: [
        mediaEngineProvider.overrideWithValue(engine),
        analyticsServiceProvider.overrideWithValue(analytics),
      ],
    );
    controller = container.read(downloadControllerProvider.notifier);
  });
  tearDown(() async {
    container.dispose();
    await engine.events.close();
  });

  test('a successful analysis logs url_analyzed with the host', () async {
    await controller.resolve(testPreview.sourceUrl.toString());
    await Future.microtask(() {}); // flush unawaited fire-and-forget calls
    expect(
      analytics.events,
      contains('url_analyzed:www.youtube.com:restored=false'),
    );
  });

  test('a failed analysis logs url_analyze_failed with the engine code', () async {
    engine.resolutionError = const MediaEngineException(
      'network',
      'Pas de réseau',
    );
    await controller.resolve(testPreview.sourceUrl.toString());
    await Future.microtask(() {});
    expect(analytics.events, contains('url_analyze_failed:network'));
  });

  test('a cancellation is not reported as a failure', () async {
    engine.resolutionError = const MediaEngineException('cancelled', 'Annulé');
    await controller.resolve(testPreview.sourceUrl.toString());
    await Future.microtask(() {});
    expect(
      analytics.events.where((e) => e.startsWith('url_analyze_failed')),
      isEmpty,
    );
  });

  test('download emits started then success with the resolved size', () async {
    await controller.resolve(testPreview.sourceUrl.toString());
    final operation = controller.download(testFormat);
    engine.downloadCompleter!.complete(testDownload);
    await operation;
    await Future.microtask(() {});
    expect(
      analytics.events,
      containsAllInOrder([
        'download_started:www.youtube.com:mp4-720',
        'download_success:www.youtube.com:mp4-720:4096',
      ]),
    );
  });
}
