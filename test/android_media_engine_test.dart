import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dazdownloader/features/download/data/android_media_engine.dart';
import 'package:dazdownloader/features/download/domain/media_engine.dart';
import 'package:dazdownloader/features/download/domain/media_models.dart';

import 'support/test_media_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dazdownloader/media');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late AndroidMediaEngine engine;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    engine = AndroidMediaEngine();
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  test('passes URL/task and decodes actual nonstandard resolutions', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'resolve');
      expect(call.arguments['url'], testPreview.sourceUrl.toString());
      expect(call.arguments['taskId'], 'test-task');
      return {
        'title': 'Actual title',
        'author': 'Author',
        'duration': 31.5,
        'formats': [
          {
            'id': 'mp4-2160',
            'extension': 'mp4',
            'height': 2160,
            'sizeBytes': null,
          },
        ],
      };
    });
    final preview = await engine.resolve(
      testPreview.sourceUrl,
      taskId: 'test-task',
    );
    expect(preview.title, 'Actual title');
    expect(preview.formats.single.qualityLabel, '2160p');
    expect(preview.formats.single.sizeBytes, isNull);
    expect(preview.duration.inMilliseconds, 31500);
  });

  test('does not synthesize formats for empty native metadata', () async {
    messenger.setMockMethodCallHandler(
      channel,
      (_) async => {'title': 'Title', 'author': 'Author', 'formats': []},
    );
    await expectLater(
      engine.resolve(testPreview.sourceUrl, taskId: 'a'),
      throwsA(
        isA<MediaEngineException>().having(
          (e) => e.code,
          'code',
          'invalid_response',
        ),
      ),
    );
  });

  test('returns only nonempty published content URIs', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.arguments['formatId'], testFormat.id);
      return {
        'uri': testDownload.uri.toString(),
        'name': 'video.mp4',
        'mimeType': 'video/mp4',
        'sizeBytes': 4096,
      };
    });
    final result = await engine.download(testPreview, testFormat, taskId: 'a');
    expect(result.uri.scheme, 'content');
    expect(result.sizeBytes, 4096);
  });

  for (final response in [
    {
      'uri': 'file:///cache/media.mp4',
      'name': 'video.mp4',
      'mimeType': 'video/mp4',
      'sizeBytes': 4096,
    },
    {
      'uri': 'content://media/1',
      'name': 'video.mp4',
      'mimeType': 'video/mp4',
      'sizeBytes': 0,
    },
  ]) {
    test('rejects incomplete download result $response', () async {
      messenger.setMockMethodCallHandler(channel, (_) async => response);
      await expectLater(
        engine.download(testPreview, testFormat, taskId: 'a'),
        throwsA(isA<MediaEngineException>()),
      );
    });
  }

  test('propagates native access errors as user-readable failures', () async {
    messenger.setMockMethodCallHandler(channel, (_) async {
      throw PlatformException(code: 'unavailable', message: 'Vidéo privée');
    });
    await expectLater(
      engine.resolve(testPreview.sourceUrl, taskId: 'a'),
      throwsA(
        isA<MediaEngineException>().having(
          (e) => e.message,
          'message',
          'Vidéo privée',
        ),
      ),
    );
  });

  test('unsupported platforms do not pretend to download', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    await expectLater(
      engine.resolve(testPreview.sourceUrl, taskId: 'a'),
      throwsA(
        isA<MediaEngineException>().having(
          (e) => e.code,
          'code',
          'unsupported_platform',
        ),
      ),
    );
  });

  test(
    'decodes an actual TikTok photo count instead of a video format',
    () async {
      messenger.setMockMethodCallHandler(
        channel,
        (_) async => {
          'title': 'Photos',
          'author': 'Test',
          'photoCount': 2,
          'formats': [
            {'id': 'photos-all', 'extension': 'photos'},
          ],
        },
      );
      final preview = await engine.resolve(
        testAlbum.sourceUrl,
        taskId: 'album',
      );
      expect(preview.photoCount, 2);
      expect(preview.formats.single.format, MediaFormat.photos);
    },
  );

  Map<String, Object> photoResult(int index) => {
    'uri': 'content://media/external/downloads/${100 + index}',
    'name': 'photo-$index.jpg',
    'mimeType': 'image/jpeg',
    'sizeBytes': 1024,
  };

  test('album success requires every distinct image to be published', () async {
    messenger.setMockMethodCallHandler(
      channel,
      (_) async => {
        ...photoResult(0),
        'sizeBytes': 2048,
        'files': [photoResult(0), photoResult(1)],
      },
    );
    final result = await engine.download(
      testAlbum,
      testPhotoFormat,
      taskId: 'album',
    );
    expect(result.files.length, 2);
    expect(result.sizeBytes, 2048);
  });

  for (final badFiles in [
    [photoResult(0)],
    [photoResult(0), photoResult(0)],
    [
      photoResult(0),
      {...photoResult(1), 'mimeType': 'video/mp4'},
    ],
    [
      photoResult(0),
      {...photoResult(1), 'uri': 'file:///tmp/partial.jpg'},
    ],
  ]) {
    test('rejects an incomplete or invalid album $badFiles', () async {
      messenger.setMockMethodCallHandler(
        channel,
        (_) async => {...photoResult(0), 'sizeBytes': 2048, 'files': badFiles},
      );
      await expectLater(
        engine.download(testAlbum, testPhotoFormat, taskId: 'album'),
        throwsA(isA<MediaEngineException>()),
      );
    });
  }

  test('update requires an actual executable version', () async {
    messenger.setMockMethodCallHandler(
      channel,
      (_) async => {'engineVersion': '2026.08.19'},
    );
    expect(await engine.update(taskId: 'update'), '2026.08.19');
    messenger.setMockMethodCallHandler(channel, (_) async => null);
    await expectLater(
      engine.update(taskId: 'update'),
      throwsA(isA<MediaEngineException>()),
    );
  });

  test('diagnostic exposes fixed metadata but not stderr or URLs', () async {
    messenger.setMockMethodCallHandler(channel, (_) async {
      throw PlatformException(
        code: 'instagram_limited',
        message: 'Accès limité',
        details: {
          'engineVersion': '2026.08.19',
          'androidApi': 35,
          'appVersion': '1.1.0',
          'operation': 'resolve',
          'stderr': 'secret',
          'url': 'https://private.test/?token=secret',
        },
      );
    });
    await expectLater(
      engine.resolve(testPreview.sourceUrl, taskId: 'test'),
      throwsA(
        isA<MediaEngineException>()
            .having((e) => e.diagnostic, 'version', contains('2026.08.19'))
            .having(
              (e) => e.diagnostic,
              'no secret',
              isNot(contains('secret')),
            ),
      ),
    );
  });
}
