enum MediaPlatform {
  youtube,
  tiktok,
  instagram,
  snapchat,
  x,
  facebook,
  pinterest,
  threads,
}

extension MediaPlatformDetails on MediaPlatform {
  String get label => switch (this) {
    MediaPlatform.youtube => 'YouTube',
    MediaPlatform.tiktok => 'TikTok',
    MediaPlatform.instagram => 'Instagram',
    MediaPlatform.snapchat => 'Snapchat',
    MediaPlatform.x => 'X',
    MediaPlatform.facebook => 'Facebook',
    MediaPlatform.pinterest => 'Pinterest',
    MediaPlatform.threads => 'Threads',
  };

  /// Android packages of the platform's apps, full edition before Lite. The
  /// home screen opens whichever is installed and asks when there are two.
  /// Keep in sync with the `<queries>` of AndroidManifest.xml.
  List<String> get appPackages => switch (this) {
    MediaPlatform.youtube => const ['com.google.android.youtube'],
    MediaPlatform.tiktok => const [
      'com.zhiliaoapp.musically',
      'com.ss.android.ugc.trill',
      'com.zhiliaoapp.musically.go',
      'com.ss.android.ugc.tiktok.lite',
    ],
    MediaPlatform.instagram => const [
      'com.instagram.android',
      'com.instagram.lite',
    ],
    MediaPlatform.snapchat => const ['com.snapchat.android'],
    MediaPlatform.x => const ['com.twitter.android'],
    MediaPlatform.facebook => const [
      'com.facebook.katana',
      'com.facebook.lite',
    ],
    MediaPlatform.pinterest => const ['com.pinterest'],
    MediaPlatform.threads => const ['com.instagram.barcelona'],
  };

  /// Home page of the platform, opened in a browser when none of its apps is
  /// installed.
  Uri get homeUrl => Uri.parse(switch (this) {
    MediaPlatform.youtube => 'https://www.youtube.com',
    MediaPlatform.tiktok => 'https://www.tiktok.com',
    MediaPlatform.instagram => 'https://www.instagram.com',
    MediaPlatform.snapchat => 'https://www.snapchat.com',
    MediaPlatform.x => 'https://x.com',
    MediaPlatform.facebook => 'https://www.facebook.com',
    MediaPlatform.pinterest => 'https://www.pinterest.com',
    MediaPlatform.threads => 'https://www.threads.com',
  });
}

/// "YouTube, TikTok, … ou Threads": built from the enum so every message
/// stays in sync when a platform is added.
String get supportedPlatformsLabel {
  final labels = [for (final platform in MediaPlatform.values) platform.label];
  return '${labels.sublist(0, labels.length - 1).join(', ')} ou ${labels.last}';
}

enum MediaFormat { mp4, mp3 }

extension MediaFormatDetails on MediaFormat {
  String get label => switch (this) {
    MediaFormat.mp4 => 'MP4',
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
    this.engineVersion,
  });

  final Uri sourceUrl;
  final String title;
  final String author;
  final MediaPlatform platform;
  final Duration duration;
  final List<MediaFormatOption> formats;
  final String? thumbnailUrl;
  final String? engineVersion;
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
    this.folder,
  });

  final Uri uri;
  final String name;
  final String mimeType;
  final int sizeBytes;

  /// Where the file was saved, as shown to the user. Unknown for a transfer
  /// restored from the native journal.
  final String? folder;
}
