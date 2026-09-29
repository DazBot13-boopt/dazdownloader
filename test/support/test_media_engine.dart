import 'dart:async';

import 'package:dazdownloader/features/download/domain/media_engine.dart';
import 'package:dazdownloader/features/download/domain/media_models.dart';

const testFormat = MediaFormatOption(
  id: 'mp4-720',
  format: MediaFormat.mp4,
  height: 720,
);
final testPreview = MediaPreview(
  sourceUrl: Uri.parse('https://www.youtube.com/watch?v=test'),
  title: 'Vidéo de test',
  author: 'Auteur de test',
  platform: MediaPlatform.youtube,
  duration: const Duration(seconds: 30),
  formats: const [testFormat],
);
final testDownload = DownloadedMedia(
  uri: Uri.parse('content://media/external/downloads/42'),
  name: 'video.mp4',
  mimeType: 'video/mp4',
  sizeBytes: 4096,
);

/// Explicitly a test double. Production always uses the native Android bridge.
class TestMediaEngine implements MediaEngine {
  final events = StreamController<MediaProgress>.broadcast(sync: true);
  Completer<MediaPreview>? resolveCompleter;
  Completer<DownloadedMedia>? downloadCompleter;
  int resolveCalls = 0;
  int downloadCalls = 0;
  int updateCalls = 0;
  String? taskId;
  bool opened = false;
  bool acceptCancel = true;
  MediaEngineException? resolutionError;

  @override
  Stream<MediaProgress> get progress => events.stream;

  @override
  Future<MediaPreview> resolve(Uri url, {required String taskId}) async {
    resolveCalls++;
    this.taskId = taskId;
    if (resolutionError case final error?) throw error;
    return resolveCompleter?.future ?? testPreview;
  }

  @override
  Future<DownloadedMedia> download(
    MediaPreview preview,
    MediaFormatOption format, {
    required String taskId,
  }) {
    downloadCalls++;
    this.taskId = taskId;
    downloadCompleter = Completer<DownloadedMedia>();
    return downloadCompleter!.future;
  }

  @override
  Future<bool> cancel(String taskId) async {
    if (!acceptCancel) return false;
    const error = MediaEngineException('cancelled', 'Annulé');
    if (downloadCompleter case final pending? when !pending.isCompleted) {
      pending.completeError(error);
    }
    if (resolveCompleter case final pending? when !pending.isCompleted) {
      pending.completeError(error);
    }
    return true;
  }

  @override
  Future<void> open(DownloadedMedia media) async {
    opened = true;
  }

  @override
  Future<void> update({required String taskId}) async {
    updateCalls++;
  }

  void emit({
    double percent = 50,
    String? id,
    MediaTransferPhase phase = MediaTransferPhase.downloading,
  }) {
    events.add(
      MediaProgress(taskId: id ?? taskId!, phase: phase, percent: percent),
    );
  }
}
