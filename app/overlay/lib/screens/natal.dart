import 'dart:math' as m;

import 'package:flutter/material.dart';

import '../astro/engine.dart';
import '../birth.dart';
import 'birth_form.dart';
import '../theme.dart';
import '../ui/glyph.dart';
import '../zodiac.dart';

enum NatalView { chart, rising, moon }

/// Doğum bilgisini alır (yoksa formu açar), haritayı hesaplar ve ilgili ekranı gösterir.
class NatalScreen extends StatefulWidget {
  final NatalView view;
  const NatalScreen({super.key, required this.view});
  @override
  State<NatalScreen> createState() => _NatalScreenState();
}

class _NatalScreenState extends State<NatalScreen> {
  PersonalChart? chart;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool edit = false}) async {
    var b = await Astro.instance.loadBirth();
    if (!mounted) return;
    if (b == null || edit) {
      final nb = await BirthFormScreen.open(context, initial: b);
      if (nb == null) {
        if (b == null && mounted) Navigator.of(context).pop();
        return;
      }
      await Astro.instance.saveBirth(nb);
      b = nb;
    }
    try {
      final results = await Future.wait([PersonalChart.compute(b), Astro.instance.loadNatalTexts()]);
      if (mounted) setState(() => chart = results[0] as PersonalChart);
    } catch (e) {
      if (mounted) setState(() => error = 'Hesaplama yapılamadı: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = switch (widget.view) {
      NatalView.chart => 'Doğum haritan',
      NatalView.rising => 'Yükselen burcun',
      NatalView.moon => 'Ay burcun',
    };
    return Scaffold(
      appBar: AppBar(title: Text(title), actions: [
        IconButton(
          tooltip: 'Doğum bilgilerini düzenle',
          onPressed: () {
            setState(() => chart = null);
            _load(edit: true);
          },
          icon: const Icon(Icons.edit_outlined),
        ),
      ]),
      body: StarfieldBackground(
        child: SafeArea(
          top: false,
          child: error != null
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(error!)))
              : chart == null
                  ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
                  : switch (widget.view) {
                      NatalView.chart => _ChartView(chart!),
                      NatalView.rising => _RisingView(chart!),
                      NatalView.moon => _MoonView(chart!),
                    },
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ ortak parçalar
String _missing() => 'Bu yerleşimin yorumu hazırlanıyor; kısa süre içinde burada olacak.';

Widget _birthLine(PersonalChart c) {
  final b = c.birth;
  final t = b.timeKnown ? '${b.hour!.toString().padLeft(2, '0')}:${b.minute!.toString().padLeft(2, '0')}' : 'saat bilinmiyor';
  return Text('${b.name.isEmpty ? '' : '${b.name} · '}${trDate(b.date)} · $t · ${b.place.label}',
      style: AppText.body(13, color: AppColors.muted));
}

class _BigSign extends StatelessWidget {
  final int sign;
  final String caption;
  final String? degree;
  const _BigSign({required this.sign, required this.caption, this.degree});

  @override
  Widget build(BuildContext context) {
    final z = kZodiacs[sign];
    return Column(children: [
      Container(
        width: 140,
        height: 140,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
          gradient: RadialGradient(colors: [AppColors.gold.withValues(alpha: 0.20), Colors.transparent]),
        ),
        child: Glyph(z.id, size: 76, color: AppColors.goldSoft, stroke: 5),
      ),
      const SizedBox(height: 14),
      Text(caption.toUpperCase(), style: AppText.label(12)),
      const SizedBox(height: 4),
      Text(z.name, style: AppText.display(44)),
      if (degree != null) Text(degree!, style: AppText.body(14, color: AppColors.muted)),
      const SizedBox(height: 6),
      Text('${z.element} · ${z.quality} · Yönetici: ${z.ruler}', style: AppText.body(13, color: AppColors.muted)),
    ]);
  }
}

class _TextCard extends StatelessWidget {
  final String? title;
  final String text;
  const _TextCard({this.title, required this.text});
  @override
  Widget build(BuildContext context) => GlassCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (title != null) ...[Text(title!, style: AppText.label(11.5)), const SizedBox(height: 10)],
          Text(text, style: AppText.body(16, height: 1.6)),
        ]),
      );
}

