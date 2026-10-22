import 'package:flutter/material.dart';

import '../astro/engine.dart';
import '../astro/features.dart';
import '../birth.dart';
import '../theme.dart';
import '../ui/glyph.dart';
import '../zodiac.dart';
import 'birth_form.dart';
import 'common.dart';

/// Burç uyumu: kullanıcının haritası × kaydedilmiş bir kişinin haritası
class CompatScreen extends StatefulWidget {
  const CompatScreen({super.key});
  @override
  State<CompatScreen> createState() => _CompatScreenState();
}

class _CompatScreenState extends State<CompatScreen> {
  PersonalChart? me;
  List<BirthData> partners = [];
  int selected = 0;
  PersonalChart? other;
  SynastryResult? result;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final c = await ensureMyChart(context);
    if (!mounted) return;
    if (c == null) {
      Navigator.of(context).pop();
      return;
    }
    me = c;
    partners = await Astro.instance.loadPartners();
    await Astro.instance.loadLibrary('synastry');
    if (partners.isEmpty) {
      if (!mounted) return;
      final ok = await _addPartner();
      if (!ok && mounted) {
        Navigator.of(context).pop();
        return;
      }
    }
    await _compute();
  }

  Future<bool> _addPartner() async {
    final b = await BirthFormScreen.open(context, title: 'Karşılaştıracağın kişi', partner: true);
    if (b == null) return false;
    partners = [...partners, b];
    selected = partners.length - 1;
    await Astro.instance.savePartners(partners);
    return true;
  }

  Future<void> _compute() async {
    setState(() => loading = true);
    final o = await PersonalChart.compute(partners[selected]);
    final r = synastry(me!.result, o.result);
    if (mounted) {
      setState(() {
        other = o;
        result = r;
        loading = false;
      });
    }
  }

  Future<void> _remove(int i) async {
    partners = [...partners]..removeAt(i);
    await Astro.instance.savePartners(partners);
    if (partners.isEmpty) {
      if (!mounted) return;
      Navigator.of(context).pop();
      return;
    }
    selected = 0;
    await _compute();
  }

  String _aspectTitle(SynastryHit h, String otherName) {
    final a = kPlanetNames[h.a]!, b = kPlanetNames[h.b]!;
    if (h.a == h.b) return 'İkinizin $a konumu · ${aspectNamesTr[h.aspect]}';
    return 'Sen: $a – $otherName: $b · ${aspectNamesTr[h.aspect]}';
  }

  @override
  Widget build(BuildContext context) {
    final r = result, o = other, m = me;
    return FeatureScaffold(
      title: 'Burç uyumu',
      body: loading || r == null || o == null || m == null
          ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
          : ListView(padding: const EdgeInsets.fromLTRB(18, 4, 18, 28), children: [
              SizedBox(
                height: 40,
                child: ListView(scrollDirection: Axis.horizontal, children: [
                  for (var i = 0; i < partners.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: InputChip(
                        label: Text(partners[i].name),
                        selected: i == selected,
                        onPressed: () {
                          selected = i;
                          _compute();
                        },
                        onDeleted: () => _remove(i),
                        deleteButtonTooltipMessage: 'Sil',
                      ),
                    ),
                  ActionChip(
                    avatar: const Icon(Icons.add, size: 18),
                    label: const Text('Kişi ekle'),
                    onPressed: () async {
                      if (await _addPartner()) _compute();
                    },
                  ),
                ]),
              ),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: _Person(name: 'Sen', chart: m)),
                Column(children: [
                  Text('${r.total}%', style: AppText.display(46, color: AppColors.goldSoft, w: FontWeight.w700)),
                  Text('GENEL UYUM', style: AppText.label(10.5)),
                ]),
                Expanded(child: _Person(name: partners[selected].name, chart: o)),
              ]),
              const SizedBox(height: 16),
              GlassCard(
                padding: const EdgeInsets.all(16),
                child: Column(children: [
                  for (final e in r.scores.entries)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(children: [
                        Row(children: [
                          Expanded(child: Text(e.key, style: AppText.body(13.5, w: FontWeight.w600))),
                          Text('${e.value}%',
                              style: AppText.body(13.5, color: AppColors.goldSoft, w: FontWeight.w700)),
                        ]),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: e.value / 100,
                            minHeight: 8,
                            backgroundColor: const Color(0xFF2F2650),
                            color: AppColors.gold,
                          ),
                        ),
                      ]),
                    ),
                ]),
              ),
              const SizedBox(height: 18),
              const SectionLabel('Güneş burçlarınız'),
              GlassCard(
                padding: const EdgeInsets.all(16),
                child: Builder(builder: (_) {
                  final a = signIndex(m.result.planets['sun']!), b = signIndex(o.result.planets['sun']!);
                  final key = 'sc:${a < b ? a : b}:${a < b ? b : a}';
                  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${kZodiacs[a].name} ve ${kZodiacs[b].name}', style: AppText.body(15, w: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text(Astro.instance.text(key) ?? kTextPending,
                        style: AppText.body(14, color: const Color(0xFFCFC9E4), height: 1.5)),
                  ]);
                }),
              ),
              const SizedBox(height: 18),
              const SectionLabel('Haritalarınız arasında'),
              for (final h in r.hits.take(6))
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: GlassCard(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Glyph(h.a, size: 18, stroke: 8),
                        const SizedBox(width: 4),
                        Glyph(h.b, size: 18, stroke: 8),
                        const SizedBox(width: 10),
                        Expanded(
                            child: Text(_aspectTitle(h, partners[selected].name),
                                style: AppText.body(13.5, w: FontWeight.w700))),
                        TagChip(h.harmonious ? 'Uyum' : 'Dikkat'),
                      ]),
                      const SizedBox(height: 8),
                      Text(Astro.instance.text(h.key) ?? kTextPending,
                          style: AppText.body(13.5, color: const Color(0xFFCFC9E4), height: 1.5)),
                    ]),
                  ),
                ),
              Text(
                  'Uyum puanı iki doğum haritası arasındaki gezegen açılarından hesaplanır; '
                  'eğlence ve fikir vermek içindir.',
                  style: AppText.body(12, color: AppColors.muted)),
            ]),
    );
  }
}

class _Person extends StatelessWidget {
  final String name;
  final PersonalChart chart;
  const _Person({required this.name, required this.chart});

  @override
  Widget build(BuildContext context) {
    final sun = signIndex(chart.result.planets['sun']!);
    final asc = chart.hasHouses ? kZodiacs[signIndex(chart.result.asc)].name : null;
    return Column(children: [
      Container(
        width: 62,
        height: 62,
        alignment: Alignment.center,
        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0xFF8A7444))),
        child: Glyph(kZodiacs[sun].id, size: 32, stroke: 6.5),
      ),
      const SizedBox(height: 6),
      Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.body(14, w: FontWeight.w700)),
      Text('${kZodiacs[sun].name}${asc != null ? ' · Yük. $asc' : ''}',
          textAlign: TextAlign.center, style: AppText.body(11.5, color: AppColors.muted)),
    ]);
  }
}
