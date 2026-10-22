import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../ads.dart';
import '../config.dart';
import '../theme.dart';

/// Ekranın en altında sabit duran AdMob banner'ı (yalnızca ücretsiz kullanıcılar).
/// AdMob kurallarına uygun yerleşim: içerikten ve düğmelerden ince bir çizgi ve boşlukla ayrılır,
/// hiçbir şeyin üstünü örtmez. Reklam yüklenemezse hiç yer kaplamaz.
class BottomBannerAd extends StatefulWidget {
  const BottomBannerAd({super.key});
  @override
  State<BottomBannerAd> createState() => _BottomBannerAdState();
}

class _BottomBannerAdState extends State<BottomBannerAd> {
  BannerAd? _ad;
  bool _loaded = false;
  bool _firstDay = true;
  double? _width;

  @override
  void initState() {
    super.initState();
    AdService.instance.isFirstDay().then((v) {
      if (!mounted) return;
      _firstDay = v;
      _tryLoad();
    });
    AdService.instance.sdkReady.addListener(_tryLoad);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final w = MediaQuery.of(context).size.width;
    if (_width != null && _width != w) {
      _ad?.dispose();
      _ad = null;
      _loaded = false;
    }
    _width = w;
    _tryLoad();
  }

  Future<void> _tryLoad() async {
    if (_ad != null || _firstDay || !AdService.instance.sdkReady.value || _width == null) return;
    final size = await AdSize.getLargeAnchoredAdaptiveBannerAdSize(_width!.truncate());
    if (size == null || !mounted || _ad != null) return;
    _ad = BannerAd(
      adUnitId: Platform.isIOS ? kAdmobBannerIos : kAdmobBannerAndroid,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, err) {
          ad.dispose();
          _ad = null;
          debugPrint('Banner yüklenemedi: $err');
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    AdService.instance.sdkReady.removeListener(_tryLoad);
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (!_loaded || ad == null) return const SizedBox.shrink();
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.bg,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      padding: const EdgeInsets.only(top: 6),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: ad.size.width.toDouble(),
          height: ad.size.height.toDouble(),
          child: AdWidget(ad: ad),
        ),
      ),
    );
  }
}
