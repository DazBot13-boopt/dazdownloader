import 'dart:convert';
import 'dart:io' show HttpClient, HttpStatus, Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'device_abi.dart';

/// Page of the Loady site that offers the APKs, used when the phone's
/// architecture has no APK of its own.
const loadyDownloadPageUrl = 'https://loady-site.vercel.app/#telechargement';

const _latestRelease =
    'https://github.com/DazBot13-boopt/dazdownloader/releases/latest/download';

/// Published with every official release by build-apk.yml. A static release
/// asset, not the GitHub API: the API allows 60 requests per hour per IP, and
/// mobile carriers put many users behind the same address.
final _versionUrl = Uri.parse('$_latestRelease/version.json');

/// The latest APK for this phone, opened in the browser so the download starts
/// at once. Loady never installs it itself: that would need the
/// REQUEST_INSTALL_PACKAGES permission, which Google Play restricts.
Uri updateDownloadUri() => apkDownloadUri(currentApkAbi());

/// APK of the latest release for [abi], or the site's download section when
/// no APK is published for it.
Uri apkDownloadUri(String? abi) => abi == null
    ? Uri.parse(loadyDownloadPageUrl)
    : Uri.parse('$_latestRelease/app-$abi-release.apk');

enum UpdateCheckOutcome { available, upToDate, failed, unsupported }

class UpdateCheckResult {
  const UpdateCheckResult(this.outcome, [this.version]);

  final UpdateCheckOutcome outcome;

  /// The newer version name, set only when [outcome] is available.
  final String? version;
}

abstract interface class UpdateChecker {
  /// Compares the latest published release with the installed app.
  ///
  /// Without [force], the network is asked at most once a day and a version
  /// the user dismissed is not offered again. [force] is the explicit check
  /// from the settings screen.
  Future<UpdateCheckResult> check({bool force = false});

  Future<void> dismiss(String version);
}

/// True when [candidate] is a strictly higher `major.minor.patch` than
/// [installed]. A leading `v` and a `+build` suffix are ignored; anything
/// unparsable is never treated as newer.
bool isNewerVersion(String candidate, String installed) {
  final a = _parts(candidate);
  final b = _parts(installed);
  if (a == null || b == null) return false;
  for (var i = 0; i < 3; i++) {
    if (a[i] != b[i]) return a[i] > b[i];
  }
  return false;
}

List<int>? _parts(String value) {
  final name = value.trim().replaceFirst(RegExp(r'^v'), '').split('+').first;
  final match = RegExp(r'^(\d+)\.(\d+)\.(\d+)$').firstMatch(name);
  if (match == null) return null;
  return [for (var i = 1; i <= 3; i++) int.parse(match.group(i)!)];
}

class GitHubUpdateChecker implements UpdateChecker {
  static const _lastCheckKey = 'loady.update.last_check';
  static const _latestKey = 'loady.update.latest';
  static const _dismissedKey = 'loady.update.dismissed';
  static const _interval = Duration(days: 1);

  @override
  Future<UpdateCheckResult> check({bool force = false}) async {
    // APKs exist only for Android; the web preview has nothing to update.
    if (kIsWeb || !Platform.isAndroid) {
      return const UpdateCheckResult(UpdateCheckOutcome.unsupported);
    }
    try {
      final preferences = SharedPreferencesAsync();
      String? latest;
      if (!force) {
        final lastCheck = await preferences.getInt(_lastCheckKey);
        final recent = lastCheck != null &&
            DateTime.now().difference(
                  DateTime.fromMillisecondsSinceEpoch(lastCheck),
                ) <
                _interval;
        if (recent) latest = await preferences.getString(_latestKey);
      }
      if (latest == null) {
        latest = await _fetchLatestVersion();
        if (latest == null) {
          return const UpdateCheckResult(UpdateCheckOutcome.failed);
        }
        await preferences.setString(_latestKey, latest);
        await preferences.setInt(
          _lastCheckKey,
          DateTime.now().millisecondsSinceEpoch,
        );
      }
      final installed = (await PackageInfo.fromPlatform()).version;
      if (!isNewerVersion(latest, installed)) {
        return const UpdateCheckResult(UpdateCheckOutcome.upToDate);
      }
      if (!force && await preferences.getString(_dismissedKey) == latest) {
        return const UpdateCheckResult(UpdateCheckOutcome.upToDate);
      }
      return UpdateCheckResult(UpdateCheckOutcome.available, latest);
    } catch (_) {
      // Offline, blocked or malformed: an update check must never disturb
      // the app.
      return const UpdateCheckResult(UpdateCheckOutcome.failed);
    }
  }

  @override
  Future<void> dismiss(String version) async {
    try {
      await SharedPreferencesAsync().setString(_dismissedKey, version);
    } catch (_) {
      // Best effort: at worst the same version is offered again tomorrow.
    }
  }

  Future<String?> _fetchLatestVersion() async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    try {
      final request = await client.getUrl(_versionUrl);
      final response = await request.close().timeout(
        const Duration(seconds: 15),
      );
      if (response.statusCode != HttpStatus.ok) return null;
      final body = await response
          .transform(utf8.decoder)
          .join()
          .timeout(const Duration(seconds: 15));
      final data = jsonDecode(body);
      if (data is! Map) return null;
      final version = data['version'];
      return version is String && _parts(version) != null ? version : null;
    } finally {
      client.close(force: true);
    }
  }
}

final updateCheckerProvider = Provider<UpdateChecker>(
  (ref) => GitHubUpdateChecker(),
);
