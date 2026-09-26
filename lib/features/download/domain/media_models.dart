enum MediaPlatform {
  youtube,
  tiktok,
  instagram,
  snapchat,
  x,
  facebook,
}

extension MediaPlatformDetails on MediaPlatform {
  String get label => switch (this) {
        MediaPlatform.youtube => 'YouTube',
        MediaPlatform.tiktok => 'TikTok',
        MediaPlatform.instagram => 'Instagram',
        MediaPlatform.snapchat => 'Snapchat',
        MediaPlatform.x => 'X',
        MediaPlatform.facebook => 'Facebook',
      };
}

enum MediaFormat {
  mp4,
  webm,
  mp3,
}

extension MediaFormatDetails on MediaFormat {
  String get label => switch (this) {
        MediaFormat.mp4 => 'MP4',
        MediaFormat.webm => 'WebM',
        MediaFormat.mp3 => 'MP3',
      };
}

enum MediaQuality {
  p1080,
  p720,
  p480,
  audio,
}

extension MediaQualityDetails on MediaQuality {
  String get label => switch (this) {
        MediaQuality.p1080 => '1080p',
        MediaQuality.p720 => '720p',
        MediaQuality.p480 => '480p',
        MediaQuality.audio => 'Audio',
      };
}

class MediaFormatOption {
  const MediaFormatOption({
    required this.id,
    required this.quality,
    required this.format,
    this.sizeBytes,
  });

  final String id;
  final MediaQuality quality;
  final MediaFormat format;
  final int? sizeBytes;

  String get sizeLabel {
    final bytes = sizeBytes;
    if (bytes == null) {
      return '';
    }
    final megabytes = bytes / (1024 * 1024);
    return '${megabytes.toStringAsFixed(megabytes >= 10 ? 0 : 1)} Mo';
  }
}

class MediaPreview {
  const MediaPreview({
    required this.title,
    required this.author,
    required this.platform,
    required this.duration,
    required this.formats,
    this.thumbnailUrl,
  });

  final String title;
  final String author;
  final MediaPlatform platform;
  final Duration duration;
  final List<MediaFormatOption> formats;
  final String? thumbnailUrl;
}
