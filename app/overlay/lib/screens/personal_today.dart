import 'package:flutter/material.dart';

import '../astro/features.dart';
import '../birth.dart';
import '../theme.dart';
import '../ui/glyph.dart';
import '../zodiac.dart';
import 'common.dart';

/// Günün gökyüzü × kullanıcının doğum haritası
class PersonalTodayScreen extends StatefulWidget {
  const PersonalTodayScreen({super.key});
  @override
  State<PersonalTodayScreen> createState() => _PersonalTodayScreenState();
}

class _PersonalTodayScreenState extends State<PersonalTodayScreen> {
  PersonalChart? chart;
  List<TransitHit> hits = [];
  int offset = 0;
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
    await Astro.instance.loadLibrary('transits');
    chart = c;
    await _compute();
  }

  Future<void> _compute() async {
    final eng = await Astro.instance.engine();
    final now = DateTime.now();
    final day = DateTime(now.year, now.month, now.day, 12).add(Duration(days: offset)).toUtc();
    final h = transitsFor(eng, chart!.result, day, withAngles: chart!.hasHouses);
    if (mounted) {
      setState(() {
        hits = h;
        loading = false;
      });
    }
  }

  String _line(TransitHit h) =>
      '${kPlanetNames[h.transit]} → doğum ${_pointName(h.natal)} · ${aspectNamesTr[h.aspect]}';

  static const _poss = {
    'sun': "Güneş'in", 'moon': "Ay'ın", 'mercury': "Merkür'ün", 'venus': "Venüs'ün", 'mars': "Mars'ın",
    'jupiter': "Jüpiter'in", 'saturn': "Satürn'ün", 'asc': "Yükselen'in", 'mc': 'Tepe noktanın (MC)',
  };
  String _pointName(String k) => _poss[k] ?? k;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final day = DateTime(now.year, now.month, now.day).add(Duration(days: offset));
    final c = chart;
    return FeatureScaffold(
      title: 'Bugün sana özel',
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
      body: loading || c == null
          ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
          : ListView(padding: const EdgeInsets.fromLTRB(18, 4, 18, 28), children: [
              Text('${trLongDate(day)} · günün gökyüzü × senin doğum haritan',
                  style: AppText.body(13, color: AppColors.muted)),
              const SizedBox(height: 12),
              Row(children: [
                for (final o in [0, 1])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(o == 0 ? 'Bugün' : 'Yarın'),
                      selected: offset == o,
                      onSelected: (_) {
                        setState(() {
                          offset = o;
                          loading = true;
                        });
                        _compute();
                      },
                    ),
                  ),
              ]),
              const SizedBox(height: 12),
              if (hits.isEmpty)
                GlassCard(
                  child: Text(
                      'Bugün doğum haritana güçlü bir açı yok: sakin, kendi ritminde ilerleyebileceğin bir gün.',
                      style: AppText.body(15)),
                )
              else ...[
                _MainCard(hit: hits.first, line: _line(hits.first), chart: c),
                if (hits.length > 1) const SizedBox(height: 18),
                if (hits.length > 1) const SectionLabel('Diğer etkiler'),
                for (final h in hits.skip(1).take(5))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: GlassCard(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Glyph(h.transit, size: 20, stroke: 8),
                          const SizedBox(width: 10),
                          Expanded(child: Text(_line(h), style: AppText.body(14, w: FontWeight.w700))),
                          const SizedBox(width: 8),
                          TagChip(h.tag),
                        ]),
                        const SizedBox(height: 8),
                        Text(Astro.instance.text(h.key) ?? kTextPending,
                            style: AppText.body(14, color: const Color(0xFFCFC9E4), height: 1.5)),
                      ]),
                    ),
                  ),
              ],
              const SizedBox(height: 10),
              Text(
                  c.hasHouses
                      ? 'Etkiler, günün gerçek gezegen konumları ile doğum haritanın karşılaştırılmasıyla hesaplanır.'
                      : 'Doğum saatin olmadığı için yükselen ve MC etkileri hesaba katılmadı.',
                  style: AppText.body(12, color: AppColors.muted)),
            ]),
    );
  }
}

class _MainCard extends StatelessWidget {
  final TransitHit hit;
  final String line;
  final PersonalChart chart;
  const _MainCard({required this.hit, required this.line, required this.chart});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: const Color(0xFF2E2357),
        border: Border.all(color: const Color(0xFF5A4A82)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('GÜNÜN ANA ETKİSİ', style: AppText.label(11)),
          const Spacer(),
          TagChip(hit.tag),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Glyph(hit.transit, size: 30, color: AppColors.goldSoft, stroke: 7),
          const SizedBox(width: 10),
          Expanded(child: Text(line, style: AppText.body(15, color: AppColors.goldSoft, w: FontWeight.w700))),
        ]),
        const SizedBox(height: 6),
        Text(
          '${kPlanetNames[hit.transit]} şu an ${kSignLoc[hit.transitSign]}'
          '${chart.hasHouses ? ', senin ${chart.result.houseOf(hit.transitLon)}. evinde' : ''}',
          style: AppText.body(12.5, color: AppColors.muted),
        ),
        const SizedBox(height: 10),
        Text(Astro.instance.text(hit.key) ?? kTextPending, style: AppText.body(15.5, height: 1.55)),
      ]),
    );
  }
}
