import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

abstract class AnalyticsService {
  Future<void> logAppOpen();
  Future<void> logUrlAnalyzed({required String host, bool restored = false});
  Future<void> logAnalyzeFailed({String? reason});
  Future<void> logDownloadStarted({required String host, String? format});
  Future<void> logDownloadSuccess({
    required String host,
    String? format,
    int? bytes,
  });
  Future<void> logDownloadFailed({String? reason});
  Future<void> logEngineUpdate({required bool success});
}

class NoopAnalyticsService implements AnalyticsService {
  const NoopAnalyticsService();

  @override
  Future<void> logAppOpen() async {}

  @override
  Future<void> logUrlAnalyzed({required String host, bool restored = false}) async {}

  @override
  Future<void> logAnalyzeFailed({String? reason}) async {}

  @override
  Future<void> logDownloadStarted({required String host, String? format}) async {}

  @override
  Future<void> logDownloadSuccess({
    required String host,
    String? format,
    int? bytes,
  }) async {}

  @override
  Future<void> logDownloadFailed({String? reason}) async {}

  @override
  Future<void> logEngineUpdate({required bool success}) async {}
}

class FirebaseAnalyticsService implements AnalyticsService {
  FirebaseAnalyticsService(this._analytics);

  final FirebaseAnalytics _analytics;

  // Firebase caps event names at 40 chars and params at 100 chars; both are
  // enforced here so a bad caller never silently drops the event server-side.
  String _truncate(String value, [int max = 100]) =>
      value.length <= max ? value : value.substring(0, max);

  @override
  Future<void> logAppOpen() => _analytics.logAppOpen();

  @override
  Future<void> logUrlAnalyzed({required String host, bool restored = false}) =>
      _analytics.logEvent(
        name: 'url_analyzed',
        parameters: {
          'host': _truncate(host),
          'restored': restored ? 1 : 0,
        },
      );

  @override
  Future<void> logAnalyzeFailed({String? reason}) => _analytics.logEvent(
    name: 'url_analyze_failed',
    parameters: reason == null ? null : {'reason': _truncate(reason)},
  );

  @override
  Future<void> logDownloadStarted({required String host, String? format}) =>
      _analytics.logEvent(
        name: 'download_started',
        parameters: {
          'host': _truncate(host),
          if (format != null) 'format': _truncate(format, 40),
        },
      );

  @override
  Future<void> logDownloadSuccess({
    required String host,
    String? format,
    int? bytes,
  }) => _analytics.logEvent(
    name: 'download_success',
    parameters: {
      'host': _truncate(host),
      // ignore: use_null_aware_elements
      if (format != null) 'format': _truncate(format, 40),
      // ignore: use_null_aware_elements
      if (bytes != null) 'bytes': bytes,
    },
  );

  @override
  Future<void> logDownloadFailed({String? reason}) => _analytics.logEvent(
    name: 'download_failed',
    parameters: reason == null ? null : {'reason': _truncate(reason)},
  );

  @override
  Future<void> logEngineUpdate({required bool success}) => _analytics.logEvent(
    name: success ? 'engine_update_success' : 'engine_update_failed',
  );
}

final analyticsServiceProvider = Provider<AnalyticsService>(
  (ref) => const NoopAnalyticsService(),
);