// ------------------------------------------------------------------ yükselen
class _RisingView extends StatelessWidget {
  final PersonalChart c;
  const _RisingView(this.c);
  @override
  Widget build(BuildContext context) {
    if (!c.hasHouses) {
      return ListView(padding: const EdgeInsets.all(20), children: [
        _birthLine(c),
        const SizedBox(height: 20),
        const _TextCard(
            title: 'DOĞUM SAATİ GEREKLİ',
            text: 'Yükselen burç, doğduğun anda doğu ufkunda yükselen burçtur ve yaklaşık her 2 saatte bir değişir. '
                'Bu yüzden doğru hesaplama için doğum saatin gerekiyor. Sağ üstteki kalem simgesinden saatini ekleyebilirsin.'),
      ]);
    }
    final s = signIndex(c.result.asc);
    final ruler = _rulerKey(s);
    final rulerLon = c.result.planets[ruler]!;
    return ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 28), children: [
      _birthLine(c),
      const SizedBox(height: 24),
      _BigSign(sign: s, caption: 'Yükselen burcun', degree: '${kZodiacs[s].name} ${degInSign(c.result.asc)}'),
      const SizedBox(height: 24),
      _TextCard(text: Astro.instance.text('asc:$s') ?? _missing()),
      const SizedBox(height: 12),
      _TextCard(
        title: 'HARİTANIN YÖNETİCİSİ',
        text: 'Yükselen burcunun yöneticisi ${kPlanetNames[ruler]}; haritanda ${kSignLoc[signIndex(rulerLon)]}, '
            '${c.result.houseOf(rulerLon)}. evde. Bu gezegen hayatına yön veren ana temaları gösterir.\n\n'
            '${Astro.instance.text('ps:$ruler:${signIndex(rulerLon)}') ?? ''}',
      ),
    ]);
  }
}

String _rulerKey(int sign) =>
    const ['mars', 'venus', 'mercury', 'moon', 'sun', 'mercury', 'venus', 'pluto', 'jupiter', 'saturn', 'uranus', 'neptune'][sign];

// ------------------------------------------------------------------ ay burcu
class _MoonView extends StatelessWidget {
  final PersonalChart c;
  const _MoonView(this.c);
  @override
  Widget build(BuildContext context) {
    final lon = c.result.planets['moon']!;
    final s = signIndex(lon);
    return ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 28), children: [
      _birthLine(c),
      const SizedBox(height: 24),
      _BigSign(sign: s, caption: 'Ay burcun', degree: c.hasHouses ? '${kZodiacs[s].name} ${degInSign(lon)}' : null),
      const SizedBox(height: 20),
      if (c.moonAltSign != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _TextCard(
            title: 'DİKKAT',
            text: 'Doğduğun gün Ay, ${kZodiacs[s].name} ile ${kZodiacs[c.moonAltSign!].name} arasında burç değiştirdi. '
                'Doğum saatin olmadan hangisi olduğu kesin bilinemez; aşağıdaki yorum gün ortasına göredir. '
                'Saatini eklersen kesin sonucu görürsün.',
          ),
        ),
      _TextCard(text: Astro.instance.text('moonsign:$s') ?? _missing()),
      if (c.hasHouses) ...[
        const SizedBox(height: 12),
        _TextCard(
          title: 'AY ${c.result.houseOf(lon)}. EVİNDE',
          text: Astro.instance.text('ph:moon:${c.result.houseOf(lon)}') ?? _missing(),
        ),
      ],
    ]);
  }
}

// ------------------------------------------------------------------ doğum haritası
class _ChartView extends StatelessWidget {
  final PersonalChart c;
  const _ChartView(this.c);

