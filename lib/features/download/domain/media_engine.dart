import 'media_models.dart';

abstract interface class MediaEngine {
  Stream<MediaProgress> get progress;
  Future<MediaPreview> resolve(Uri url, {required String taskId});
  Future<DownloadedMedia> download(
    MediaPreview preview,
    MediaFormatOption format, {
    required String taskId,
  });
  Future<bool> cancel(String taskId);
  Future<void> open(DownloadedMedia media);
  Future<void> update({required String taskId});
}

class MediaEngineException implements Exception {
  const MediaEngineException(this.code, this.message);
  final String code;
  final String message;

  @override
  String toString() => message;
}
