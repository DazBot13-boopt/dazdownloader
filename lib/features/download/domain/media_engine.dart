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
  Future<TransferSnapshot?> lastTransfer();

  /// Whether this video was already saved in this format, so the user can be
  /// warned before downloading it again.
  Future<bool> alreadyDownloaded(MediaPreview preview, MediaFormatOption format);
}

class TransferSnapshot {
  const TransferSnapshot({
    required this.taskId,
    required this.state,
    this.url,
    this.message,
    this.result,
  });

  final String taskId;
  final String state;
  final Uri? url;
  final String? message;
  final DownloadedMedia? result;
}

class MediaEngineException implements Exception {
  const MediaEngineException(this.code, this.message, {this.diagnostic});
  final String code;
  final String message;
  final String? diagnostic;

  @override
  String toString() => message;
}