  @override
  Widget build(BuildContext context) {
    final r = c.result;
    final keys = AstroEngine.planetKeys;
    final aspects = <(String, String, String)>[];
    const major = ['sun', 'moon', 'mercury', 'venus', 'mars', 'jupiter', 'saturn'];
    for (var i = 0; i < major.length; i++) {
      for (var j = i + 1; j < major.length; j++) {
        final a = aspectBetween(r.planets[major[i]]!, r.planets[major[j]]!);
        if (a != null && (c.hasHouses || !(major[i] == 'moon' || major[j] == 'moon'))) {
          aspects.add((major[i], major[j], a.name));
        }
      }
    }
    return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 28), children: [
      Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: _birthLine(c)),
      const SizedBox(height: 12),
      AspectRatio(aspectRatio: 1, child: CustomPaint(painter: _WheelPainter(c))),
      if (!c.hasHouses)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text('Doğum saatin olmadığı için evler ve yükselen gösterilmiyor; Ay konumu gün ortasına göredir.',
              style: AppText.body(12.5, color: AppColors.muted)),
        ),
      const SizedBox(height: 16),
      Row(children: [
        if (c.hasHouses) Expanded(child: _MiniStat('Yükselen', signIndex(r.asc))),
        Expanded(child: _MiniStat('Güneş', signIndex(r.planets['sun']!))),
        Expanded(child: _MiniStat('Ay', signIndex(r.planets['moon']!))),
      ]),
      const SizedBox(height: 20),
      Text('GEZEGEN YERLEŞİMLERİ', style: AppText.label(12)),
      const SizedBox(height: 10),
      for (final k in keys) _PlacementTile(c: c, planet: k),
      if (aspects.isNotEmpty) ...[
        const SizedBox(height: 20),
        Text('ÖNEMLİ AÇILAR', style: AppText.label(12)),
        const SizedBox(height: 10),
        GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(children: [
            for (final a in aspects)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(children: [
                  Glyph(a.$1, size: 20, stroke: 8),
                  const SizedBox(width: 6),
                  Glyph(a.$2, size: 20, stroke: 8),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Text('${kPlanetNames[a.$1]} – ${kPlanetNames[a.$2]}: ${a.$3}',
                          style: AppText.body(14.5))),
                ]),
              ),
          ]),
        ),
      ],
      const SizedBox(height: 18),
      Text(
        'Konumlar doğum anının gerçek gökyüzüne göre telefonda hesaplanır (tropikal zodyak, Placidus ev sistemi).',
        style: AppText.body(12, color: AppColors.muted),
      ),
    ]);
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final int sign;
  const _MiniStat(this.label, this.sign);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: GlassCard(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          child: Column(children: [
            Glyph(kZodiacs[sign].id, size: 28, stroke: 7),
            const SizedBox(height: 6),
            Text(kZodiacs[sign].name, style: AppText.display(20, w: FontWeight.w700)),
            Text(label, style: AppText.body(11.5, color: AppColors.muted)),
          ]),
        ),
      );
}

class _PlacementTile extends StatelessWidget {
  final PersonalChart c;
  final String planet;
  const _PlacementTile({required this.c, required this.planet});

