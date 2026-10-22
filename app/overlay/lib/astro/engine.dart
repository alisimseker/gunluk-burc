// Doğum haritası hesaplama motoru.
// Kaynaklar: Meeus "Astronomical Algorithms" (Ay: bölüm 47, yıldız zamanı: 12, eğiklik ve nütasyon: 22),
// JPL "Approximate Positions of the Planets" (Standish, Tablo 1).
// Güneş–Plüton için 1920–2050 arası Swiss Ephemeris'ten üretilmiş günlük tablo (assets/ephem.bin)
// 4 noktalı Lagrange ile ara değerlenir; tablo dışı tarihlerde Meeus/JPL formülleri kullanılır.
// Python referans sürümü 3000 rastgele haritada Swiss Ephemeris'ten en fazla 0,3 yay dakikası sapmıştır (Ay).
import 'dart:math' as m;
import 'dart:typed_data';

double _rad(double d) => d * m.pi / 180.0;
double _deg(double r) => r * 180.0 / m.pi;

double norm360(double x) {
  x = x % 360.0;
  return x < 0 ? x + 360.0 : x;
}

double julianDay(int y, int mo, int d, double hour) {
  if (mo <= 2) {
    y -= 1;
    mo += 12;
  }
  final a = (y / 100).floor();
  final b = 2 - a + (a / 4).floor();
  return (365.25 * (y + 4716)).floor() +
      (30.6001 * (mo + 1)).floor() +
      d +
      hour / 24.0 +
      b -
      1524.5;
}

double deltaT(double y) {
  double t;
  if (y < 1900) {
    t = y - 1860;
    return 7.62 + 0.5737 * t - 0.251754 * t * t + 0.01680668 * t * t * t -
        0.0004473624 * t * t * t * t + m.pow(t, 5) / 233174;
  }
  if (y < 1920) {
    t = y - 1900;
    return -2.79 + 1.494119 * t - 0.0598939 * t * t + 0.0061966 * t * t * t - 0.000197 * t * t * t * t;
  }
  if (y < 1941) {
    t = y - 1920;
    return 21.20 + 0.84493 * t - 0.076100 * t * t + 0.0020936 * t * t * t;
  }
  if (y < 1961) {
    t = y - 1950;
    return 29.07 + 0.407 * t - t * t / 233 + t * t * t / 2547;
  }
  if (y < 1986) {
    t = y - 1975;
    return 45.45 + 1.067 * t - t * t / 260 - t * t * t / 718;
  }
  if (y < 2005) {
    t = y - 2000;
    return 63.86 + 0.3345 * t - 0.060374 * t * t + 0.0017275 * t * t * t +
        0.000651814 * t * t * t * t + 0.00002373599 * m.pow(t, 5);
  }
  t = y - 2000;
  return 62.92 + 0.32217 * t + 0.005589 * t * t;
}

const Map<String, List<List<double>>> _elements = {
  'mercury': [
    [0.38709927, 0.20563593, 7.00497902, 252.25032350, 77.45779628, 48.33076593],
    [0.00000037, 0.00001906, -0.00594749, 149472.67411175, 0.16047689, -0.12534081]
  ],
  'venus': [
    [0.72333566, 0.00677672, 3.39467605, 181.97909950, 131.60246718, 76.67984255],
    [0.00000390, -0.00004107, -0.00078890, 58517.81538729, 0.00268329, -0.27769418]
  ],
  'earth': [
    [1.00000261, 0.01671123, -0.00001531, 100.46457166, 102.93768193, 0.0],
    [0.00000562, -0.00004392, -0.01294668, 35999.37244981, 0.32327364, 0.0]
  ],
  'mars': [
    [1.52371034, 0.09339410, 1.84969142, -4.55343205, -23.94362959, 49.55953891],
    [0.00001847, 0.00007882, -0.00813131, 19140.30268499, 0.44441088, -0.29257343]
  ],
  'jupiter': [
    [5.20288700, 0.04838624, 1.30439695, 34.39644051, 14.72847983, 100.47390909],
    [-0.00011607, -0.00013253, -0.00183714, 3034.74612775, 0.21252668, 0.20469106]
  ],
  'saturn': [
    [9.53667594, 0.05386179, 2.48599187, 49.95424423, 92.59887831, 113.66242448],
    [-0.00125060, -0.00050991, 0.00193609, 1222.49362201, -0.41897216, -0.28867794]
  ],
  'uranus': [
    [19.18916464, 0.04725744, 0.77263783, 313.23810451, 170.95427630, 74.01692503],
    [-0.00196176, -0.00004397, -0.00242939, 428.48202785, 0.40805281, 0.04240589]
  ],
  'neptune': [
    [30.06992276, 0.00859048, 1.77004347, -55.12002969, 44.96476227, 131.78422574],
    [0.00026291, 0.00005105, 0.00035372, 218.45945325, -0.32241464, -0.00508664]
  ],
  'pluto': [
    [39.48211675, 0.24882730, 17.14001206, 238.92903833, 224.06891629, 110.30393684],
    [-0.00031596, 0.00005170, 0.00004818, 145.20780515, -0.04062942, -0.01183482]
  ],
};

