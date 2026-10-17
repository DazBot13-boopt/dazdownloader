import 'package:flutter_test/flutter_test.dart';

import 'package:dazdownloader/features/download/domain/media_models.dart';
import 'package:dazdownloader/features/download/domain/media_url_parser.dart';

void main() {
  test('normalizes public network URLs to HTTPS and removes fragments', () {
    expect(
      MediaUrlParser.parse('http://youtu.be/abc#fragment').toString(),
      'https://youtu.be/abc',
    );
    expect(MediaUrlParser.parse('https://youtube.com:9000/watch?v=a'), isNull);
    expect(
      MediaUrlParser.parse('https://user:pass@youtube.com/watch?v=a'),
      isNull,
    );
    expect(
      MediaUrlParser.parse('https://youtube.com.evil.example/watch?v=a'),
      isNull,
    );
  });

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
    expect(
      MediaUrlParser.platformFor(
        Uri.parse('https://www.pinterest.com/pin/123/'),
      ),
      MediaPlatform.pinterest,
    );
    expect(
      MediaUrlParser.platformFor(Uri.parse('https://pin.it/abc')),
      MediaPlatform.pinterest,
    );
    expect(
      MediaUrlParser.platformFor(
        Uri.parse('https://www.threads.net/@user/post/abc'),
      ),
      MediaPlatform.threads,
    );
    expect(
      MediaUrlParser.platformFor(Uri.parse('https://threads.com/@user/post/x')),
      MediaPlatform.threads,
    );
  });

  test('rejects unsupported and malformed URLs', () {
    expect(MediaUrlParser.parse('https://example.com/video'), isNull);
    expect(MediaUrlParser.parse('not a url'), isNull);
    expect(MediaUrlParser.parse('file:///tmp/video.mp4'), isNull);
  });
}