  @override
  Widget build(BuildContext context) {
    final lon = c.result.planets[planet]!;
    final s = signIndex(lon);
    final house = c.hasHouses ? c.result.houseOf(lon) : null;
    final moonUnsure = planet == 'moon' && c.moonAltSign != null;
    final subtitle = '${kZodiacs[s].name} ${c.hasHouses || planet != 'moon' ? degInSign(lon) : ''}'
        '${house != null ? ' · $house. ev' : ''}${moonUnsure ? ' (kesin değil)' : ''}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.line),
        ),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            leading: Glyph(planet, size: 28, stroke: 7),
            title: Text(kPlanetNames[planet]!, style: AppText.body(16, w: FontWeight.w700)),
            subtitle: Text(subtitle, style: AppText.body(13, color: AppColors.muted)),
            childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${kPlanetNames[planet]} ${kSignLoc[s]}'.toUpperCase(), style: AppText.label(11)),
              const SizedBox(height: 6),
              Text(Astro.instance.text('ps:$planet:$s') ?? _missing(), style: AppText.body(15, height: 1.55)),
              if (house != null) ...[
                const SizedBox(height: 14),
                Text('${kPlanetNames[planet]} $house. EVDE'.toUpperCase(), style: AppText.label(11)),
                const SizedBox(height: 6),
                Text(Astro.instance.text('ph:$planet:$house') ?? _missing(), style: AppText.body(15, height: 1.55)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _WheelPainter extends CustomPainter {
  final PersonalChart c;
  _WheelPainter(this.c);

  @override
  void paint(Canvas canvas, Size size) {
    final r = c.result;
    final center = size.center(Offset.zero);
    final R = size.width / 2 - 4;
    final ringIn = R * 0.80;
    final houseIn = R * 0.30;
    final ref = c.hasHouses ? r.asc : 0.0; // sol taraf
    Offset pt(double lon, double rad) {
      final a = (180 + (lon - ref)) * m.pi / 180;
      return center + Offset(m.cos(a) * rad, -m.sin(a) * rad);
    }

    final gold = Paint()
      ..color = AppColors.gold.withValues(alpha: 0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final faint = Paint()
      ..color = AppColors.gold.withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    canvas.drawCircle(center, R, Paint()..color = const Color(0xFF15112A));
    canvas.drawCircle(center, R, gold);
    canvas.drawCircle(center, ringIn, gold);
    canvas.drawCircle(center, houseIn, faint);

    // burç dilimleri
    for (var i = 0; i < 12; i++) {
      canvas.drawLine(pt(i * 30.0, ringIn), pt(i * 30.0, R), faint);
      final g = pt(i * 30.0 + 15, (R + ringIn) / 2);
      final gs = (R - ringIn) * 0.62;
      final el = AppColors.element(kZodiacs[i].element);
      canvas.save();
      canvas.translate(g.dx - gs / 2, g.dy - gs / 2);
      canvas.scale(gs / 100);
      canvas.drawPath(
          glyphPath(kZodiacs[i].id),
          Paint()
            ..color = el.withValues(alpha: 0.95)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 8
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round);
      canvas.restore();
    }

    // evler
    if (c.hasHouses) {
      for (var i = 0; i < 12; i++) {
        final axis = i == 0 || i == 3 || i == 6 || i == 9;
        canvas.drawLine(pt(r.cusps[i], houseIn), pt(r.cusps[i], ringIn), axis ? gold : faint);
        final next = r.cusps[(i + 1) % 12];
        final mid = r.cusps[i] + norm360(next - r.cusps[i]) / 2;
        final tp = TextPainter(
          text: TextSpan(text: '${i + 1}', style: AppText.body(10, color: AppColors.muted)),
          textDirection: TextDirection.ltr,
        )..layout();
        final p = pt(mid, houseIn + 10);
        tp.paint(canvas, p - Offset(tp.width / 2, tp.height / 2));
      }
    }

    // gezegenler: çakışmaları aç
    final keys = AstroEngine.planetKeys.toList()..sort((a, b) => r.planets[a]!.compareTo(r.planets[b]!));
    final placed = <String, double>{};
    double? last;
    for (final k in keys) {
      var l = r.planets[k]!;
      if (last != null && norm360(l - last) < 8) l = last + 8;
      placed[k] = l;
      last = l;
    }
    final pr = (ringIn + houseIn) / 2 + 12;
    final gsz = R * 0.11;
    for (final k in keys) {
      final real = r.planets[k]!;
      canvas.drawLine(pt(real, ringIn), pt(real, ringIn - 6), gold);
      final p = pt(placed[k]!, pr);
      canvas.drawCircle(p, gsz * 0.72, Paint()..color = const Color(0xFF221B3F));
      canvas.save();
      canvas.translate(p.dx - gsz / 2, p.dy - gsz / 2);
      canvas.scale(gsz / 100);
      canvas.drawPath(
          glyphPath(k),
          Paint()
            ..color = AppColors.goldSoft
            ..style = PaintingStyle.stroke
            ..strokeWidth = 9
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round);
      canvas.restore();
    }

    if (c.hasHouses) {
      final tp = TextPainter(
          text: TextSpan(text: 'ASC', style: AppText.label(9.5)), textDirection: TextDirection.ltr)
        ..layout();
      final p = pt(r.asc, houseIn - 14);
      tp.paint(canvas, p - Offset(tp.width / 2, tp.height / 2));
      final tm = TextPainter(text: TextSpan(text: 'MC', style: AppText.label(9.5)), textDirection: TextDirection.ltr)
        ..layout();
      final q = pt(r.mc, houseIn - 14);
      tm.paint(canvas, q - Offset(tm.width / 2, tm.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _WheelPainter old) => old.c != c;
}
