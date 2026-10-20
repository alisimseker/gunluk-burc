import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'config.dart';

class DayReading {
  final String date;
  final String focus;
  final String short;
  final String text;
  final String motivation;
  final String basis;
  final List<String> skyEvents;
  final List<String> skySummary;
  final String moonPhase;

  DayReading.fromJson(Map<String, dynamic> j)
      : date = j['date'] as String? ?? '',
        focus = j['focus'] as String? ?? '',
        short = j['short'] as String? ?? '',
        text = j['text'] as String? ?? '',
        motivation = j['motivation'] as String? ?? '',
        basis = j['basis'] as String? ?? '',
        skyEvents = List<String>.from(j['sky_events'] as List? ?? const []),
        skySummary = List<String>.from(j['sky_summary'] as List? ?? const []),
        moonPhase = j['moon_phase'] as String? ?? '';
}

class Repository {
  static const _kSign = 'sign';
  static String _cacheKey(String sign) => 'cache_$sign';

  Future<String?> getSign() async =>
      (await SharedPreferences.getInstance()).getString(_kSign);

  Future<void> setSign(String sign) async =>
      (await SharedPreferences.getInstance()).setString(_kSign, sign);

  /// Önce internetten dener; olmazsa telefondaki son kopyayı kullanır.
  Future<({Map<String, DayReading> days, bool offline})> load(String sign) async {
    final prefs = await SharedPreferences.getInstance();
    String? body;
    var offline = false;
    try {
      final res = await http
          .get(Uri.parse('$kContentBaseUrl/v1/$sign.json?t=${DateTime.now().millisecondsSinceEpoch ~/ 600000}'))
          .timeout(const Duration(seconds: 12));
      if (res.statusCode == 200) {
        body = utf8.decode(res.bodyBytes);
        await prefs.setString(_cacheKey(sign), body);
      }
    } catch (_) {
      // internet yok: önbellek kullanılacak
    }
    if (body == null) {
      offline = true;
      body = prefs.getString(_cacheKey(sign));
    }
    final days = <String, DayReading>{};
    if (body != null) {
      try {
        final j = jsonDecode(body) as Map<String, dynamic>;
        for (final d in (j['days'] as List? ?? const [])) {
          final r = DayReading.fromJson(d as Map<String, dynamic>);
          days[r.date] = r;
        }
      } catch (_) {}
    }
    return (days: days, offline: offline);
  }
}
