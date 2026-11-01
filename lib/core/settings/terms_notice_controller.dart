import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Whether the copyright notice shown at first launch has been accepted.
///
/// Defaults to accepted so widgets built without the startup override (tests,
/// web preview) are not covered by the notice; `main` overrides it with the
/// stored value.
final termsNoticeProvider = NotifierProvider<TermsNoticeController, bool>(
  () => TermsNoticeController(true),
);

class TermsNoticeController extends Notifier<bool> {
  TermsNoticeController(this.initiallyAccepted);

  final bool initiallyAccepted;

  static const _acceptedVersionKey = 'loady.terms.accepted_version';

  /// Raise this when the notice text changes in a way everyone must see
  /// again: installations that accepted an older version get it once more.
  static const currentVersion = 1;

  static Future<bool> loadAccepted() async {
    try {
      final accepted = await SharedPreferencesAsync().getInt(
        _acceptedVersionKey,
      );
      return accepted != null && accepted >= currentVersion;
    } catch (_) {
      return false;
    }
  }

  @override
  bool build() => initiallyAccepted;

  Future<void> accept() async {
    state = true;
    try {
      await SharedPreferencesAsync().setInt(
        _acceptedVersionKey,
        currentVersion,
      );
    } catch (_) {
      // The notice stays dismissed for this session; it returns next launch.
    }
  }
}
