import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'config.dart';

/// Premium üyelik (aylık 299 ₺, yıllık 2.499 ₺).
///
/// Google Play / App Store yalnızca SÜRESİ DOLMAMIŞ abonelikleri geri yükler. Bu yüzden uygulama her
/// açılışta mağazaya sorar: üyelik aktifse özellikler açılır, iptal edilip süresi bittiyse kapanır,
/// yenilenince yeniden açılır. İnternet yoksa son doğrulanan durum en fazla 3 gün geçerli sayılır.
class PremiumService extends ChangeNotifier {
  PremiumService._();
  static final PremiumService instance = PremiumService._();

  static const productIds = {kMonthlyProductId, kYearlyProductId};
  static const _kVerifiedAt = 'premium_verified_at';
  static const _kDebugOverride = 'premium_debug_override';
  static const _offlineGrace = Duration(days: 3);

  // Mağaza incelemesi için erişim kodu: yalnızca Google Play / App Store inceleme ekibine verilir.
  // Kodun kendisi depoda yok, yalnızca özeti (SHA-256) var. Girilen kod Premium'u 60 gün açar.
  static const _kReviewUntil = 'premium_review_until';
  static const _reviewSalt = 'burc-atlasi-inceleme';
  static const _reviewHash = '5c9d92ac4ca35223c1f7f308c6b3d2a0cca0303a0d8da8e9cbd453d136530101';
  DateTime? _reviewUntil;

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _sub;

  bool _active = false;
  bool _storeAvailable = false;
  bool _busy = false;
  bool? _debugOverride;
  final Map<String, ProductDetails> products = {};
  String? activePlan;
  String? lastError;

  bool get _reviewActive => _reviewUntil != null && DateTime.now().isBefore(_reviewUntil!);
  bool get isPremium => _debugOverride ?? (_active || _reviewActive);

  /// İnceleme erişim kodunu dener; doğruysa Premium 60 gün açılır.
  Future<bool> redeemCode(String code) async {
    final c = code.trim().toUpperCase();
    if (sha256.convert(utf8.encode('$_reviewSalt$c')).toString() != _reviewHash) return false;
    _reviewUntil = DateTime.now().add(const Duration(days: 60));
    (await SharedPreferences.getInstance()).setInt(_kReviewUntil, _reviewUntil!.millisecondsSinceEpoch);
    notifyListeners();
    return true;
  }
  bool get storeAvailable => _storeAvailable;
  bool get busy => _busy;

  String price(String id) =>
      products[id]?.price ?? (id == kYearlyProductId ? kYearlyFallbackPrice : kMonthlyFallbackPrice);

