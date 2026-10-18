import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

/// Static AdMob configuration for Loady.
///
/// IDs are AdMob **public** identifiers — they are embedded in every
/// published APK and are safe to keep in source. They are not secrets.
class AdsConfig {
  const AdsConfig._();

  // Production Loady ad units.
  static const _prodBannerUnitId = 'ca-app-pub-4928947364999295/5662168943';
  static const _prodInterstitialUnitId =
      'ca-app-pub-4928947364999295/4157515583';

  // Google test ad units — safe to show anywhere during development
  // without risking policy violations against real inventory.
  static const _testBannerUnitId = 'ca-app-pub-3940256099942544/6300978111';
  static const _testInterstitialUnitId =
      'ca-app-pub-3940256099942544/1033173712';

  /// AdMob banner unit used by the home page. Returns the Google test id
  /// in debug builds so staging devices never serve real inventory.
  static String get bannerUnitId {
    if (kDebugMode) return _testBannerUnitId;
    if (kIsWeb || !Platform.isAndroid) return _testBannerUnitId;
    return _prodBannerUnitId;
  }

  /// AdMob interstitial unit shown after a successful download.
  static String get interstitialUnitId {
    if (kDebugMode) return _testInterstitialUnitId;
    if (kIsWeb || !Platform.isAndroid) return _testInterstitialUnitId;
    return _prodInterstitialUnitId;
  }

  /// Remote Config key: when true, the banner is rendered on supported
  /// platforms. Default is **false** so a fresh install never shows an
  /// ad before you flip the switch from the Firebase Console.
  static const remoteConfigEnabledKey = 'ads_enabled';
}
