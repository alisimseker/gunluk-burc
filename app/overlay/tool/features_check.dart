// Takvim olaylarını ve yıllık harita anını yazdırır (Python/Swiss Ephemeris ile karşılaştırmak için).
// Çalıştırma: dart run tool/features_check.dart > tool/features_out.json
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../lib/astro/engine.dart';
import '../lib/astro/features.dart';

void main() {
  final bytes = File('assets/ephem.bin').readAsBytesSync();
  final e = AstroEngine(SlowTable.parse(ByteData.view(Uint8List.fromList(bytes).buffer)));
  final from = DateTime.utc(2026, 10, 22);
  final ev = skyEvents(e, from, 450)
      .map((x) => {'t': x.utc.toIso8601String(), 'type': x.type, 'p': x.planet, 's': x.sign})
      .toList();
  final natal = e.chart(DateTime.utc(1995, 6, 15, 11, 30), 41.0138, 28.9497);
  final sr = solarReturnUtc(e, natal.planets['sun']!, DateTime(1995, 6, 15), 2026);
  final p2 = e.chart(DateTime.utc(1993, 10, 2, 7, 15), 39.9334, 32.8597);
  final syn = synastry(natal, p2);
  final tr = transitsFor(e, natal, DateTime.utc(2026, 10, 22, 9), withAngles: true)
      .take(8)
      .map((h) => '${h.key} orb=${h.orb.toStringAsFixed(2)}')
      .toList();
  stdout.writeln(jsonEncode({
    'events': ev,
    'solar_return': sr.toIso8601String(),
    'synastry': {'scores': syn.scores, 'total': syn.total, 'hits': syn.hits.take(8).map((h) => '${h.key} ${h.orb.toStringAsFixed(1)}').toList()},
    'transits': tr,
  }));
}