List<double> _helio(String name, double T) {
  final el = _elements[name]![0], rt = _elements[name]![1];
  final v = List<double>.generate(6, (i) => el[i] + rt[i] * T);
  final a = v[0], e = v[1], inc = v[2], L = v[3], wbar = v[4], node = v[5];
  final w = wbar - node;
  var mAnom = norm360(L - wbar);
  if (mAnom > 180) mAnom -= 360;
  final mr = _rad(mAnom);
  var E = mr + e * m.sin(mr);
  for (var i = 0; i < 30; i++) {
    final dE = (mr - (E - e * m.sin(E))) / (1 - e * m.cos(E));
    E += dE;
    if (dE.abs() < 1e-12) break;
  }
  final xp = a * (m.cos(E) - e);
  final yp = a * m.sqrt(1 - e * e) * m.sin(E);
  final cw = m.cos(_rad(w)), sw = m.sin(_rad(w));
  final cO = m.cos(_rad(node)), sO = m.sin(_rad(node));
  final cI = m.cos(_rad(inc)), sI = m.sin(_rad(inc));
  final x = (cw * cO - sw * sO * cI) * xp + (-sw * cO - cw * sO * cI) * yp;
  final y = (cw * sO + sw * cO * cI) * xp + (-sw * sO + cw * cO * cI) * yp;
  final z = (sw * sI) * xp + (cw * sI) * yp;
  return [x, y, z];
}

/// [Δψ, Δε] derece
List<double> nutation(double T) {
  final om = _rad(125.04452 - 1934.136261 * T);
  final L = _rad(280.4665 + 36000.7698 * T);
  final lp = _rad(218.3165 + 481267.8813 * T);
  final dpsi = -17.20 * m.sin(om) - 1.32 * m.sin(2 * L) - 0.23 * m.sin(2 * lp) + 0.21 * m.sin(2 * om);
  final deps = 9.20 * m.cos(om) + 0.57 * m.cos(2 * L) + 0.10 * m.cos(2 * lp) - 0.09 * m.cos(2 * om);
  return [dpsi / 3600.0, deps / 3600.0];
}

double obliquity(double T) {
  final e0 = 23 + 26 / 60 + 21.448 / 3600 - (46.8150 * T + 0.00059 * T * T - 0.001813 * T * T * T) / 3600;
  return e0 + nutation(T)[1];
}

double _precession(double T) => (5028.796195 * T + 1.1054348 * T * T) / 3600.0;

double _analyticPlanet(String name, double jdTT) {
  final T = (jdTT - 2451545.0) / 36525.0;
  final ea = _helio('earth', T);
  double lon;
  if (name == 'sun') {
    lon = norm360(_deg(m.atan2(-ea[1], -ea[0]))) - 20.4898 / 3600.0;
  } else {
    var tau = 0.0;
    var d = [0.0, 0.0, 0.0];
    for (var i = 0; i < 2; i++) {
      final tp = (jdTT - tau - 2451545.0) / 36525.0;
      final p = _helio(name, tp);
      d = [p[0] - ea[0], p[1] - ea[1], p[2] - ea[2]];
      tau = 0.0057755183 * m.sqrt(d[0] * d[0] + d[1] * d[1] + d[2] * d[2]);
    }
    lon = norm360(_deg(m.atan2(d[1], d[0])));
  }
  return norm360(lon + _precession(T) + nutation(T)[0]);
}

