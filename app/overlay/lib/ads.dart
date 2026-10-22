import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math' as m;

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'config.dart';
import 'premium.dart';
import 'screens/ad_screen.dart';
import 'zodiac.dart';

/// Markanın doğrudan kampanyası (docs/v1/ads.json içinden)
class Campaign {
  final String id, brand, title, cta, url;
  final String? subtitle, image, video, logo;
  final DateTime start, end;
  final int skipAfter, weight;
  final List<String>? signs; // yalnızca bu burçlara göster (boşsa herkese)

  Campaign.fromJson(Map<String, dynamic> j)
      : id = j['id'] as String,
        brand = j['brand'] as String? ?? '',
        title = j['title'] as String? ?? '',
        subtitle = j['subtitle'] as String?,
        cta = j['cta'] as String? ?? 'İncele',
        url = j['url'] as String? ?? '',
        image = j['image'] as String?,
        video = j['video'] as String?,
        logo = j['logo'] as String?,
        start = DateTime.parse(j['start'] as String),
        end = DateTime.parse(j['end'] as String),
        skipAfter = (j['skip_after'] as num?)?.toInt() ?? 5,
        weight = (j['weight'] as num?)?.toInt() ?? 1,
        signs = (j['signs'] as List?)?.cast<String>();

  bool activeAt(DateTime t) => !t.isBefore(start) && t.isBefore(end);
}

/// Reklam kuralları:
///  - Premium üyeler hiç reklam görmez.
///  - Ücretsiz kullanıcı günde en fazla [kAdsPerDay] tam ekran reklam görür; uygulamayı ilk kurduğu gün hiç görmez.
///  - Reklam, kullanıcı ana sayfada yorumu okuyacak kadar kaldıktan sonra ([kAdDelay]) gösterilir, açılışta değil.
///  - Aktif bir marka kampanyası varsa o gösterilir; yoksa AdMob reklamı.
///  - Ana sayfanın en altında, içerikten ve düğmelerden ayrı, sabit bir AdMob banner'ı (ilk gün yok).
class AdService {
  AdService._();
  static final AdService instance = AdService._();

  static const _kFirstOpen = 'ads_first_open';
  static const _kDay = 'ads_day';
  static const _kCount = 'ads_count';

  bool _sdkReady = false;
  bool _consentDone = false;

  /// AdMob hazır olduğunda true olur (alt banner bunu dinler)
  final ValueNotifier<bool> sdkReady = ValueNotifier(false);

  /// Uygulamanın kurulduğu gün mü? (ilk gün hiç reklam yok)
  Future<bool> isFirstDay() async =>
      (await SharedPreferences.getInstance()).getString(_kFirstOpen) == isoDate(DateTime.now());
  InterstitialAd? _interstitial;
  bool _loading = false;
  List<Campaign> _campaigns = [];
  DateTime? _campaignsAt;
  bool _showing = false;

