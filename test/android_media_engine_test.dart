import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dazdownloader/features/download/data/android_media_engine.dart';
import 'package:dazdownloader/features/download/domain/media_engine.dart';

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
    expect(result.folder, isNull);
  });

  test('reports the folder the file was actually saved to', () async {
    messenger.setMockMethodCallHandler(channel, (_) async => {
      'uri': testDownload.uri.toString(),
      'name': 'video.mp4',
      'mimeType': 'video/mp4',
      'sizeBytes': 4096,
      'folder': 'Mes vidéos',
    });
    final result = await engine.download(testPreview, testFormat, taskId: 'a');
    expect(result.folder, 'Mes vidéos');
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

  test('restores only a complete persisted native transfer', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'transferStatus');
      return {
        'taskId': 'native-task',
        'state': 'completed',
        'url': testPreview.sourceUrl.toString(),
        'uri': testDownload.uri.toString(),
        'name': testDownload.name,
        'mimeType': testDownload.mimeType,
        'sizeBytes': testDownload.sizeBytes,
      };
    });
    final transfer = await engine.lastTransfer();
    expect(transfer?.taskId, 'native-task');
    expect(transfer?.state, 'completed');
    expect(transfer?.result?.uri, testDownload.uri);
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
