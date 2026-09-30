import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dazdownloader/features/download/domain/media_engine.dart';
import 'package:dazdownloader/features/download/domain/media_models.dart';
import 'package:dazdownloader/features/download/presentation/download_controller.dart';

import 'support/test_media_engine.dart';

void main() {
  late TestMediaEngine engine;
  late ProviderContainer container;
  late DownloadController controller;

  setUp(() {
    engine = TestMediaEngine();
    container = ProviderContainer(
      overrides: [mediaEngineProvider.overrideWithValue(engine)],
    );
    controller = container.read(downloadControllerProvider.notifier);
  });
  tearDown(() async {
    container.dispose();
    await engine.events.close();
  });

  DownloadState state() => container.read(downloadControllerProvider);

  test('invalid or unsupported URLs never reach the native engine', () async {
    await controller.resolve('https://youtube.com.evil.example/video');
    expect(state().status, DownloadStatus.failed);
    expect(engine.resolveCalls, 0);
  });

  test('resolves real metadata through the injected engine', () async {
    await controller.resolve(testPreview.sourceUrl.toString());
    expect(state().status, DownloadStatus.ready);
    expect(state().preview, same(testPreview));
    expect(state().result, isNull);
  });

  test('100 percent transfer is not a saved-file success', () async {
    await controller.resolve(testPreview.sourceUrl.toString());
    final operation = controller.download(testFormat);
    engine.emit(percent: 100);
    expect(state().status, DownloadStatus.downloading);
    expect(state().result, isNull);
    engine.emit(phase: MediaTransferPhase.processing);
    expect(state().status, DownloadStatus.processing);
    engine.emit(phase: MediaTransferPhase.saving);
    expect(state().status, DownloadStatus.saving);
    engine.downloadCompleter!.complete(testDownload);
    await operation;
    expect(state().status, DownloadStatus.completed);
    expect(state().result, testDownload);
    await controller.openResult();
    expect(engine.opened, isTrue);
  });

  test('blocks duplicate clicks and ignores stale progress', () async {
    await controller.resolve(testPreview.sourceUrl.toString());
    final operation = controller.download(testFormat);
    await controller.download(testFormat);
    await controller.resolve('https://www.tiktok.com/@a/video/1');
    expect(engine.downloadCalls, 1);
    expect(engine.resolveCalls, 1);
    engine.emit(id: 'old-job');
    expect(state().progress, isNull);
    engine.downloadCompleter!.complete(testDownload);
    await operation;
    engine.emit();
    expect(state().status, DownloadStatus.completed);
  });

  test('native storage failure cannot leave a success result', () async {
    await controller.resolve(testPreview.sourceUrl.toString());
    final operation = controller.download(testFormat);
    engine.emit(percent: 100);
    engine.downloadCompleter!.completeError(
      const MediaEngineException('storage_full', 'Stockage plein'),
    );
    await operation;
    expect(state().status, DownloadStatus.failed);
    expect(state().result, isNull);
    expect(state().error, 'Stockage plein');
    expect(state().preview, isNotNull);
  });

  test(
    'cancellation waits for native acknowledgement and allows retry',
    () async {
      await controller.resolve(testPreview.sourceUrl.toString());
      final operation = controller.download(testFormat);
      await controller.cancel();
      await operation;
      expect(state().status, DownloadStatus.cancelled);
      expect(state().result, isNull);
      final retry = controller.download(testFormat);
      engine.downloadCompleter!.complete(testDownload);
      await retry;
      expect(state().status, DownloadStatus.completed);
    },
  );

  test('completion wins if cancellation comes after publication', () async {
    await controller.resolve(testPreview.sourceUrl.toString());
    final operation = controller.download(testFormat);
    engine.acceptCancel = false;
    await controller.cancel();
    expect(state().status, DownloadStatus.downloading);
    engine.downloadCompleter!.complete(testDownload);
    await operation;
    expect(state().status, DownloadStatus.completed);
  });

  test('can cancel metadata resolution and recover', () async {
    engine.resolveCompleter = Completer<MediaPreview>();
    final operation = controller.resolve(testPreview.sourceUrl.toString());
    await controller.cancel();
    await operation;
    expect(state().status, DownloadStatus.cancelled);
    engine.resolveCompleter = null;
    await controller.resolve(testPreview.sourceUrl.toString());
    expect(state().status, DownloadStatus.ready);
  });

  test(
    'engine update refreshes metadata instead of reusing an expired preview',
    () async {
      await controller.resolve(testPreview.sourceUrl.toString());
      await controller.updateEngine();
      expect(engine.updateCalls, 1);
      expect(engine.resolveCalls, 2);
      expect(state().status, DownloadStatus.ready);
      expect(state().engineVersion, '2026.08.19');
    },
  );

  test(
    'photo transfer does not complete before all saved files are returned',
    () async {
      engine.preview = testAlbum;
      await controller.resolve(testAlbum.sourceUrl.toString());
      final operation = controller.download(testPhotoFormat);
      engine.emit(percent: 100);
      expect(state().result, isNull);
      engine.downloadCompleter!.complete(testAlbumDownload);
      await operation;
      expect(state().result!.files.length, 2);
      await controller.openResult(testPhotos[1]);
      expect(engine.openedFile, same(testPhotos[1]));
    },
  );

  test(
    'failed Instagram retry retains update verification and diagnostic',
    () async {
      engine.resolutionError = const MediaEngineException(
        'instagram_limited',
        'Accès limité',
        diagnostic: 'Code : instagram_limited',
      );
      await controller.resolve('https://instagram.com/reel/test');
      await controller.updateEngine();
      expect(state().status, DownloadStatus.failed);
      expect(state().engineVersion, '2026.08.19');
      expect(state().diagnostic, 'Code : instagram_limited');
    },
  );
}