const List<List<int>> _moonTerms = [
  [0, 0, 1, 0, 6288774], [2, 0, -1, 0, 1274027], [2, 0, 0, 0, 658314], [0, 0, 2, 0, 213618],
  [0, 1, 0, 0, -185116], [0, 0, 0, 2, -114332], [2, 0, -2, 0, 58793], [2, -1, -1, 0, 57066],
  [2, 0, 1, 0, 53322], [2, -1, 0, 0, 45758], [0, 1, -1, 0, -40923], [1, 0, 0, 0, -34720],
  [0, 1, 1, 0, -30383], [2, 0, 0, -2, 15327], [0, 0, 1, 2, -12528], [0, 0, 1, -2, 10980],
  [4, 0, -1, 0, 10675], [0, 0, 3, 0, 10034], [4, 0, -2, 0, 8548], [2, 1, -1, 0, -7888],
  [2, 1, 0, 0, -6766], [1, 0, -1, 0, -5163], [1, 1, 0, 0, 4987], [2, -1, 1, 0, 4036],
  [2, 0, 2, 0, 3994], [4, 0, 0, 0, 3861], [2, 0, -3, 0, 3665], [0, 1, -2, 0, -2689],
  [2, 0, -1, 2, -2602], [2, -1, -2, 0, 2390], [1, 0, 1, 0, -2348], [2, -2, 0, 0, 2236],
  [0, 1, 2, 0, -2120], [0, 2, 0, 0, -2069], [2, -2, -1, 0, 2048], [2, 0, 1, -2, -1773],
  [2, 0, 0, 2, -1595], [4, -1, -1, 0, 1215], [0, 0, 2, 2, -1110], [3, 0, -1, 0, -892],
  [2, 1, 1, 0, -810], [4, -1, -2, 0, 759], [0, 2, -1, 0, -713], [2, 2, -1, 0, -700],
  [2, 1, -2, 0, 691], [2, -1, 0, -2, 596], [4, 0, 1, 0, 549], [0, 0, 4, 0, 537],
  [4, -1, 0, 0, 520], [1, 0, -2, 0, -487], [2, 1, 0, -2, -399], [0, 0, 2, -2, -381],
  [1, 1, 1, 0, 351], [3, 0, -2, 0, -340], [4, 0, -3, 0, 330], [2, -1, 2, 0, 327],
  [0, 2, 1, 0, -323], [1, 1, -1, 0, 299], [2, 0, 3, 0, 294],
];

double moonLon(double jdTT) {
  final T = (jdTT - 2451545.0) / 36525.0;
  final t2 = T * T, t3 = t2 * T, t4 = t3 * T;
  final lp = 218.3164477 + 481267.88123421 * T - 0.0015786 * t2 + t3 / 538841 - t4 / 65194000;
  final D = 297.8501921 + 445267.1114034 * T - 0.0018819 * t2 + t3 / 545868 - t4 / 113065000;
  final M = 357.5291092 + 35999.0502909 * T - 0.0001536 * t2 + t3 / 24490000;
  final mp = 134.9633964 + 477198.8675055 * T + 0.0087414 * t2 + t3 / 69699 - t4 / 14712000;
  final F = 93.2720950 + 483202.0175233 * T - 0.0036539 * t2 - t3 / 3526000 + t4 / 863310000;
  final E = 1 - 0.002516 * T - 0.0000074 * t2;
  var s = 0.0;
  for (final t in _moonTerms) {
    final arg = _rad(t[0] * D + t[1] * M + t[2] * mp + t[3] * F);
    final k = t[1].abs() == 1 ? E : (t[1].abs() == 2 ? E * E : 1.0);
    s += t[4] * k * m.sin(arg);
  }
  final a1 = _rad(119.75 + 131.849 * T), a2 = _rad(53.09 + 479264.290 * T);
  s += 3958 * m.sin(a1) + 1962 * m.sin(_rad(lp - F)) + 318 * m.sin(a2);
  return norm360(lp + s / 1e6 + nutation(T)[0]);
}

double meanNode(double jdTT) {
  final T = (jdTT - 2451545.0) / 36525.0;
  return norm360(125.0445479 - 1934.1362891 * T + 0.0020754 * T * T +
      T * T * T / 467441 - T * T * T * T / 60616000);
}

