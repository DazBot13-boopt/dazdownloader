import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dazdownloader/features/download/domain/media_engine.dart';
import 'package:dazdownloader/features/download/domain/media_models.dart';
import 'package:dazdownloader/features/download/data/download_session_store.dart';
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
    // The cancel button appears only once the state turns busy, which happens
    // after the pending link is saved. Cancelling before that reaches no task.
    await Future<void>.delayed(Duration.zero);
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

  test('an interrupted analysis is offered again, never relaunched', () async {
    const savedUrl = 'https://www.youtube.com/watch?v=test';
    final store = _MemorySessionStore(savedUrl);
    final restoredContainer = ProviderContainer(
      overrides: [
        mediaEngineProvider.overrideWithValue(engine),
        downloadSessionStoreProvider.overrideWithValue(store),
      ],
    );
    addTearDown(restoredContainer.dispose);

    // Building the provider begins the asynchronous restoration.
    restoredContainer.read(downloadControllerProvider);
    await Future<void>.delayed(Duration.zero);

    final restored = restoredContainer.read(downloadControllerProvider);
    // The link comes back with a manual retry; waking the engine on its own
    // is what made every launch re-analyze the last link.
    expect(engine.resolveCalls, 0);
    expect(restored.status, DownloadStatus.failed);
    expect(restored.url, Uri.parse(savedUrl));
    expect(restored.preview, isNull);
    expect(restored.restored, isTrue);
    expect(store.value, isNull);

    restoredContainer
        .read(downloadControllerProvider.notifier)
        .consumeRestoreNavigation();
    expect(
      restoredContainer.read(downloadControllerProvider).restored,
      isFalse,
    );
  });

  test(
    'restores a completed native transfer after the application restarts',
    () async {
      engine.persistedTransfer = TransferSnapshot(
        taskId: 'native-download',
        state: 'completed',
        url: testPreview.sourceUrl,
        result: testDownload,
      );
      final restoredContainer = ProviderContainer(
        overrides: [
          mediaEngineProvider.overrideWithValue(engine),
          downloadSessionStoreProvider.overrideWithValue(
            _MemorySessionStore(null),
          ),
        ],
      );
      addTearDown(restoredContainer.dispose);

      restoredContainer.read(downloadControllerProvider);
      await Future<void>.delayed(Duration.zero);

      final restored = restoredContainer.read(downloadControllerProvider);
      expect(restored.status, DownloadStatus.completed);
      expect(restored.url, testPreview.sourceUrl);
      expect(restored.result, same(testDownload));
      expect(restored.restored, isTrue);
    },
  );

  test(
    'a finished download does not relaunch an analysis on the next launch',
    () async {
      // Simulate the full happy path: analyze → download → complete.
      await controller.resolve(testPreview.sourceUrl.toString());
      final operation = controller.download(testFormat);
      engine.downloadCompleter!.complete(testDownload);
      await operation;
      expect(state().status, DownloadStatus.completed);

      // The in-memory store should also forget the link, so the Android
      // engine's own transfer journal is the only source for restoration.
      final followUpStore = _MemorySessionStore(null);
      final followUpEngine = TestMediaEngine();
      final followUpContainer = ProviderContainer(
        overrides: [
          mediaEngineProvider.overrideWithValue(followUpEngine),
          downloadSessionStoreProvider.overrideWithValue(followUpStore),
        ],
      );
      addTearDown(() async {
        followUpContainer.dispose();
        await followUpEngine.events.close();
      });

      followUpContainer.read(downloadControllerProvider);
      await Future<void>.delayed(Duration.zero);

      final after = followUpContainer.read(downloadControllerProvider);
      expect(after.status, DownloadStatus.idle);
      expect(followUpEngine.resolveCalls, 0);
    },
  );

  test('a restored transfer is surfaced once, not on every launch', () async {
    final store = _MemorySessionStore(null);
    final transfer = TransferSnapshot(
      taskId: 'native-download',
      state: 'completed',
      url: testPreview.sourceUrl,
      result: testDownload,
    );

    // Each call stands for a cold launch: the native journal keeps its entry
    // until a new transfer replaces it, so it is read again every time.
    Future<DownloadState> launch() async {
      final launchEngine = TestMediaEngine()..persistedTransfer = transfer;
      final launchContainer = ProviderContainer(
        overrides: [
          mediaEngineProvider.overrideWithValue(launchEngine),
          downloadSessionStoreProvider.overrideWithValue(store),
        ],
      );
      addTearDown(() async {
        launchContainer.dispose();
        await launchEngine.events.close();
      });
      launchContainer.read(downloadControllerProvider);
      await Future<void>.delayed(Duration.zero);
      return launchContainer.read(downloadControllerProvider);
    }

    final first = await launch();
    expect(first.status, DownloadStatus.completed);
    expect(first.restored, isTrue);
    expect(store.seen, 'native-download');

    final second = await launch();
    expect(second.status, DownloadStatus.idle);
    expect(second.restored, isFalse);
    expect(second.url, isNull);
  });

  test('watching a download finish marks its transfer as seen', () async {
    final store = _MemorySessionStore(null);
    final watched = ProviderContainer(
      overrides: [
        mediaEngineProvider.overrideWithValue(engine),
        downloadSessionStoreProvider.overrideWithValue(store),
      ],
    );
    addTearDown(watched.dispose);
    final notifier = watched.read(downloadControllerProvider.notifier);

    await notifier.resolve(testPreview.sourceUrl.toString());
    final operation = notifier.download(testFormat);
    engine.downloadCompleter!.complete(testDownload);
    await operation;

    expect(watched.read(downloadControllerProvider).status,
        DownloadStatus.completed);
    expect(store.seen, isNotNull);
    expect(store.value, isNull);
  });

  test(
    'restoring a completed native transfer also clears the pending link',
    () async {
      final store = _MemorySessionStore(testPreview.sourceUrl.toString());
      engine.persistedTransfer = TransferSnapshot(
        taskId: 'native-download',
        state: 'completed',
        url: testPreview.sourceUrl,
        result: testDownload,
      );
      final restoredContainer = ProviderContainer(
        overrides: [
          mediaEngineProvider.overrideWithValue(engine),
          downloadSessionStoreProvider.overrideWithValue(store),
        ],
      );
      addTearDown(restoredContainer.dispose);

      restoredContainer.read(downloadControllerProvider);
      await Future<void>.delayed(Duration.zero);

      expect(store.value, isNull);
      expect(engine.resolveCalls, 0);
    },
  );
}

class _MemorySessionStore extends DownloadSessionStore {
  _MemorySessionStore(this.value);

  String? value;
  String? seen;

  @override
  Future<String?> readPendingUrl() async => value;

  @override
  Future<void> savePendingUrl(String url) async {
    value = url;
  }

  @override
  Future<void> clearPendingUrl() async {
    value = null;
  }

  @override
  Future<String?> readSeenTransferId() async => seen;

  @override
  Future<void> saveSeenTransferId(String taskId) async {
    seen = taskId;
  }
}
