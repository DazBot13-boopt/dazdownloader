import 'package:flutter_test/flutter_test.dart';

import 'package:dazdownloader/features/download/domain/media_models.dart';
import 'package:dazdownloader/features/download/domain/media_url_parser.dart';

void main() {
  test('detects supported platform URLs', () {
    expect(
      MediaUrlParser.parse('https://www.youtube.com/watch?v=dQw4w9WgXcQ'),
      isNotNull,
    );
    expect(
      MediaUrlParser.platformFor(
        Uri.parse('https://www.tiktok.com/@user/video/123'),
      ),
      MediaPlatform.tiktok,
    );
    expect(
      MediaUrlParser.platformFor(Uri.parse('https://x.com/user/status/123')),
      MediaPlatform.x,
    );
  });

  test('rejects unsupported and malformed URLs', () {
    expect(MediaUrlParser.parse('https://example.com/video'), isNull);
    expect(MediaUrlParser.parse('not a url'), isNull);
    expect(MediaUrlParser.parse('file:///tmp/video.mp4'), isNull);
  });
}
