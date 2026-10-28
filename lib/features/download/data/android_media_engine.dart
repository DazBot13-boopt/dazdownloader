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
        diagnostic: _diagnostic(error),
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
        engineVersion: data['engineVersion'] as String?,
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
      return _file(data);
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
  Future<String> update({required String taskId}) async {
    final data = await _invoke<Map>('update', {'taskId': taskId});
    final version = data?['engineVersion'];
    if (version is! String ||
        !RegExp(r'^\d{4}\.\d{2}\.\d{2}').hasMatch(version)) {
      throw _invalidResponse;
    }
    return version;
  }

  @override
  Future<bool> alreadyDownloaded(
    MediaPreview preview,
    MediaFormatOption format,
  ) async {
    try {
      return await _invoke<bool>('alreadyDownloaded', {
            'title': preview.title,
            'extension': format.format.name,
          }) ??
          false;
    } on MediaEngineException {
      // Only a warning: an older engine or a failed check never blocks the
      // download itself.
      return false;
    }
  }

  @override
  Future<TransferSnapshot?> lastTransfer() async {
    final data = await _invoke<Map>('transferStatus', const {});
    if (data == null) return null;
    final taskId = data['taskId'];
    final state = data['state'];
    if (taskId is! String || state is! String) return null;
    final uriValue = data['uri'];
    final name = data['name'];
    final mime = data['mimeType'];
    final size = data['sizeBytes'];
    DownloadedMedia? result;
    if (uriValue is String && name is String && mime is String && size is num) {
      final uri = Uri.tryParse(uriValue);
      if (uri != null && uri.scheme == 'content' && size > 0) {
        result = DownloadedMedia(
          uri: uri,
          name: name,
          mimeType: mime,
          sizeBytes: size.toInt(),
        );
      }
    }
    return TransferSnapshot(
      taskId: taskId,
      state: state,
      url: data['url'] is String ? Uri.tryParse(data['url'] as String) : null,
      message: data['message'] as String?,
      result: result,
    );
  }

  static DownloadedMedia _file(Map data) {
    final uri = Uri.parse(data['uri'] as String);
    final size = (data['sizeBytes'] as num).toInt();
    final name = data['name'] as String;
    final mime = data['mimeType'] as String;
    if (uri.scheme != 'content' ||
        uri.authority.isEmpty ||
        size <= 0 ||
        name.isEmpty ||
        mime.isEmpty) {
      throw _invalidResponse;
    }
    final folder = data['folder'];
    return DownloadedMedia(
      uri: uri,
      name: name,
      mimeType: mime,
      sizeBytes: size,
      folder: folder is String && folder.isNotEmpty ? folder : null,
    );
  }

  static String? _diagnostic(PlatformException error) {
    final details = error.details;
    if (details is! Map) return null;
    // Only fixed, non-sensitive fields. Never include stderr, URLs or cookies.
    String safe(Object? value) {
      final text = (value?.toString() ?? 'inconnu').replaceAll(
        RegExp(r'[^a-zA-Z0-9_. -]'),
        '',
      );
      return text.substring(0, text.length.clamp(0, 80));
    }

    return 'Code : ${safe(error.code)}\n'
        'App : ${safe(details['appVersion'])} · Android API : ${safe(details['androidApi'])}\n'
        'Moteur : ${safe(details['engineVersion'])}\n'
        'Opération : ${safe(details['operation'])}';
  }

  static const _invalidResponse = MediaEngineException(
    'invalid_response',
    'Le moteur n’a pas renvoyé un média valide. Réessayez l’analyse du lien.',
  );
}
