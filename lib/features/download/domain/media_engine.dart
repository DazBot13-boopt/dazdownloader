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
  Future<String> update({required String taskId});
}

class MediaEngineException implements Exception {
  const MediaEngineException(this.code, this.message, {this.diagnostic});
  final String code;
  final String message;
  final String? diagnostic;

  @override
  String toString() => message;
}
