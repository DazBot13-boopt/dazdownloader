enum MediaPlatform { youtube, tiktok, instagram, snapchat, x, facebook }

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

enum MediaFormat { mp4, webm, mp3 }

extension MediaFormatDetails on MediaFormat {
  String get label => switch (this) {
    MediaFormat.mp4 => 'MP4',
    MediaFormat.webm => 'WebM',
    MediaFormat.mp3 => 'MP3',
  };
}

enum MediaQuality { p1080, p720, p480, audio }

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
    required this.format,
    this.height,
    this.sizeBytes,
  });

  final String id;
  final MediaFormat format;
  final int? height;
  final int? sizeBytes;

  String get qualityLabel => format == MediaFormat.mp3
      ? 'Audio'
      : height == null
      ? 'Original'
      : '${height}p';

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
    required this.sourceUrl,
    required this.title,
    required this.author,
    required this.platform,
    required this.duration,
    required this.formats,
    this.thumbnailUrl,
  });

  final Uri sourceUrl;
  final String title;
  final String author;
  final MediaPlatform platform;
  final Duration duration;
  final List<MediaFormatOption> formats;
  final String? thumbnailUrl;
}

enum MediaTransferPhase { downloading, processing, saving }

class MediaProgress {
  const MediaProgress({
    required this.taskId,
    required this.phase,
    this.percent,
    this.etaSeconds,
  });

  final String taskId;
  final MediaTransferPhase phase;
  final double? percent;
  final int? etaSeconds;
}

class DownloadedMedia {
  const DownloadedMedia({
    required this.uri,
    required this.name,
    required this.mimeType,
    required this.sizeBytes,
  });

  final Uri uri;
  final String name;
  final String mimeType;
  final int sizeBytes;
}
