import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'astro/engine.dart';
import 'config.dart';

class Place {
  final String name, country, tzName;
  final double lat, lon;
  const Place(this.name, this.country, this.lat, this.lon, this.tzName);

  factory Place.fromJson(Map<String, dynamic> j) => Place(
      j['n'] as String, j['c'] as String, (j['la'] as num).toDouble(), (j['lo'] as num).toDouble(), j['tz'] as String);
  Map<String, dynamic> toJson() => {'n': name, 'c': country, 'la': lat, 'lo': lon, 'tz': tzName};
  String get label => country == 'Türkiye' ? name : '$name, $country';
}

class BirthData {
  final String name;
  final DateTime date; // yalnızca yıl-ay-gün
  final int? hour, minute; // bilinmiyorsa null
  final Place place;
  BirthData(this.name, this.date, this.hour, this.minute, this.place);

  bool get timeKnown => hour != null;

  Map<String, dynamic> toJson() => {
        'name': name,
        'y': date.year,
        'm': date.month,
        'd': date.day,
        'h': hour,
        'min': minute,
        'place': place.toJson(),
      };

  factory BirthData.fromJson(Map<String, dynamic> j) => BirthData(
        j['name'] as String? ?? '',
        DateTime(j['y'] as int, j['m'] as int, j['d'] as int),
        j['h'] as int?,
        j['min'] as int?,
        Place.fromJson((j['place'] as Map).cast<String, dynamic>()),
      );

  /// Doğum anının UTC karşılığı (doğum yerinin o tarihteki resmî saatine göre)
  DateTime utcAt(int h, int mi) {
    final loc = tz.getLocation(place.tzName);
    return tz.TZDateTime(loc, date.year, date.month, date.day, h, mi).toUtc();
  }
}

/// Hesaplama ve veri yükleme
class Astro {
  Astro._();
  static final Astro instance = Astro._();

  AstroEngine? _engine;
  List<Place>? _places;
  Map<String, String> natalTexts = {};

  Future<AstroEngine> engine() async {
    if (_engine != null) return _engine!;
    tzdata.initializeTimeZones();
    final b = await rootBundle.load('assets/ephem.bin');
    _engine = AstroEngine(SlowTable.parse(b));
    return _engine!;
  }

  Future<List<Place>> places() async {
    if (_places != null) return _places!;
    final s = await rootBundle.loadString('assets/places.json');
    _places = (jsonDecode(s) as List).map((e) => Place.fromJson((e as Map).cast<String, dynamic>())).toList();
    return _places!;
  }

  static String _fold(String s) => s
      .replaceAll('İ', 'i')
      .replaceAll('I', 'ı')
      .toLowerCase()
      .replaceAll('ı', 'i')
      .replaceAll('ş', 's')
      .replaceAll('ğ', 'g')
      .replaceAll('ü', 'u')
      .replaceAll('ö', 'o')
      .replaceAll('ç', 'c')
      .replaceAll('â', 'a')
      .replaceAll('î', 'i')
      .replaceAll('û', 'u');

  Future<List<Place>> searchPlaces(String q) async {
    final all = await places();
    final f = _fold(q.trim());
    if (f.isEmpty) return all.take(30).toList();
    final starts = <Place>[], contains = <Place>[];
    for (final p in all) {
      final n = _fold(p.name);
      if (n.startsWith(f)) {
        starts.add(p);
      } else if (n.contains(f) || _fold(p.country).startsWith(f)) {
        contains.add(p);
      }
      if (starts.length > 40) break;
    }
    return [...starts, ...contains].take(40).toList();
  }

  // ---------------------------------------------------------------- doğum bilgisi
  static const _kBirth = 'birth_data';

  Future<BirthData?> loadBirth() async {
    final s = (await SharedPreferences.getInstance()).getString(_kBirth);
    if (s == null) return null;
    try {
      return BirthData.fromJson(jsonDecode(s) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveBirth(BirthData b) async =>
      (await SharedPreferences.getInstance()).setString(_kBirth, jsonEncode(b.toJson()));

  // ---------------------------------------------------------------- yapay zekâ yorumları
  static const _kNatal = 'natal_texts_cache';

  Future<void> loadNatalTexts() async {
    final prefs = await SharedPreferences.getInstance();
    String? body;
    try {
      final r = await http
          .get(Uri.parse('$kContentBaseUrl/v1/natal/tr.json?t=${DateTime.now().millisecondsSinceEpoch ~/ 3600000}'))
          .timeout(const Duration(seconds: 15));
      if (r.statusCode == 200) {
        body = utf8.decode(r.bodyBytes);
        await prefs.setString(_kNatal, body);
      }
    } catch (_) {}
    body ??= prefs.getString(_kNatal);
    if (body == null) return;
    try {
      final j = jsonDecode(body) as Map<String, dynamic>;
      natalTexts = (j['texts'] as Map).cast<String, String>();
    } catch (_) {}
  }

  String? text(String key) => natalTexts[key];
}

/// Hesaplanmış kişisel harita
class PersonalChart {
  final BirthData birth;
  final ChartResult result; // saat bilinmiyorsa öğlen 12:00 kabul edilir; evler/yükselen kullanılmaz
  final int? moonAltSign; // saat bilinmiyorsa ve Ay o gün burç değiştirdiyse diğer olası burç
  PersonalChart(this.birth, this.result, this.moonAltSign);

  bool get hasHouses => birth.timeKnown;

  static Future<PersonalChart> compute(BirthData b) async {
    final eng = await Astro.instance.engine();
    if (b.timeKnown) {
      final utc = b.utcAt(b.hour!, b.minute!);
      return PersonalChart(b, eng.chart(utc, b.place.lat, b.place.lon), null);
    }
    final noon = eng.chart(b.utcAt(12, 0), b.place.lat, b.place.lon);
    final start = eng.chart(b.utcAt(0, 0), b.place.lat, b.place.lon).planets['moon']!;
    final end = eng.chart(b.utcAt(23, 59), b.place.lat, b.place.lon).planets['moon']!;
    int? alt;
    final s0 = signIndex(start), s1 = signIndex(end), sn = signIndex(noon.planets['moon']!);
    if (s0 != s1) alt = sn == s0 ? s1 : s0;
    return PersonalChart(b, noon, alt);
  }
}
