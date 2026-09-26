import '../domain/media_models.dart';
import '../domain/media_url_parser.dart';

abstract interface class MediaEngine {
  Future<MediaPreview> resolve(Uri url);
}

class FakeMediaEngine implements MediaEngine {
  @override
  Future<MediaPreview> resolve(Uri url) async {
    await Future<void>.delayed(const Duration(milliseconds: 650));

    final platform = MediaUrlParser.platformFor(url);
    if (platform == null) {
      throw const InvalidUrlException(MediaUrlError.unsupported);
    }

    return MediaPreview(
      title: 'Contenu ${platform.label} détecté',
      author: 'Aperçu local',
      platform: platform,
      duration: const Duration(minutes: 2, seconds: 14),
      formats: const [
        MediaFormatOption(
          id: 'mp4-1080',
          quality: MediaQuality.p1080,
          format: MediaFormat.mp4,
          sizeBytes: 48 * 1024 * 1024,
        ),
        MediaFormatOption(
          id: 'mp4-720',
          quality: MediaQuality.p720,
          format: MediaFormat.mp4,
          sizeBytes: 28 * 1024 * 1024,
        ),
        MediaFormatOption(
          id: 'webm-720',
          quality: MediaQuality.p720,
          format: MediaFormat.webm,
          sizeBytes: 24 * 1024 * 1024,
        ),
        MediaFormatOption(
          id: 'mp3-audio',
          quality: MediaQuality.audio,
          format: MediaFormat.mp3,
          sizeBytes: 6 * 1024 * 1024,
        ),
      ],
    );
  }
}
