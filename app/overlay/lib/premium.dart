import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'config.dart';

/// Aylık üyelik durumu.
///
/// Google Play / App Store yalnızca SÜRESİ DOLMAMIŞ abonelikleri geri yükler. Bu yüzden uygulama her
/// açılışta mağazaya sorar: üyelik aktifse özellikler açılır, iptal edilip süresi bittiyse kapanır,
/// yenilenince yeniden açılır. İnternet yoksa son doğrulanan durum en fazla 3 gün geçerli sayılır.
class PremiumService extends ChangeNotifier {
  PremiumService._();
  static final PremiumService instance = PremiumService._();

  static const _kVerifiedAt = 'premium_verified_at';
  static const _kDebugOverride = 'premium_debug_override';
  static const _offlineGrace = Duration(days: 3);

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _sub;

  bool _active = false;
  bool _storeAvailable = false;
  bool _busy = false;
  bool? _debugOverride;
  ProductDetails? product;
  String? lastError;

  bool get isPremium => _debugOverride ?? _active;
  bool get storeAvailable => _storeAvailable;
  bool get busy => _busy;
  bool? get debugOverride => _debugOverride;

  /// Mağazadaki fiyat (yoksa varsayılan)
  String get priceText => product?.price ?? kPremiumFallbackPrice;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    if (kDebugMode && prefs.containsKey(_kDebugOverride)) {
      _debugOverride = prefs.getBool(_kDebugOverride);
    }
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
      lastError = '$e';
      notifyListeners();
    });
    try {
      final res = await _iap.queryProductDetails({kPremiumProductId});
      if (res.productDetails.isNotEmpty) product = res.productDetails.first;
    } catch (_) {}
    await refresh();
  }

  /// Mağazadan güncel abonelik durumunu sorar.
  Future<void> refresh() async {
    if (!_storeAvailable) return;
    var found = false;
    final c = Completer<void>();
    late StreamSubscription<List<PurchaseDetails>> probe;
    probe = _iap.purchaseStream.listen((list) {
      if (list.any((p) =>
          p.productID == kPremiumProductId &&
          (p.status == PurchaseStatus.restored || p.status == PurchaseStatus.purchased))) {
        found = true;
        if (!c.isCompleted) c.complete();
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

  Future<void> _setActive(bool v) async {
    _active = v;
    final prefs = await SharedPreferences.getInstance();
    if (v) {
      await prefs.setInt(_kVerifiedAt, DateTime.now().millisecondsSinceEpoch);
    } else {
      await prefs.remove(_kVerifiedAt);
    }
    notifyListeners();
  }

  Future<void> _onPurchases(List<PurchaseDetails> list) async {
    for (final p in list) {
      if (p.productID != kPremiumProductId) continue;
      switch (p.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _setActive(true);
          _busy = false;
        case PurchaseStatus.error:
          lastError = p.error?.message ?? 'Satın alma tamamlanamadı.';
          _busy = false;
        case PurchaseStatus.canceled:
          _busy = false;
        case PurchaseStatus.pending:
          _busy = true;
      }
      if (p.pendingCompletePurchase) {
        try {
          await _iap.completePurchase(p);
        } catch (_) {}
      }
    }
    notifyListeners();
  }

  Future<bool> buy() async {
    lastError = null;
    if (!_storeAvailable) {
      lastError = 'Mağaza şu anda kullanılamıyor. İnternet bağlantını kontrol et.';
      notifyListeners();
      return false;
    }
    if (product == null) {
      try {
        final res = await _iap.queryProductDetails({kPremiumProductId});
        if (res.productDetails.isNotEmpty) product = res.productDetails.first;
      } catch (_) {}
    }
    if (product == null) {
      lastError = 'Üyelik paketi mağazada bulunamadı. (Uygulama Google Play üzerinden yüklenmiş olmalı.)';
      notifyListeners();
      return false;
    }
    _busy = true;
    notifyListeners();
    try {
      return await _iap.buyNonConsumable(purchaseParam: PurchaseParam(productDetails: product!));
    } catch (e) {
      _busy = false;
      lastError = '$e';
      notifyListeners();
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
