import 'package:shared_preferences/shared_preferences.dart';

class DownloadSessionStore {
  static const _pendingUrlKey = 'loady.pending_analysis_url';

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
}
