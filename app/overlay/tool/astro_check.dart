// Doğum haritası motorunu Swiss Ephemeris referans değerleriyle karşılaştırır.
// Çalıştırma: dart run tool/astro_check.dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../lib/astro/engine.dart';

double diff(double a, double b) => (((a - b + 540) % 360) - 180).abs();

void main() {
  tzdata.initializeTimeZones();
  final bytes = File('assets/ephem.bin').readAsBytesSync();
  final engine = AstroEngine(SlowTable.parse(ByteData.view(Uint8List.fromList(bytes).buffer)));
  final cases = jsonDecode(File('tool/astro_cases.json').readAsStringSync()) as List;
  var worst = <String, double>{};
  var signErr = 0, utcErr = 0;
  for (final c in cases) {
    final l = (c['local'] as List).cast<int>();
    final loc = tz.getLocation(c['tz'] as String);
    final utc = tz.TZDateTime(loc, l[0], l[1], l[2], l[3], l[4]).toUtc();
    final u = (c['utc'] as List).cast<int>();
    if (utc.year != u[0] || utc.month != u[1] || utc.day != u[2] || utc.hour != u[3] || utc.minute != u[4]) {
      utcErr++;
      stdout.writeln('UTC farkı: ${c['place']} ${c['local']} → $utc (beklenen ${c['utc']})');
    }
    final r = engine.chart(DateTime.utc(u[0], u[1], u[2], u[3], u[4]), (c['lat'] as num).toDouble(),
        (c['lon'] as num).toDouble());
    final ref = (c['planets'] as Map).cast<String, num>();
    void chk(String k, double mine, double exp) {
      final e = diff(mine, exp);
      worst[k] = (worst[k] ?? 0) > e ? worst[k]! : e;
      if (signIndex(mine) != signIndex(exp)) signErr++;
    }

    ref.forEach((k, v) => chk(k, r.planets[k]!, v.toDouble()));
    chk('asc', r.asc, (c['asc'] as num).toDouble());
    chk('mc', r.mc, (c['mc'] as num).toDouble());
    final cs = (c['cusps'] as List).cast<num>();
    for (var i = 0; i < 12; i++) {
      chk('cusps', r.cusps[i], cs[i].toDouble());
    }
  }
  stdout.writeln('${cases.length} harita kontrol edildi. En büyük farklar (yay dakikası):');
  worst.forEach((k, v) => stdout.writeln('  ${k.padRight(8)} ${(v * 60).toStringAsFixed(2)}'));
  stdout.writeln('Burç uyuşmazlığı: $signErr, UTC dönüşüm hatası: $utcErr');
  stdout.writeln(signErr == 0 && utcErr == 0 && worst.values.every((v) => v < 0.05) ? 'SONUC: GECTI' : 'SONUC: KALDI');
}
