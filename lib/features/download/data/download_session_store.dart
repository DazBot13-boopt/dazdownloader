import 'package:shared_preferences/shared_preferences.dart';

class DownloadSessionStore {
  static const _pendingUrlKey = 'loady.pending_analysis_url';
  static const _seenTransferKey = 'loady.seen_transfer_task';

  Future<String?> readPendingUrl() async {
    try {
      return await SharedPreferencesAsync().getString(_pendingUrlKey);
    } catch (_) {
      return null;
    }
  }

  Future<void> savePendingUrl(String url) async {
    try {
      await SharedPreferencesAsync().setString(_pendingUrlKey, url);
    } catch (_) {
      // Persistence is best effort; the active operation remains authoritative.
    }
  }

  Future<void> clearPendingUrl() async {
    try {
      await SharedPreferencesAsync().remove(_pendingUrlKey);
    } catch (_) {
      // Same best-effort guarantee as savePendingUrl.
    }
  }

  /// Identifier of the last native transfer already shown to the user. The
  /// Android journal keeps its entry until a new transfer replaces it, so
  /// without this marker every later launch would restore the same download.
  Future<String?> readSeenTransferId() async {
    try {
      return await SharedPreferencesAsync().getString(_seenTransferKey);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveSeenTransferId(String taskId) async {
    try {
      await SharedPreferencesAsync().setString(_seenTransferKey, taskId);
    } catch (_) {
      // Best effort: at worst the finished transfer is restored once more.
    }
  }
}
