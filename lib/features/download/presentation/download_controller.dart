import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/analytics/analytics_service.dart';
import '../data/android_media_engine.dart';
import '../data/download_session_store.dart';
import '../domain/media_engine.dart';
import '../domain/media_models.dart';
import '../domain/media_url_parser.dart';

final mediaEngineProvider = Provider<MediaEngine>(
  (ref) => AndroidMediaEngine(),
);
final downloadSessionStoreProvider = Provider<DownloadSessionStore>(
  (ref) => DownloadSessionStore(),
);
final downloadControllerProvider =
    NotifierProvider<DownloadController, DownloadState>(DownloadController.new);

enum DownloadStatus {
  idle,
  resolving,
  ready,
  downloading,
  processing,
  saving,
  cancelling,
  cancelled,
  completed,
  failed,
  updating,
}

class DownloadState {
  const DownloadState({
    this.status = DownloadStatus.idle,
    this.url,
    this.preview,
    this.progress,
    this.result,
    this.error,
    this.diagnostic,
    this.engineVersion,
    this.restored = false,
  });

  final DownloadStatus status;
  final Uri? url;
  final MediaPreview? preview;
  final MediaProgress? progress;
  final DownloadedMedia? result;
  final String? error;
  final String? diagnostic;
  final String? engineVersion;
  final bool restored;

  bool get isBusy => switch (status) {
    DownloadStatus.resolving ||
    DownloadStatus.downloading ||
    DownloadStatus.processing ||
    DownloadStatus.saving ||
    DownloadStatus.cancelling ||
    DownloadStatus.updating => true,
    _ => false,
  };
}

class DownloadController extends Notifier<DownloadState> {
  late MediaEngine _engine;
  String? _activeTask;
  int _sequence = 0;
  bool _disposed = false;
  String? _engineVersion;
  late DownloadSessionStore _sessionStore;
  late AnalyticsService _analytics;

  @override
  DownloadState build() {
    _engine = ref.read(mediaEngineProvider);
    _sessionStore = ref.read(downloadSessionStoreProvider);
    _analytics = ref.read(analyticsServiceProvider);
    final subscription = _engine.progress.listen(
      _onProgress,
      onError: (_) {
        // Progress is advisory. Only the method result confirms completion.
      },
    );
    ref.onDispose(() {
      _disposed = true;
      unawaited(subscription.cancel());
      final task = _activeTask;
      if (task != null) {
        unawaited(_engine.cancel(task).then<void>((_) {}, onError: (_, _) {}));
      }
    });
    unawaited(_restoreSession());
    return const DownloadState();
  }

  Future<void> _restoreSession() async {
    await _restoreLastTransfer();
    if (state.url == null) await _restorePendingAnalysis();
  }

  Future<void> _restoreLastTransfer() async {
    try {
      final transfer = await _engine.lastTransfer();
      if (_disposed ||
          transfer == null ||
          transfer.url == null ||
          state.url != null) {
        return;
      }
      // The native journal keeps its entry until the next transfer replaces
      // it. Each outcome is therefore surfaced once; otherwise every later
      // launch would reopen the analysis screen for a finished download.
      final seen = await _sessionStore.readSeenTransferId();
      if (_disposed || seen == transfer.taskId || state.url != null) return;
      if (transfer.state == 'completed' && transfer.result != null) {
        state = DownloadState(
          status: DownloadStatus.completed,
          url: transfer.url,
          result: transfer.result,
          restored: true,
        );
        // The native journal already surfaced this completion, so the saved
        // pending link must not trigger a fresh analysis on the next launch.
        unawaited(_sessionStore.clearPendingUrl());
      } else if (transfer.state == 'failed') {
        state = DownloadState(
          status: DownloadStatus.failed,
          url: transfer.url,
          error: transfer.message ?? 'Le dernier téléchargement a échoué.',
          restored: true,
        );
      } else {
        return; // Nothing conclusive to restore for this transfer yet.
      }
      await _sessionStore.saveSeenTransferId(transfer.taskId);
    } on MediaEngineException {
      // The transfer journal is supplemental. Pending analysis restoration is
      // still available if an older Android engine does not expose it.
    }
  }

  Future<void> _restorePendingAnalysis() async {
    final rawUrl = await _sessionStore.readPendingUrl();
    if (_disposed || rawUrl == null || rawUrl.isEmpty || state.url != null) {
      return;
    }
    final uri = MediaUrlParser.parse(rawUrl);
    if (uri == null) {
      await _sessionStore.clearPendingUrl();
      return;
    }
    state = DownloadState(
      status: DownloadStatus.failed,
      url: uri,
      error: 'L’analyse a été interrompue. Relancez-la quand vous le souhaitez.',
      restored: true,
    );
    await _sessionStore.clearPendingUrl();
  }

  String _newTask() =>
      '${DateTime.now().microsecondsSinceEpoch}-${++_sequence}';

  void _onProgress(MediaProgress progress) {
    if (_disposed ||
        progress.taskId != _activeTask ||
        state.status == DownloadStatus.cancelling) {
      return;
    }
    state = DownloadState(
      status: switch (progress.phase) {
        MediaTransferPhase.downloading => DownloadStatus.downloading,
        MediaTransferPhase.processing => DownloadStatus.processing,
        MediaTransferPhase.saving => DownloadStatus.saving,
      },
      url: state.url,
      preview: state.preview,
      progress: progress,
    );
  }

