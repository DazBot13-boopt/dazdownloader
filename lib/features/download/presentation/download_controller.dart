import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/fake_media_engine.dart';
import '../domain/media_models.dart';
import '../domain/media_url_parser.dart';

final mediaEngineProvider = Provider<MediaEngine>((ref) => FakeMediaEngine());

final downloadControllerProvider =
    AsyncNotifierProvider<DownloadController, MediaPreview?>(
  DownloadController.new,
);

class DownloadController extends AsyncNotifier<MediaPreview?> {
  @override
  Future<MediaPreview?> build() async => null;

  Future<void> resolve(String rawUrl) async {
    final uri = MediaUrlParser.parse(rawUrl);
    if (uri == null) {
      state = AsyncError(
        const InvalidUrlException(MediaUrlError.malformed),
        StackTrace.current,
      );
      return;
    }

    state = const AsyncLoading();
    state = await AsyncValue.guard<MediaPreview>(
      () => ref.read(mediaEngineProvider).resolve(uri),
    );
  }

  void reset() {
    state = const AsyncData(null);
  }
}
