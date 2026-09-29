import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../domain/media_engine.dart';
import '../domain/media_models.dart';
import '../domain/media_url_parser.dart';

/// Native code owns extraction, FFmpeg and publication. Signed stream URLs
/// never need to cross the platform channel.
class AndroidMediaEngine implements MediaEngine {
  static const _methods = MethodChannel('dazdownloader/media');
  static const _events = EventChannel('dazdownloader/media/progress');

  bool get _supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  late final Stream<MediaProgress> _progress = _supported
      ? _events.receiveBroadcastStream().map((event) {
          final data = Map<String, dynamic>.from(event as Map);
          final value = (data['percent'] as num?)?.toDouble();
          return MediaProgress(
            taskId: data['taskId'] as String,
            phase: MediaTransferPhase.values.byName(data['phase'] as String),
            percent: value != null && value.isFinite
                ? value.clamp(0, 100).toDouble()
                : null,
            etaSeconds: (data['etaSeconds'] as num?)?.toInt(),
          );
        })
      : const Stream.empty();

  @override
  Stream<MediaProgress> get progress => _progress;

  Future<T?> _invoke<T>(String method, Map<String, Object?> arguments) async {
    if (!_supported) {
      throw const MediaEngineException(
        'unsupported_platform',
        'Le téléchargement natif est disponible dans l’application Android, '
            'pas dans la version web.',
      );
    }
    try {
      return await _methods.invokeMethod<T>(method, arguments);
    } on PlatformException catch (error) {
      throw MediaEngineException(
        error.code,
        error.message ?? 'Le moteur de téléchargement a rencontré une erreur.',
      );
    } on MissingPluginException {
      throw const MediaEngineException(
        'missing_engine',
        'Le moteur Android est absent. Réinstallez la nouvelle version de l’APK.',
      );
    }
  }

  @override
  Future<MediaPreview> resolve(Uri url, {required String taskId}) async {
    final result = await _invoke<Map>('resolve', {
      'url': url.toString(),
      'taskId': taskId,
    });
    if (result == null) throw _invalidResponse;
    try {
      final data = Map<String, dynamic>.from(result);
      final formats = (data['formats'] as List)
          .map((item) {
            final format = Map<String, dynamic>.from(item as Map);
            return MediaFormatOption(
              id: format['id'] as String,
              format: MediaFormat.values.byName(format['extension'] as String),
              height: (format['height'] as num?)?.toInt(),
              sizeBytes: (format['sizeBytes'] as num?)?.toInt(),
            );
          })
          .toList(growable: false);
      if (formats.isEmpty || formats.any((format) => format.id.isEmpty)) {
        throw _invalidResponse;
      }
      final seconds = (data['duration'] as num?)?.toDouble();
      return MediaPreview(
        sourceUrl: url,
        title: data['title'] as String,
        author: data['author'] as String,
        platform: MediaUrlParser.platformFor(url)!,
        duration: Duration(
          milliseconds: seconds != null && seconds.isFinite && seconds > 0
              ? (seconds * 1000).round()
              : 0,
        ),
        formats: formats,
        thumbnailUrl: data['thumbnail'] as String?,
      );
    } on MediaEngineException {
      rethrow;
    } catch (_) {
      throw _invalidResponse;
    }
  }

  @override
  Future<DownloadedMedia> download(
    MediaPreview preview,
    MediaFormatOption format, {
    required String taskId,
  }) async {
    final data = await _invoke<Map>('download', {
      'url': preview.sourceUrl.toString(),
      'formatId': format.id,
      'taskId': taskId,
    });
    try {
      if (data == null) throw _invalidResponse;
      final uri = Uri.parse(data['uri'] as String);
      final size = (data['sizeBytes'] as num).toInt();
      if (uri.scheme != 'content' || size <= 0) throw _invalidResponse;
      return DownloadedMedia(
        uri: uri,
        name: data['name'] as String,
        mimeType: data['mimeType'] as String,
        sizeBytes: size,
      );
    } catch (_) {
      throw _invalidResponse;
    }
  }

  @override
  Future<bool> cancel(String taskId) async =>
      await _invoke<bool>('cancel', {'taskId': taskId}) ?? false;

  @override
  Future<void> open(DownloadedMedia media) => _invoke<void>('open', {
    'uri': media.uri.toString(),
    'mimeType': media.mimeType,
  });

  @override
  Future<void> update({required String taskId}) =>
      _invoke<void>('update', {'taskId': taskId});

  static const _invalidResponse = MediaEngineException(
    'invalid_response',
    'Le moteur n’a pas renvoyé un média valide. Réessayez l’analyse du lien.',
  );
}
