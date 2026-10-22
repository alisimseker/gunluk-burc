import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../astro/features.dart';
import '../birth.dart';
import '../native_bridge.dart';
import '../theme.dart';
import '../ui/glyph.dart';
import '../zodiac.dart';
import 'common.dart';

const _months = ['OCA', 'ŞUB', 'MAR', 'NİS', 'MAY', 'HAZ', 'TEM', 'AĞU', 'EYL', 'EKİ', 'KAS', 'ARA'];
const _signGen = [
  "Koç burcunda", "Boğa burcunda", "İkizler burcunda", "Yengeç burcunda", "Aslan burcunda", "Başak burcunda",
  "Terazi burcunda", "Akrep burcunda", "Yay burcunda", "Oğlak burcunda", "Kova burcunda", "Balık burcunda"
];

String eventTitle(SkyEvent e) {
  final p = e.planet == null ? '' : kPlanetNames[e.planet]!;
  final s = e.sign == null ? '' : _signGen[e.sign!];
  return switch (e.type) {
    'retro' => '$p retrosu başlıyor',
    'direct' => '$p düz harekete geçiyor',
    'newmoon' => 'Yeniay $s',
    'fullmoon' => 'Dolunay $s',
    'solar_eclipse' => 'Güneş tutulması $s',
    'lunar_eclipse' => 'Ay tutulması $s',
    'ingress' => '$p ${kZodiacs[e.sign!].name} burcuna geçiyor',
    _ => e.type,
  };
}

String eventKind(SkyEvent e) => switch (e.type) {
      'retro' => 'Retro',
      'direct' => 'Retro biter',
      'newmoon' => 'Yeniay',
      'fullmoon' => 'Dolunay',
      'solar_eclipse' || 'lunar_eclipse' => 'Tutulma',
      _ => 'Geçiş',
    };

String eventGlyph(SkyEvent e) => e.planet ?? (e.type.contains('eclipse') ? 'sun' : 'moon');

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});
  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  static const _kNotify = 'sky_notify';
  List<SkyEvent> events = [];
  List<String> retroNow = [];
  PersonalChart? me;
  bool notify = true;
  bool loading = true;
  int? open;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final eng = await Astro.instance.engine();
    final b = await Astro.instance.loadBirth();
    me = b == null ? null : await PersonalChart.compute(b);
    await Astro.instance.loadLibrary('events');
    final now = DateTime.now().toUtc();
    events = skyEvents(eng, now, 120);
    retroNow = retrogradeNow(eng, now);
    notify = (await SharedPreferences.getInstance()).getBool(_kNotify) ?? true;
    if (notify) await scheduleSkyNotifications(events);
    if (mounted) setState(() => loading = false);
  }

  Future<void> _toggle(bool v) async {
    setState(() => notify = v);
    await (await SharedPreferences.getInstance()).setBool(_kNotify, v);
    if (v) {
      await NativeBridge.requestNotificationPermission();
      await scheduleSkyNotifications(events);
    } else {
      await NativeBridge.cancelSkyEvents();
    }
  }

  String? _personal(SkyEvent e) {
    final c = me;
    if (c == null || !c.hasHouses || e.lon == null) return null;
    return 'Senin haritanda ${c.result.houseOf(e.lon!)}. evini etkiliyor.';
  }

  @override
  Widget build(BuildContext context) {
    return FeatureScaffold(
      title: 'Gökyüzü takvimi',
      body: loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
          : ListView(padding: const EdgeInsets.fromLTRB(18, 4, 18, 28), children: [
              if (retroNow.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: const Color(0xFF2E2357),
                    border: Border.all(color: const Color(0xFF5A4A82)),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('ŞU AN', style: AppText.label(11)),
                    const SizedBox(height: 6),
                    Text('${retroNow.map((p) => kPlanetNames[p]).join(', ')} retro',
                        style: AppText.display(24, color: AppColors.goldSoft, w: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(_retroEndText(), style: AppText.body(13, color: const Color(0xFFCFC9E4))),
                  ]),
                ),
              GlassCard(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Column(children: [
                  for (var i = 0; i < events.length; i++) _row(i),
                ]),
              ),
              const SizedBox(height: 14),
              GlassCard(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                child: SwitchListTile(
                  value: notify,
                  onChanged: _toggle,
                  activeThumbColor: AppColors.gold,
                  title: Text('Önemli olaylardan 1 gün önce haber ver', style: AppText.body(14)),
                  subtitle: Text('Retro, Yeniay, Dolunay ve tutulmalar', style: AppText.body(12, color: AppColors.muted)),
                ),
              ),
            ]),
    );
  }

  String _retroEndText() {
    final ends = <String>[];
    for (final p in retroNow) {
      final e = events.where((x) => x.type == 'direct' && x.planet == p);
      if (e.isNotEmpty) {
        final d = e.first.utc.toLocal();
        ends.add('${kPlanetNames[p]} ${d.day} ${_monthName(d.month)}');
      }
    }
    return ends.isEmpty ? 'Retro dönemi devam ediyor.' : 'Düz harekete geçiş: ${ends.join(', ')}.';
  }

  String _monthName(int m) => const [
        'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran', 'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'
      ][m - 1];

  Widget _row(int i) {
    final e = events[i];
    final d = e.utc.toLocal();
    final expanded = open == i;
    final personal = _personal(e);
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => setState(() => open = expanded ? null : i),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            SizedBox(
              width: 44,
              child: Column(children: [
                Text('${d.day}', style: AppText.display(22, w: FontWeight.w700)),
                Text(_months[d.month - 1], style: AppText.body(10.5, color: AppColors.muted, w: FontWeight.w600)),
              ]),
            ),
            const SizedBox(width: 8),
            Glyph(eventGlyph(e), size: 20, stroke: 8),
            const SizedBox(width: 10),
            Expanded(child: Text(eventTitle(e), style: AppText.body(14))),
            TagChip(eventKind(e)),
          ]),
          if (expanded) ...[
            const SizedBox(height: 10),
            Text(Astro.instance.text(e.key) ?? kTextPending,
                style: AppText.body(14, color: const Color(0xFFCFC9E4), height: 1.5)),
            if (personal != null) ...[
              const SizedBox(height: 6),
              Text(personal, style: AppText.body(13, color: AppColors.gold, w: FontWeight.w600)),
            ],
          ],
        ]),
      ),
    );
  }
}

/// Önemli olaylar için bir gün önce saat 10:00'da bildirim planlar (en fazla 20 olay).
Future<void> scheduleSkyNotifications(List<SkyEvent> events) async {
  final important =
      events.where((e) => e.type != 'ingress' || e.planet == 'sun').take(20).toList();
  final now = DateTime.now();
  final list = <Map<String, Object>>[];
  for (final e in important) {
    final local = e.utc.toLocal();
    final at = DateTime(local.year, local.month, local.day, 10).subtract(const Duration(days: 1));
    if (at.isBefore(now)) continue;
    list.add({
      'id': '${e.type}_${e.planet ?? ''}_${local.year}${local.month}${local.day}',
      'at': at.millisecondsSinceEpoch,
      'title': 'Yarın: ${eventTitle(e)}',
      'body': (Astro.instance.text(e.key) ?? 'Gökyüzü takviminde ayrıntıları gör.').split('. ').first,
    });
  }
  await NativeBridge.scheduleSkyEvents(list);
}
