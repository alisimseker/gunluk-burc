// Premium özellikleri için hesaplamalar: günün kişisel etkileri (transit), uyum (sinastri),
// gökyüzü takvimi olayları ve yıllık (güneş dönüşü) harita.
import 'dart:math' as m;

import 'engine.dart';

const aspectKeys = ['conj', 'sextile', 'square', 'trine', 'opp'];
const aspectAngles = {'conj': 0.0, 'sextile': 60.0, 'square': 90.0, 'trine': 120.0, 'opp': 180.0};
const aspectNamesTr = {
  'conj': 'kavuşum',
  'sextile': 'altmışlık',
  'square': 'kare',
  'trine': 'üçgen',
  'opp': 'karşıt'
};

double _sep(double a, double b) {
  final d = norm360(a - b);
  return d > 180 ? 360 - d : d;
}

/// En yakın açı ve orbu (orb sınırı içinde değilse null)
({String key, double orb})? matchAspect(double a, double b, double maxOrb) {
  final s = _sep(a, b);
  for (final k in aspectKeys) {
    final o = (s - aspectAngles[k]!).abs();
    if (o <= maxOrb) return (key: k, orb: o);
  }
  return null;
}

double jdFromUtc(DateTime u) =>
    julianDay(u.year, u.month, u.day, u.hour + u.minute / 60.0 + u.second / 3600.0);

double ttFromUt(double jdUT, int year) => jdUT + deltaT(year.toDouble()) / 86400.0;

DateTime utcFromJd(double jd) {
  final ms = ((jd - 2440587.5) * 86400000).round();
  return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
}

// ----------------------------------------------------------------------------- günün etkileri
class TransitHit {
  final String transit, aspect, natal;
  final double orb;
  final int transitSign;
  final double transitLon;
  final double weight;
  TransitHit(this.transit, this.aspect, this.natal, this.orb, this.transitSign, this.transitLon, this.weight);
  String get key => 'tr:$transit:$aspect:$natal';

  /// Uygulamada gösterilecek etiket
  String get tag {
    if (aspect == 'square' || aspect == 'opp') return 'Dikkat';
    if (transit == 'venus' || natal == 'venus' || (transit == 'mars' && natal == 'moon')) return 'Aşk';
    if (natal == 'mc' || transit == 'saturn' && aspect != 'conj') return 'İş';
    if (aspect == 'trine' || aspect == 'sextile') return 'Fırsat';
    return 'Etki';
  }
}

const _transitOrb = {
  'moon': 4.0, 'sun': 2.5, 'mercury': 2.0, 'venus': 2.0, 'mars': 2.0,
  'jupiter': 1.5, 'saturn': 1.5, 'uranus': 1.2, 'neptune': 1.2, 'pluto': 1.2,
};
const _transitWeight = {
  'moon': 1.0, 'sun': 2.2, 'mercury': 1.8, 'venus': 2.0, 'mars': 2.2,
  'jupiter': 3.0, 'saturn': 3.2, 'uranus': 2.8, 'neptune': 2.6, 'pluto': 2.8,
};
const _natalWeight = {
  'sun': 1.3, 'moon': 1.3, 'asc': 1.2, 'mc': 1.0, 'mercury': 0.9, 'venus': 1.0, 'mars': 0.9, 'jupiter': 0.7, 'saturn': 0.7,
};

/// Verilen anda (öğlen önerilir) gökyüzünün doğum haritasına yaptığı açılar, önem sırasıyla.
List<TransitHit> transitsFor(AstroEngine eng, ChartResult natal, DateTime whenUtc, {required bool withAngles}) {
  final jdTT = ttFromUt(jdFromUtc(whenUtc), whenUtc.year);
  final hits = <TransitHit>[];
  final natalPoints = <String, double>{
    for (final k in ['sun', 'moon', 'mercury', 'venus', 'mars', 'jupiter', 'saturn']) k: natal.planets[k]!,
    if (withAngles) 'asc': natal.asc,
    if (withAngles) 'mc': natal.mc,
  };
  for (final t in _transitOrb.keys) {
    final tl = eng.planetLon(t, jdTT);
    for (final e in natalPoints.entries) {
      final a = matchAspect(tl, e.value, _transitOrb[t]!);
      if (a == null) continue;
      final w = _transitWeight[t]! * _natalWeight[e.key]! * (1.2 - a.orb / _transitOrb[t]!);
      hits.add(TransitHit(t, a.key, e.key, a.orb, signIndex(tl), tl, w));
    }
  }
  hits.sort((a, b) => b.weight.compareTo(a.weight));
  return hits;
}