  /// Geriye dönük uyumluluk (aylık fiyat)
  String get priceText => price(kMonthlyProductId);

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    if (kDebugMode && prefs.containsKey(_kDebugOverride)) {
      _debugOverride = prefs.getBool(_kDebugOverride);
    }
    final ru = prefs.getInt(_kReviewUntil);
    if (ru != null) _reviewUntil = DateTime.fromMillisecondsSinceEpoch(ru);
    final verified = prefs.getInt(_kVerifiedAt);
    if (verified != null &&
        DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(verified)) < _offlineGrace) {
      _active = true; // geçici: mağaza yanıtına kadar
    }
    notifyListeners();

    try {
      _storeAvailable = await _iap.isAvailable();
    } catch (_) {
      _storeAvailable = false;
    }
    if (!_storeAvailable) return;

    _sub ??= _iap.purchaseStream.listen(_onPurchases, onError: (Object e) {
      lastError = 'Satın alma tamamlanamadı. Lütfen biraz sonra tekrar dene.';
      _setBusy(false);
    });
    await _loadProducts();
    await refresh();
  }

  Future<void> _loadProducts() async {
    try {
      final res = await _iap.queryProductDetails(productIds);
      for (final p in res.productDetails) {
        products[p.id] = p;
      }
      notifyListeners();
    } catch (_) {}
  }

  /// Mağazadan güncel abonelik durumunu sorar.
  Future<void> refresh() async {
    if (!_storeAvailable) return;
    String? found;
    final c = Completer<void>();
    late StreamSubscription<List<PurchaseDetails>> probe;
    probe = _iap.purchaseStream.listen((list) {
      for (final p in list) {
        if (productIds.contains(p.productID) &&
            (p.status == PurchaseStatus.restored || p.status == PurchaseStatus.purchased)) {
          found = p.productID;
          if (!c.isCompleted) c.complete();
        }
      }
    });
    try {
      await _iap.restorePurchases();
      await c.future.timeout(const Duration(seconds: 6));
    } catch (_) {
      // zaman aşımı = aktif abonelik yok
    }
    await probe.cancel();
    await _setActive(found);
  }

  Future<void> _setActive(String? plan) async {
    _active = plan != null;
    activePlan = plan;
    final prefs = await SharedPreferences.getInstance();
    if (_active) {
      await prefs.setInt(_kVerifiedAt, DateTime.now().millisecondsSinceEpoch);
    } else {
      await prefs.remove(_kVerifiedAt);
    }
    notifyListeners();
  }

  Timer? _busyGuard;

  /// Satın alma düğmesinin "yükleniyor" durumu. Mağaza hiç yanıt vermese bile düğme
  /// en geç 45 saniye sonra yeniden basılabilir hale gelir (asla sonsuza kadar dönmez).
  void _setBusy(bool v) {
    _busy = v;
    _busyGuard?.cancel();
    if (v) {
      _busyGuard = Timer(const Duration(seconds: 45), () {
        if (_busy) {
          _busy = false;
          notifyListeners();
        }
      });
    }
    notifyListeners();
  }

  Future<void> _onPurchases(List<PurchaseDetails> list) async {
    for (final p in list) {
      // Google Play hata ya da iptal bildirdiğinde ürün kimliği boş gelebilir: yine de düğmeyi serbest bırak.
      if (!productIds.contains(p.productID)) {
        if (p.status == PurchaseStatus.error) {
          lastError = _friendlyError(p.error);
          _setBusy(false);
        } else if (p.status == PurchaseStatus.canceled) {
          _setBusy(false);
        }
        if (p.pendingCompletePurchase) {
          try {
            await _iap.completePurchase(p);
          } catch (_) {}
        }
        continue;
      }
      switch (p.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _setActive(p.productID);
          lastError = null;
          _setBusy(false);
        case PurchaseStatus.error:
          lastError = _friendlyError(p.error);
          _setBusy(false);
        case PurchaseStatus.canceled:
          _setBusy(false);
        case PurchaseStatus.pending:
          lastError = 'Ödemen onay bekliyor. Onaylanınca Premium kendiliğinden açılır.';
          _setBusy(false);
      }
      if (p.pendingCompletePurchase) {
        try {
          await _iap.completePurchase(p);
        } catch (_) {}
      }
    }
    notifyListeners();
  }

  String _friendlyError(IAPError? e) {
    final m = (e?.message ?? '').toLowerCase();
    if (m.contains('already') || m.contains('owned')) {
      return 'Bu üyelik zaten hesabında görünüyor. "Satın alımları geri yükle"ye dokun.';
    }
    if (m.contains('unavailable') || m.contains('network') || m.contains('service')) {
      return 'Google Play\'e şu an ulaşılamıyor. İnternet bağlantını kontrol edip tekrar dene.';
    }
    return 'Satın alma tamamlanamadı. Lütfen biraz sonra tekrar dene.';
  }

  Future<bool> buy(String productId) async {
    lastError = null;
    if (!_storeAvailable) {
      lastError = 'Mağaza şu anda kullanılamıyor. İnternet bağlantını kontrol et.';
      notifyListeners();
      return false;
    }
    if (!products.containsKey(productId)) await _loadProducts();
    final prod = products[productId];
    if (prod == null) {
      lastError = 'Üyelik paketi mağazada bulunamadı. (Uygulama Google Play üzerinden yüklenmiş olmalı.)';
      notifyListeners();
      return false;
    }
    _setBusy(true);
    try {
      final started = await _iap.buyNonConsumable(purchaseParam: PurchaseParam(productDetails: prod));
      if (!started) {
        lastError = 'Satın alma başlatılamadı. Lütfen tekrar dene.';
        _setBusy(false);
      }
      return started;
    } catch (e) {
      lastError = 'Satın alma başlatılamadı. Lütfen tekrar dene.';
      _setBusy(false);
      return false;
    }
  }

  /// Yalnızca geliştirme sürümünde: mağaza olmadan özellikleri denemek için
  Future<void> setDebugOverride(bool? v) async {
    if (!kDebugMode) return;
    _debugOverride = v;
    final prefs = await SharedPreferences.getInstance();
    if (v == null) {
      await prefs.remove(_kDebugOverride);
    } else {
      await prefs.setBool(_kDebugOverride, v);
    }
    notifyListeners();
  }
}