  Future<void> resolve(
    String rawUrl, {
    bool force = false,
    bool restored = false,
  }) async {
    if (state.isBusy) return; // One native operation at a time.
    final uri = MediaUrlParser.parse(rawUrl);
    if (uri == null) {
      state = DownloadState(
        status: DownloadStatus.failed,
        error: 'Collez le lien d’une vidéo $supportedPlatformsLabel.',
      );
      return;
    }
    if (!force && state.preview != null && state.url == uri) return;
    await _sessionStore.savePendingUrl(uri.toString());
    if (_disposed) return;
    final task = _activeTask = _newTask();
    state = DownloadState(
      status: DownloadStatus.resolving,
      url: uri,
      restored: restored || state.restored,
    );
    try {
      final preview = await _engine.resolve(uri, taskId: task);
      _engineVersion = preview.engineVersion ?? _engineVersion;
      if (_disposed || _activeTask != task) return;
      state = DownloadState(
        status: DownloadStatus.ready,
        url: uri,
        preview: preview,
        engineVersion: _engineVersion,
        restored: state.restored,
      );
      unawaited(
        _analytics.logUrlAnalyzed(host: uri.host, restored: restored),
      );
    } catch (error) {
      if (!_isCancellation(error)) {
        unawaited(_analytics.logAnalyzeFailed(reason: _errorReason(error)));
      }
      _fail(task, error);
    } finally {
      await _sessionStore.clearPendingUrl();
      if (_activeTask == task) _activeTask = null;
    }
  }

  Future<void> download(MediaFormatOption format) async {
    final preview = state.preview;
    if (state.isBusy || preview == null) return;
    if (!preview.formats.any((candidate) => candidate.id == format.id)) return;
    final task = _activeTask = _newTask();
    state = DownloadState(
      status: DownloadStatus.downloading,
      url: preview.sourceUrl,
      preview: preview,
    );
    unawaited(
      _analytics.logDownloadStarted(
        host: preview.sourceUrl.host,
        format: format.id,
      ),
    );
    try {
      final result = await _engine.download(preview, format, taskId: task);
      if (_disposed || _activeTask != task) return;
      state = DownloadState(
        status: DownloadStatus.completed,
        url: preview.sourceUrl,
        preview: preview,
        result: result,
      );
      // Downloaded already: a cold restart should not re-analyze this link.
      unawaited(_sessionStore.clearPendingUrl());
      unawaited(
        _analytics.logDownloadSuccess(
          host: preview.sourceUrl.host,
          format: format.id,
          bytes: result.sizeBytes,
        ),
      );
    } catch (error) {
      if (!_isCancellation(error)) {
        unawaited(_analytics.logDownloadFailed(reason: _errorReason(error)));
      }
      _fail(task, error);
    } finally {
      if (_activeTask == task) {
        _activeTask = null;
        // The user watched this transfer reach its outcome, so the native
        // journal must not replay it on the next launch. A disposed
        // controller means they left: that outcome is still worth restoring.
        if (!_disposed) unawaited(_sessionStore.saveSeenTransferId(task));
      }
    }
  }

  Future<void> cancel() async {
    final task = _activeTask;
    if (task == null || state.status == DownloadStatus.cancelling) return;
    final previous = state;
    state = DownloadState(
      status: DownloadStatus.cancelling,
      url: previous.url,
      preview: previous.preview,
    );
    try {
      final accepted = await _engine.cancel(task);
      if (!accepted &&
          !_disposed &&
          _activeTask == task &&
          state.status == DownloadStatus.cancelling) {
        state = previous; // Publication won the race; await the method result.
      }
    } catch (_) {
      if (!_disposed &&
          _activeTask == task &&
          state.status == DownloadStatus.cancelling) {
        state = previous;
      }
    }
  }

  Future<void> updateEngine() async {
    if (state.isBusy) return;
    final url = state.url;
    final task = _activeTask = _newTask();
    state = DownloadState(status: DownloadStatus.updating, url: url);
    try {
      _engineVersion = await _engine.update(taskId: task);
      if (_disposed || _activeTask != task) return;
      _activeTask = null;
      // `resolve` deliberately refuses concurrent operations. Publish an idle
      // state before starting the fresh analysis, otherwise the retry would be
      // ignored while the controller still appears to be updating.
      state = DownloadState(
        url: url,
        engineVersion: _engineVersion,
        restored: state.restored,
      );
      unawaited(_analytics.logEngineUpdate(success: true));
      if (url != null) await resolve(url.toString(), force: true);
    } catch (error) {
      if (!_isCancellation(error)) {
        unawaited(_analytics.logEngineUpdate(success: false));
      }
      _fail(task, error);
    } finally {
      if (_activeTask == task) _activeTask = null;
    }
  }

  void consumeRestoreNavigation() {
    if (!state.restored) return;
    state = DownloadState(
      status: state.status,
      url: state.url,
      preview: state.preview,
      progress: state.progress,
      result: state.result,
      error: state.error,
      diagnostic: state.diagnostic,
      engineVersion: state.engineVersion,
    );
  }

  Future<void> openResult() async {
    final result = state.result;
    if (result != null) await _engine.open(result);
  }

  bool _isCancellation(Object error) =>
      error is MediaEngineException && error.code == 'cancelled';

  String? _errorReason(Object error) =>
      error is MediaEngineException ? error.code : null;

  void _fail(String task, Object error) {
    if (_disposed || _activeTask != task) return;
    final cancelled =
        error is MediaEngineException && error.code == 'cancelled';
    state = DownloadState(
      status: cancelled ? DownloadStatus.cancelled : DownloadStatus.failed,
      url: state.url,
      preview: state.preview,
      diagnostic: error is MediaEngineException ? error.diagnostic : null,
      engineVersion: _engineVersion,
      error: cancelled
          ? null
          : error is MediaEngineException
          ? error.message
          : 'Une erreur inattendue est survenue. Redémarrez le moteur et réessayez.',
    );
  }
}