// ----------------------------------------------------------------------------- uyum
class SynastryHit {
  final String a, aspect, b; // a: birinci kişinin gezegeni, b: ikincinin
  final double orb;
  SynastryHit(this.a, this.aspect, this.b, this.orb);

  /// Kütüphane anahtarı (gezegen çifti sıralı)
  String get key {
    const order = ['sun', 'moon', 'mercury', 'venus', 'mars', 'jupiter', 'saturn'];
    final x = order.indexOf(a) <= order.indexOf(b) ? a : b;
    final y = x == a ? b : a;
    return 'sy:$x:$aspect:$y';
  }

  bool get harmonious => aspect == 'trine' || aspect == 'sextile' || (aspect == 'conj' && !(a == 'saturn' || b == 'saturn'));
}

class SynastryResult {
  final List<SynastryHit> hits;
  final Map<String, int> scores; // Aşk, İletişim, Duygusal bağ, Uzun vade
  final int total;
  SynastryResult(this.hits, this.scores, this.total);
}

const _synPlanets = ['sun', 'moon', 'mercury', 'venus', 'mars', 'jupiter', 'saturn'];
const _synCategories = {
  'Aşk ve çekim': {'venus': 1.0, 'mars': 1.0, 'sun': 0.5, 'moon': 0.4},
  'İletişim': {'mercury': 1.0, 'sun': 0.4, 'moon': 0.3, 'jupiter': 0.3},
  'Duygusal bağ': {'moon': 1.0, 'venus': 0.6, 'sun': 0.4},
  'Uzun vade': {'saturn': 1.0, 'sun': 0.5, 'moon': 0.5, 'jupiter': 0.6},
};

/// Klasik sinastri puanlaması: uyumlu açılar artırır, zorlayıcı açılar azaltır; orb küçüldükçe etki büyür.
SynastryResult synastry(ChartResult p1, ChartResult p2) {
  final hits = <SynastryHit>[];
  for (final a in _synPlanets) {
    for (final b in _synPlanets) {
      final orb = (a == 'moon' || b == 'moon' || a == 'sun' || b == 'sun') ? 7.0 : 6.0;
      final r = matchAspect(p1.planets[a]!, p2.planets[b]!, orb);
      if (r != null) hits.add(SynastryHit(a, r.key, b, r.orb));
    }
  }
  hits.sort((x, y) => x.orb.compareTo(y.orb));
  final scores = <String, int>{};
  for (final cat in _synCategories.entries) {
    var s = 0.0, w = 0.0;
    for (final h in hits) {
      final wa = cat.value[h.a] ?? 0, wb = cat.value[h.b] ?? 0;
      final wt = (wa + wb) * (1 - h.orb / 8.0);
      if (wt <= 0) continue;
      final sign = h.harmonious ? 1.0 : (h.aspect == 'conj' ? -0.3 : -0.8);
      s += sign * wt;
      w += wt;
    }
    // 0 etki = 60; güçlü uyum 95'e, güçlü gerilim 30'a yaklaşır
    final v = w == 0 ? 60.0 : 60 + 35 * (s / (w + 1.5));
    scores[cat.key] = v.round().clamp(25, 97);
  }
  final total = (scores.values.reduce((a, b) => a + b) / scores.length).round();
  return SynastryResult(hits, scores, total);
}

// ----------------------------------------------------------------------------- takvim
class SkyEvent {
  final DateTime utc;
  final String type; // retro, direct, newmoon, fullmoon, solar_eclipse, lunar_eclipse, ingress
  final String? planet;
  final int? sign;
  final double? lon; // olayın ekliptik boylamı (kişisel ev hesabı için)
  SkyEvent(this.utc, this.type, {this.planet, this.sign, this.lon});

  String get key => switch (type) {
        'retro' || 'direct' => 'ev:$type:$planet',
        'newmoon' || 'fullmoon' => 'ev:$type:$sign',
        'ingress' => 'ev:ingress:$planet:$sign',
        _ => 'ev:$type',
      };
}

double _elong(AstroEngine e, double jdTT) => norm360(e.planetLon('moon', jdTT) - e.planetLon('sun', jdTT));

double _bisect(double a, double b, bool Function(double) beforeEvent) {
  for (var i = 0; i < 24; i++) {
    final mid = (a + b) / 2;
    if (beforeEvent(mid)) {
      a = mid;
    } else {
      b = mid;
    }
  }
  return (a + b) / 2;
}