double siderealDeg(double jdUT) {
  final T = (jdUT - 2451545.0) / 36525.0;
  final g = 280.46061837 + 360.98564736629 * (jdUT - 2451545.0) + 0.000387933 * T * T - T * T * T / 38710000;
  return norm360(g + nutation(T)[0] * m.cos(_rad(obliquity(T))));
}

/// Gezegen tablosu (Swiss Ephemeris'ten üretilmiş).
/// EPH1: Mars–Plüton, 2 gün, uint16.  EPH2: Güneş–Plüton, 1 gün, uint32 (≈0.0001″ çözünürlük).
class SlowTable {
  static const order1 = ['mars', 'jupiter', 'saturn', 'uranus', 'neptune', 'pluto'];
  static const order2 = ['sun', 'mercury', 'venus', 'mars', 'jupiter', 'saturn', 'uranus', 'neptune', 'pluto'];
  final double start, step;
  final int n;
  final Map<String, List<int>> data;
  final double scale;
  SlowTable._(this.start, this.step, this.n, this.data, this.scale);

  bool has(String name) => data.containsKey(name);

  static SlowTable? parse(ByteData b) {
    if (b.lengthInBytes < 28) return null;
    final magic = String.fromCharCodes([b.getUint8(0), b.getUint8(1), b.getUint8(2), b.getUint8(3)]);
    if (magic != 'EPH1' && magic != 'EPH2') return null;
    final v2 = magic == 'EPH2';
    final start = b.getFloat64(4, Endian.little);
    final step = b.getFloat64(12, Endian.little);
    final n = b.getInt32(20, Endian.little);
    final np = b.getUint32(24, Endian.little);
    final order = v2 ? order2 : order1;
    final width = v2 ? 4 : 2;
    final data = <String, List<int>>{};
    var off = 28;
    for (var k = 0; k < np && k < order.length; k++) {
      final List<int> arr = v2 ? Uint32List(n) : Uint16List(n);
      for (var i = 0; i < n; i++) {
        arr[i] = v2 ? b.getUint32(off + i * 4, Endian.little) : b.getUint16(off + i * 2, Endian.little);
      }
      data[order[k]] = arr;
      off += n * width;
    }
    return SlowTable._(start, step, n, data, v2 ? 360.0 / 4294967296.0 : 360.0 / 65536.0);
  }

  double? lon(String name, double jdTT) {
    final arr = data[name];
    if (arr == null) return null;
    final x = (jdTT - start) / step;
    final i = x.floor() - 1;
    if (i < 0 || i + 3 >= n) return null;
    final v = List<double>.generate(4, (k) => arr[i + k] * scale);
    for (var k = 1; k < 4; k++) {
      while (v[k] - v[k - 1] > 180) {
        v[k] -= 360;
      }
      while (v[k] - v[k - 1] < -180) {
        v[k] += 360;
      }
    }
    final t = x - (i + 1);
    final l0 = -t * (t - 1) * (t - 2) / 6;
    final l1 = (t + 1) * (t - 1) * (t - 2) / 2;
    final l2 = -(t + 1) * t * (t - 2) / 2;
    final l3 = (t + 1) * t * (t - 1) / 6;
    return norm360(v[0] * l0 + v[1] * l1 + v[2] * l2 + v[3] * l3);
  }
}

class ChartResult {
  /// Gezegen anahtarı → ekliptik boylam (derece)
  final Map<String, double> planets;
  final double asc, mc;

  /// 12 ev başlangıcı (Placidus; kutup bölgelerinde eşit ev)
  final List<double> cusps;
  final bool placidus;
  ChartResult(this.planets, this.asc, this.mc, this.cusps, this.placidus);

  int houseOf(double lon) {
    for (var i = 0; i < 12; i++) {
      final a = cusps[i], b = cusps[(i + 1) % 12];
      final span = norm360(b - a);
      if (norm360(lon - a) < span) return i + 1;
    }
    return 1;
  }
}

class AstroEngine {
  final SlowTable? table;
  AstroEngine(this.table);

  static const planetKeys = [
    'sun', 'moon', 'mercury', 'venus', 'mars', 'jupiter', 'saturn', 'uranus', 'neptune', 'pluto', 'node'
  ];

