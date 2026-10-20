import 'package:flutter/services.dart';

import 'config.dart';

/// Kilit ekranı (iOS widget / Android kalıcı bildirim) tarafıyla konuşan köprü.
class NativeBridge {
  static const _ch = MethodChannel('gunlukburc/native');

  /// Burcu yerel tarafa kaydeder; günlük güncellemeyi ve bildirimleri kurar.
  static Future<void> setSign(String sign) async {
    try {
      await _ch.invokeMethod('setSign', {'sign': sign, 'baseUrl': kContentBaseUrl});
    } catch (_) {}
  }

  /// Uygulama her açıldığında içerikleri tazeler (sessizce).
  static Future<void> sync() async {
    try {
      await _ch.invokeMethod('sync');
    } catch (_) {}
  }

  static Future<bool> requestNotificationPermission() async {
    try {
      return await _ch.invokeMethod<bool>('requestNotificationPermission') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> notificationsEnabled() async {
    try {
      return await _ch.invokeMethod<bool>('notificationsEnabled') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Android: pil optimizasyonu / bildirim ayarları ekranını açar.
  static Future<void> openNotificationSettings() async {
    try {
      await _ch.invokeMethod('openNotificationSettings');
    } catch (_) {}
  }
}