/// [fromUtc]'dan itibaren [days] gün içindeki olaylar
List<SkyEvent> skyEvents(AstroEngine e, DateTime fromUtc, int days) {
  final out = <SkyEvent>[];
  const step = 0.25; // 6 saat
  final start = ttFromUt(jdFromUtc(fromUtc), fromUtc.year);
  const stationPlanets = ['mercury', 'venus', 'mars', 'jupiter', 'saturn', 'uranus', 'neptune', 'pluto'];
  const ingressPlanets = ['sun', 'mercury', 'venus', 'mars', 'jupiter', 'saturn'];
  // Yavaş gezegenlerde duraklama günlerce sürer: hız geniş aralıkla ölçülür
  const span = {'mercury': 0.5, 'venus': 0.5, 'mars': 1.0, 'jupiter': 2.0, 'saturn': 2.0, 'uranus': 4.0, 'neptune': 4.0, 'pluto': 4.0};
  double speed(String p, double jd) =>
      ((e.planetLon(p, jd + span[p]!) - e.planetLon(p, jd - span[p]!) + 540) % 360) - 180;
  DateTime ut(double jdTT) => utcFromJd(jdTT - deltaT(fromUtc.year.toDouble()) / 86400.0);

  for (var jd = start; jd < start + days; jd += step) {
    final n = jd + step;
    // ay evreleri
    final e0 = _elong(e, jd), e1 = _elong(e, n);
    if (e1 < e0) {
      final t = _bisect(jd, n, (x) => _elong(e, x) > 180);
      final eclipse = _sep(e.planetLon('sun', t), meanNode(t)) < 17.5 || _sep(e.planetLon('sun', t), norm360(meanNode(t) + 180)) < 17.5;
      final l = e.planetLon('moon', t);
      out.add(SkyEvent(ut(t), eclipse ? 'solar_eclipse' : 'newmoon', sign: signIndex(l), lon: l));
    }
    if (e0 < 180 && e1 >= 180) {
      final t = _bisect(jd, n, (x) => _elong(e, x) < 180);
      final ml = e.planetLon('moon', t);
      final eclipse = _sep(ml, meanNode(t)) < 16.5 || _sep(ml, norm360(meanNode(t) + 180)) < 16.5;
      out.add(SkyEvent(ut(t), eclipse ? 'lunar_eclipse' : 'fullmoon', sign: signIndex(ml), lon: ml));
    }
    // burç geçişleri
    for (final p in ingressPlanets) {
      final s0 = signIndex(e.planetLon(p, jd)), s1 = signIndex(e.planetLon(p, n));
      if (s0 != s1) {
        final t = _bisect(jd, n, (x) => signIndex(e.planetLon(p, x)) == s0);
        out.add(SkyEvent(ut(t), 'ingress', planet: p, sign: s1, lon: s1 * 30.0 + 0.5));
      }
    }
  }
  // duraklamalar (günlük adım yeterli)
  for (final p in stationPlanets) {
    var prev = speed(p, start - 1);
    for (var jd = start; jd < start + days; jd += 1) {
      final s = speed(p, jd);
      if ((prev > 0) != (s > 0)) {
        final t = _bisect(jd - 1, jd, (x) => (speed(p, x) > 0) == (prev > 0));
        final pl = e.planetLon(p, t);
        out.add(SkyEvent(ut(t), s < 0 ? 'retro' : 'direct', planet: p, sign: signIndex(pl), lon: pl));
        jd += 10; // aynı duraklamayı iki kez sayma
        prev = speed(p, jd);
        continue;
      }
      prev = s;
    }
  }
  out.sort((a, b) => a.utc.compareTo(b.utc));
  return out;
}

/// Şu anda retro olan gezegenler
List<String> retrogradeNow(AstroEngine e, DateTime utc) {
  final jd = ttFromUt(jdFromUtc(utc), utc.year);
  return ['mercury', 'venus', 'mars', 'jupiter', 'saturn']
      .where((p) => ((e.planetLon(p, jd + 0.5) - e.planetLon(p, jd - 0.5) + 540) % 360) - 180 < 0)
      .toList();
}

// ----------------------------------------------------------------------------- yıllık harita
/// [year] yılındaki doğum gününe en yakın güneş dönüşü anı (UTC)
DateTime solarReturnUtc(AstroEngine e, double natalSun, DateTime birthDate, int year) {
  var guess = DateTime.utc(year, birthDate.month, m.min(birthDate.day, 28), 12);
  var jd = ttFromUt(jdFromUtc(guess), year);
  for (var i = 0; i < 30; i++) {
    final d = ((e.planetLon('sun', jd) - natalSun + 540) % 360) - 180;
    if (d.abs() < 1e-6) break;
    jd -= d / 0.9856;
  }
  return utcFromJd(jd - deltaT(year.toDouble()) / 86400.0);
}
