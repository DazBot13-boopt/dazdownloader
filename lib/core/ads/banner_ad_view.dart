import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ads_config.dart';
import 'ads_controller.dart';

/// Renders a 320x50 AdMob banner when the Remote Config kill-switch is
/// on. Returns an empty box on every other platform / state so callers
/// can embed it unconditionally.
class BannerAdView extends ConsumerStatefulWidget {
  const BannerAdView({super.key});

  @override
  ConsumerState<BannerAdView> createState() => _BannerAdViewState();
}

class _BannerAdViewState extends ConsumerState<BannerAdView> {
  BannerAd? _ad;
  bool _loaded = false;

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  void _loadIfNeeded() {
    if (_ad != null || kIsWeb || !Platform.isAndroid) return;
    final banner = BannerAd(
      adUnitId: AdsConfig.bannerUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (!mounted) return;
          setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          debugPrint('Banner failed to load: $error');
        },
      ),
    );
    banner.load();
    _ad = banner;
  }

  @override
  Widget build(BuildContext context) {
    final enabled = ref.watch(adsEnabledProvider);
    if (!enabled) return const SizedBox.shrink();
    _loadIfNeeded();
    final ad = _ad;
    if (ad == null || !_loaded) return const SizedBox.shrink();
    return SafeArea(
      top: false,
      child: Container(
        alignment: Alignment.center,
        width: ad.size.width.toDouble(),
        height: ad.size.height.toDouble(),
        child: AdWidget(ad: ad),
      ),
    );
  }
}