  String get _unitId => Platform.isIOS ? kAdmobInterstitialIos : kAdmobInterstitialAndroid;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey(_kFirstOpen)) {
      await prefs.setString(_kFirstOpen, isoDate(DateTime.now()));
    }
    if (PremiumService.instance.isPremium) return;
    _gatherConsent();
    unawaited(_loadCampaigns());
  }

  void _gatherConsent() {
    try {
      ConsentInformation.instance.requestConsentInfoUpdate(ConsentRequestParameters(), () {
        ConsentForm.loadAndShowConsentFormIfRequired((FormError? e) async {
          _consentDone = true;
          await _initSdk();
        });
      }, (FormError e) async {
        _consentDone = true;
        await _initSdk();
      });
    } catch (_) {
      _consentDone = true;
    }
  }

  Future<void> _initSdk() async {
    if (_sdkReady) return;
    try {
      if (!await ConsentInformation.instance.canRequestAds()) return;
      await MobileAds.instance.initialize();
      _sdkReady = true;
      sdkReady.value = true;
      _preload();
    } catch (_) {}
  }

  void _preload() {
    if (!_sdkReady || _interstitial != null || _loading || PremiumService.instance.isPremium) return;
    _loading = true;
    InterstitialAd.load(
      adUnitId: _unitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _loading = false;
          _interstitial = ad;
        },
        onAdFailedToLoad: (err) {
          _loading = false;
          debugPrint('AdMob yüklenemedi: $err');
        },
      ),
    );
  }

  Future<void> _loadCampaigns() async {
    if (_campaignsAt != null && DateTime.now().difference(_campaignsAt!) < const Duration(hours: 1)) return;
    try {
      final r = await http
          .get(Uri.parse('$kContentBaseUrl/v1/ads.json?t=${DateTime.now().millisecondsSinceEpoch ~/ 600000}'))
          .timeout(const Duration(seconds: 10));
      if (r.statusCode == 200) {
        final j = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
        _campaigns = [
          for (final c in (j['campaigns'] as List? ?? const []))
            try_(() => Campaign.fromJson((c as Map).cast<String, dynamic>()))
        ].whereType<Campaign>().toList();
        _campaignsAt = DateTime.now();
      }
    } catch (_) {}
  }

  static T? try_<T>(T Function() f) {
    try {
      return f();
    } catch (_) {
      return null;
    }
  }

  Future<bool> _allowedToday() async {
    if (PremiumService.instance.isPremium) return false;
    final prefs = await SharedPreferences.getInstance();
    final today = isoDate(DateTime.now());
    if (prefs.getString(_kFirstOpen) == today) return false; // ilk gün reklam yok
    final count = prefs.getString(_kDay) == today ? (prefs.getInt(_kCount) ?? 0) : 0;
    return count < kAdsPerDay;
  }

  Future<void> _markShown() async {
    final prefs = await SharedPreferences.getInstance();
    final today = isoDate(DateTime.now());
    final count = prefs.getString(_kDay) == today ? (prefs.getInt(_kCount) ?? 0) : 0;
    await prefs.setString(_kDay, today);
    await prefs.setInt(_kCount, count + 1);
  }

  /// Uygun ise bir reklam gösterir. [sign]: kullanıcının burcu (hedefli kampanyalar için).
  Future<void> maybeShow(BuildContext context, {String? sign}) async {
    if (_showing || !await _allowedToday()) return;
    await _loadCampaigns();
    final now = DateTime.now();
    final active = _campaigns
        .where((c) => c.activeAt(now) && (c.signs == null || c.signs!.isEmpty || c.signs!.contains(sign)))
        .toList();
    if (!context.mounted) return;
    if (active.isNotEmpty) {
      final total = active.fold<int>(0, (s, c) => s + m.max(1, c.weight));
      var pick = m.Random().nextInt(total);
      var chosen = active.first;
      for (final c in active) {
        pick -= m.max(1, c.weight);
        if (pick < 0) {
          chosen = c;
          break;
        }
      }
      _showing = true;
      await _markShown();
      if (!context.mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(fullscreenDialog: true, builder: (_) => AdScreen(campaign: chosen)));
      _showing = false;
      return;
    }
    if (!_consentDone) return;
    final ad = _interstitial;
    if (ad == null) {
      _preload();
      return;
    }
    _showing = true;
    _interstitial = null;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (a) {
        a.dispose();
        _showing = false;
        _preload();
      },
      onAdFailedToShowFullScreenContent: (a, e) {
        a.dispose();
        _showing = false;
        _preload();
      },
    );
    await _markShown();
    await ad.show();
  }

  /// Avrupa'daki kullanıcılar için gizlilik seçenekleri (ayarlarda gösterilir)
  Future<bool> privacyOptionsRequired() async {
    try {
      return await ConsentInformation.instance.getPrivacyOptionsRequirementStatus() ==
          PrivacyOptionsRequirementStatus.required;
    } catch (_) {
      return false;
    }
  }

  void showPrivacyOptions() {
    try {
      ConsentForm.showPrivacyOptionsForm((_) {});
    } catch (_) {}
  }
}
