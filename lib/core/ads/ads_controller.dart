import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ads_config.dart';

/// Rolls up the two conditions that decide whether ads are rendered:
/// the platform supports them AND the Remote Config kill-switch is on.
/// Default is `false` so first launch never shows an ad.
class AdsEnabledNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  // ignore: use_setters_to_change_properties
  void set(bool value) => state = value;
}

final adsEnabledProvider = NotifierProvider<AdsEnabledNotifier, bool>(
  AdsEnabledNotifier.new,
);

/// Hook called at app start. Initializes the Mobile Ads SDK, pulls the
/// Remote Config flag, and reflects it into [adsEnabledProvider] so any
/// widget watching that provider rebuilds when ads flip on/off.
Future<void> initAds(ProviderContainer container) async {
  if (kIsWeb || !Platform.isAndroid) return;
  try {
    await MobileAds.instance.initialize();
    final rc = FirebaseRemoteConfig.instance;
    await rc.setDefaults(const {AdsConfig.remoteConfigEnabledKey: false});
    await rc.setConfigSettings(
      RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        // 1h on-device cache: fetches don't hammer the service, and
        // flipping the switch in the Firebase Console reaches users
        // within one app session.
        minimumFetchInterval: const Duration(hours: 1),
      ),
    );
    unawaited(_refreshFlag(rc, container));
  } catch (error, stack) {
    debugPrint('AdMob init failed, ads disabled: $error\n$stack');
  }
}

Future<void> _refreshFlag(
  FirebaseRemoteConfig rc,
  ProviderContainer container,
) async {
  try {
    await rc.fetchAndActivate();
    final enabled = rc.getBool(AdsConfig.remoteConfigEnabledKey);
    container.read(adsEnabledProvider.notifier).set(enabled);
  } catch (error) {
    debugPrint('Remote Config fetch failed: $error');
  }
}