  double planetLon(String name, double jdTT) {
    if (name == 'moon') return moonLon(jdTT);
    if (name == 'node') return meanNode(jdTT);
    final r = table?.lon(name, jdTT);
    if (r != null) return r;
    return _analyticPlanet(name, jdTT);
  }

  /// utc: doğum anının UTC karşılığı
  ChartResult chart(DateTime utc, double lat, double lon, {bool withHouses = true}) {
    final hour = utc.hour + utc.minute / 60.0 + utc.second / 3600.0;
    final jdUT = julianDay(utc.year, utc.month, utc.day, hour);
    final jdTT = jdUT + deltaT(utc.year + (utc.month - 0.5) / 12) / 86400.0;
    final planets = {for (final k in planetKeys) k: planetLon(k, jdTT)};

    final T = (jdUT - 2451545.0) / 36525.0;
    final eps = _rad(obliquity(T));
    final ramc = norm360(siderealDeg(jdUT) + lon);
    final r = _rad(ramc);
    final mc = norm360(_deg(m.atan2(m.sin(r), m.cos(r) * m.cos(eps))));
    final asc = norm360(_deg(m.atan2(m.cos(r), -(m.sin(r) * m.cos(eps) + m.tan(_rad(lat)) * m.sin(eps)))));

    final cusps = List<double>.filled(12, 0);
    var placidus = false;
    if (lat.abs() < 66.0) {
      placidus = true;
      final phi = _rad(lat);
      double cusp(double offset, double frac, bool upper) {
        var ra = norm360(ramc + offset);
        for (var i = 0; i < 50; i++) {
          final l = m.atan2(m.sin(_rad(ra)), m.cos(_rad(ra)) * m.cos(eps));
          final dec = m.asin(m.sin(eps) * m.sin(l));
          final x = (m.tan(phi) * m.tan(dec)).clamp(-1.0, 1.0);
          final ad = _deg(m.asin(x));
          final nw = upper ? norm360(ramc + frac * (90 + ad)) : norm360(ramc + 180 - frac * (90 - ad));
          final diff = ((nw - ra + 540) % 360) - 180;
          ra = nw;
          if (diff.abs() < 1e-9) break;
        }
        return norm360(_deg(m.atan2(m.sin(_rad(ra)), m.cos(_rad(ra)) * m.cos(eps))));
      }

      cusps[0] = asc;
      cusps[9] = mc;
      cusps[10] = cusp(30, 1 / 3, true);
      cusps[11] = cusp(60, 2 / 3, true);
      cusps[1] = cusp(120, 2 / 3, false);
      cusps[2] = cusp(150, 1 / 3, false);
      cusps[3] = norm360(mc + 180);
      cusps[4] = norm360(cusps[10] + 180);
      cusps[5] = norm360(cusps[11] + 180);
      cusps[6] = norm360(asc + 180);
      cusps[7] = norm360(cusps[1] + 180);
      cusps[8] = norm360(cusps[2] + 180);
    } else {
      for (var i = 0; i < 12; i++) {
        cusps[i] = norm360(asc + 30.0 * i);
      }
    }
    return ChartResult(planets, asc, mc, cusps, placidus);
  }
}

int signIndex(double lon) => (norm360(lon) ~/ 30) % 12;

String degInSign(double lon) {
  final d = norm360(lon) % 30;
  final deg = d.floor();
  final min = ((d - deg) * 60).floor();
  return "$deg°${min.toString().padLeft(2, '0')}'";
}

/// Açılar: iki boylam arası açı türü (orb dahil) ya da null
const aspectDefs = [
  [0, 8, 'kavuşum'],
  [60, 5, 'altmışlık'],
  [90, 7, 'kare'],
  [120, 7, 'üçgen'],
  [180, 8, 'karşıt'],
];

({int angle, String name, double orb})? aspectBetween(double a, double b) {
  var d = (norm360(a - b));
  if (d > 180) d = 360 - d;
  for (final def in aspectDefs) {
    final ang = def[0] as int, orb = (def[1] as int).toDouble();
    final o = (d - ang).abs();
    if (o <= orb) return (angle: ang, name: def[2] as String, orb: o);
  }
  return null;
}
