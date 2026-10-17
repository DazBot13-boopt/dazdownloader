import 'media_models.dart';

enum MediaUrlError { empty, malformed, unsupported }

class InvalidUrlException implements Exception {
  const InvalidUrlException(this.reason);

  final MediaUrlError reason;

  @override
  String toString() => switch (reason) {
    MediaUrlError.empty => 'Collez une URL pour continuer.',
    MediaUrlError.malformed => 'Cette URL n’est pas valide.',
    MediaUrlError.unsupported =>
      'Cette plateforme n’est pas encore prise en charge.',
  };
}

class MediaUrlParser {
  static Uri? parse(String raw) {
    final value = raw.trim();
    if (value.isEmpty) {
      return null;
    }

    final candidate = value.contains('://') ? value : 'https://$value';
    final uri = Uri.tryParse(candidate);
    if (uri == null ||
        !{'http', 'https'}.contains(uri.scheme) ||
        uri.host.isEmpty ||
        (uri.hasPort && uri.port != 80 && uri.port != 443) ||
        uri.userInfo.isNotEmpty) {
      return null;
    }

    if (platformFor(uri) == null) {
      return null;
    }

    return uri.replace(scheme: 'https', port: 443).removeFragment();
  }

  static MediaPlatform? platformFor(Uri uri) {
    final host = uri.host.toLowerCase().replaceFirst(RegExp(r'\.$'), '');

    if (_matches(host, 'youtube.com') || host == 'youtu.be') {
      return MediaPlatform.youtube;
    }
    if (_matches(host, 'tiktok.com') || host == 'www.tiktokv.com') {
      return MediaPlatform.tiktok;
    }
    if (_matches(host, 'instagram.com')) {
      return MediaPlatform.instagram;
    }
    if (_matches(host, 'snapchat.com')) {
      return MediaPlatform.snapchat;
    }
    if (_matches(host, 'x.com') || _matches(host, 'twitter.com')) {
      return MediaPlatform.x;
    }
    if (_matches(host, 'facebook.com') ||
        _matches(host, 'fb.com') ||
        host == 'fb.watch') {
      return MediaPlatform.facebook;
    }
    if (_matches(host, 'pinterest.com') ||
        _matches(host, 'pinterest.fr') ||
        host == 'pin.it') {
      return MediaPlatform.pinterest;
    }
    if (_matches(host, 'threads.net') || _matches(host, 'threads.com')) {
      return MediaPlatform.threads;
    }
    return null;
  }

  static bool _matches(String host, String domain) {
    return host == domain || host.endsWith('.$domain');
  }
}
