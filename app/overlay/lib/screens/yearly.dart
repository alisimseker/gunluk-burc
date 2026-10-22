import 'package:flutter/material.dart';
import 'package:timezone/timezone.dart' as tz;

import '../astro/engine.dart';
import '../astro/features.dart';
import '../birth.dart';
import '../theme.dart';
import '../ui/glyph.dart';
import '../zodiac.dart';
import 'common.dart';

/// Yıllık öngörü: güneş dönüşü (doğum günü) haritası
class YearlyScreen extends StatefulWidget {
  const YearlyScreen({super.key});
  @override
  State<YearlyScreen> createState() => _YearlyScreenState();
}

class _YearlyScreenState extends State<YearlyScreen> {
  PersonalChart? me;
  ChartResult? sr;
  DateTime? srLocal, nextLocal;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool edit = false}) async {
    final c = await ensureMyChart(context, edit: edit);
    if (!mounted) return;
    if (c == null) {
      Navigator.of(context).pop();
      return;
    }
    me = c;
    await Astro.instance.loadLibrary('solar');
    final eng = await Astro.instance.engine();
    final sun = c.result.planets['sun']!;
    final now = DateTime.now().toUtc();
    var t = solarReturnUtc(eng, sun, c.birth.date, now.year);
    if (t.isAfter(now)) t = solarReturnUtc(eng, sun, c.birth.date, now.year - 1);
    final next = solarReturnUtc(eng, sun, c.birth.date, t.year + 1);
    final p = c.birth.place;
    sr = eng.chart(t, p.lat, p.lon);
    // yerel saat: doğum yerinin saat dilimine göre
    srLocal = _local(c.birth, t);
    nextLocal = _local(c.birth, next);
    if (mounted) setState(() => loading = false);
  }

  /// Doğum yerinin o tarihteki resmî saatiyle yerel zaman
  DateTime _local(BirthData b, DateTime utc) => tz.TZDateTime.from(utc, tz.getLocation(b.place.tzName));

  static const _planets = ['sun', 'moon', 'venus', 'mars', 'jupiter', 'saturn'];
  static const _themes = {
    'sun': 'Yılın ana sahnesi',
    'moon': 'Duygusal odak',
    'venus': 'Aşk ve keyif',
    'mars': 'Enerjini harcadığın alan',
    'jupiter': 'Büyüme ve şans',
    'saturn': 'Sabır ve emek',
  };

  @override
  Widget build(BuildContext context) {
    final r = sr, a = srLocal, n = nextLocal;
    return FeatureScaffold(
      title: 'Yıllık öngörü',
      actions: [
        IconButton(
          tooltip: 'Doğum bilgilerini düzenle',
          icon: const Icon(Icons.edit_outlined),
          onPressed: () {
            setState(() => loading = true);
            _load(edit: true);
          },
        ),
      ],
      body: loading || r == null || a == null || n == null || me == null
          ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
          : ListView(padding: const EdgeInsets.fromLTRB(18, 4, 18, 28), children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  color: const Color(0xFF2E2357),
                  border: Border.all(color: const Color(0xFF5A4A82)),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('SENİN YILIN', style: AppText.label(11)),
                  const SizedBox(height: 6),
                  Text('${trDate(a)} – ${trDate(n)}',
                      style: AppText.display(26, color: AppColors.goldSoft, w: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(
                    "Doğum günü haritan: Güneş'in doğduğun konuma döndüğü an "
                    '(${a.hour.toString().padLeft(2, '0')}:${a.minute.toString().padLeft(2, '0')}, ${me!.birth.place.label})',
                    style: AppText.body(12.5, color: const Color(0xFFCFC9E4)),
                  ),
                ]),
              ),
              const SizedBox(height: 14),
              if (me!.hasHouses) ...[
                GlassCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Glyph(kZodiacs[signIndex(r.asc)].id, size: 30, stroke: 6.5),
                      const SizedBox(width: 12),
                      Text('Yılın yükseleni: ${kZodiacs[signIndex(r.asc)].name}',
                          style: AppText.body(15.5, w: FontWeight.w700)),
                    ]),
                    const SizedBox(height: 8),
                    Text(Astro.instance.text('sr:asc:${signIndex(r.asc)}') ?? kTextPending,
                        style: AppText.body(14.5, height: 1.55)),
                  ]),
                ),
                const SizedBox(height: 18),
                const SectionLabel('Yılın temaları'),
                for (final p in _planets)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: GlassCard(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Glyph(p, size: 20, stroke: 8),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text('${_themes[p]} · ${kPlanetNames[p]} ${r.houseOf(r.planets[p]!)}. evde',
                                style: AppText.body(14, w: FontWeight.w700)),
                          ),
                        ]),
                        const SizedBox(height: 8),
                        Text(Astro.instance.text('sr:$p:${r.houseOf(r.planets[p]!)}') ?? kTextPending,
                            style: AppText.body(14, color: const Color(0xFFCFC9E4), height: 1.5)),
                      ]),
                    ),
                  ),
              ] else
                GlassCard(
                  child: Text(
                    'Yıllık harita evlere göre yorumlanır; bunun için doğum saatin gerekiyor. '
                    'Sağ üstteki kalem simgesinden saatini ekleyebilirsin.',
                    style: AppText.body(15),
                  ),
                ),
            ]),
    );
  }
}
