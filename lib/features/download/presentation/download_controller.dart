import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/android_media_engine.dart';
import '../domain/media_engine.dart';
import '../domain/media_models.dart';
import '../domain/media_url_parser.dart';

final mediaEngineProvider = Provider<MediaEngine>(
  (ref) => AndroidMediaEngine(),
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
  });

  final DownloadStatus status;
  final Uri? url;
  final MediaPreview? preview;
  final MediaProgress? progress;
  final DownloadedMedia? result;
  final String? error;
  final String? diagnostic;
  final String? engineVersion;

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

  @override
  DownloadState build() {
    _engine = ref.read(mediaEngineProvider);
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
    return const DownloadState();
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

  Future<void> resolve(String rawUrl, {bool force = false}) async {
    if (state.isBusy) return; // One native operation at a time.
    final uri = MediaUrlParser.parse(rawUrl);
    if (uri == null) {
      state = const DownloadState(
        status: DownloadStatus.failed,
        error:
            'Collez le lien d’une vidéo YouTube, TikTok, Instagram, '
            'Snapchat, X ou Facebook.',
      );
      return;
    }
    if (!force && state.preview != null && state.url == uri) return;
    final task = _activeTask = _newTask();
    state = DownloadState(status: DownloadStatus.resolving, url: uri);
    try {
      final preview = await _engine.resolve(uri, taskId: task);
      _engineVersion = preview.engineVersion ?? _engineVersion;
      if (_disposed || _activeTask != task) return;
      state = DownloadState(
        status: DownloadStatus.ready,
        url: uri,
        preview: preview,
        engineVersion: _engineVersion,
      );
    } catch (error) {
      _fail(task, error);
    } finally {
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
    try {
      final result = await _engine.download(preview, format, taskId: task);
      if (_disposed || _activeTask != task) return;
      state = DownloadState(
        status: DownloadStatus.completed,
        url: preview.sourceUrl,
        preview: preview,
        result: result,
      );
    } catch (error) {
      _fail(task, error);
    } finally {
      if (_activeTask == task) _activeTask = null;
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
      state = DownloadState(url: url, engineVersion: _engineVersion);
      if (url != null) await resolve(url.toString(), force: true);
    } catch (error) {
      _fail(task, error);
    } finally {
      if (_activeTask == task) _activeTask = null;
    }
  }

  Future<void> openResult([DownloadedMedia? file]) async {
    final result = file ?? state.result;
    if (result != null) await _engine.open(result);
  }

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
          : 'Une erreur inattendue est survenue. Réessayez.',
    );
  }
}
