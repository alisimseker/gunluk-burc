import 'dart:async';

import 'package:flutter/material.dart';

import '../birth.dart';
import '../theme.dart';
import '../ui/glyph.dart';
import '../zodiac.dart';

/// Doğum tarihi, saati ve yeri. Kaydedilince BirthData ile kapanır.
class BirthFormScreen extends StatefulWidget {
  final BirthData? initial;
  const BirthFormScreen({super.key, this.initial});

  static Future<BirthData?> open(BuildContext context, {BirthData? initial}) =>
      Navigator.of(context).push<BirthData>(MaterialPageRoute(builder: (_) => BirthFormScreen(initial: initial)));

  @override
  State<BirthFormScreen> createState() => _BirthFormScreenState();
}

class _BirthFormScreenState extends State<BirthFormScreen> {
  final name = TextEditingController();
  DateTime? date;
  TimeOfDay? time;
  bool timeUnknown = false;
  Place? place;

  @override
  void initState() {
    super.initState();
    final b = widget.initial;
    if (b != null) {
      name.text = b.name;
      date = b.date;
      time = b.timeKnown ? TimeOfDay(hour: b.hour!, minute: b.minute!) : null;
      timeUnknown = !b.timeKnown;
      place = b.place;
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: date ?? DateTime(now.year - 25, 6, 15),
      firstDate: DateTime(1920),
      lastDate: now,
      helpText: 'Doğum tarihin',
      initialDatePickerMode: DatePickerMode.year,
    );
    if (d != null) setState(() => date = d);
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(
      context: context,
      initialTime: time ?? const TimeOfDay(hour: 12, minute: 0),
      helpText: 'Doğum saatin',
      initialEntryMode: TimePickerEntryMode.input,
      builder: (ctx, child) => MediaQuery(data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true), child: child!),
    );
    if (t != null) {
      setState(() {
        time = t;
        timeUnknown = false;
      });
    }
  }

  Future<void> _pickPlace() async {
    final p = await showModalBottomSheet<Place>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bg2,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => const _PlaceSearch(),
    );
    if (p != null) setState(() => place = p);
  }

  bool get valid => date != null && place != null && (timeUnknown || time != null);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Doğum bilgilerin')),
      body: StarfieldBackground(
        child: SafeArea(
          top: false,
          child: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 24), children: [
            Text(
              'Haritan doğduğun anın gerçek gökyüzüne göre hesaplanır. Bilgilerin yalnızca bu telefonda saklanır.',
              style: AppText.body(14, color: AppColors.muted),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: name,
              textCapitalization: TextCapitalization.words,
              style: AppText.body(16),
              decoration: const InputDecoration(labelText: 'Adın (isteğe bağlı)'),
            ),
            const SizedBox(height: 14),
            _Field(
              icon: Icons.calendar_month_outlined,
              label: 'Doğum tarihi',
              value: date == null ? null : trDate(date!),
              onTap: _pickDate,
            ),
            const SizedBox(height: 14),
            _Field(
              icon: Icons.schedule,
              label: 'Doğum saati',
              value: timeUnknown
                  ? 'Bilmiyorum'
                  : (time == null
                      ? null
                      : '${time!.hour.toString().padLeft(2, '0')}:${time!.minute.toString().padLeft(2, '0')}'),
              onTap: _pickTime,
            ),
            CheckboxListTile(
              value: timeUnknown,
              onChanged: (v) => setState(() {
                timeUnknown = v ?? false;
                if (timeUnknown) time = null;
              }),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              activeColor: AppColors.gold,
              title: Text('Doğum saatimi bilmiyorum', style: AppText.body(14)),
              subtitle: Text('Saat olmadan yükselen burç ve evler hesaplanamaz.',
                  style: AppText.body(12, color: AppColors.muted)),
            ),
            const SizedBox(height: 4),
            _Field(icon: Icons.place_outlined, label: 'Doğum yeri', value: place?.label, onTap: _pickPlace),
            const SizedBox(height: 28),
            GoldButton(
              text: 'Haritamı hesapla',
              onPressed: !valid
                  ? null
                  : () {
                      final b = BirthData(name.text.trim(), date!, timeUnknown ? null : time!.hour,
                          timeUnknown ? null : time!.minute, place!);
                      Navigator.of(context).pop(b);
                    },
            ),
          ]),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final VoidCallback onTap;
  const _Field({required this.icon, required this.label, required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) => GlassCard(
        onTap: onTap,
        radius: 14,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          Icon(icon, color: AppColors.gold, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: AppText.body(12, color: AppColors.muted)),
              const SizedBox(height: 2),
              Text(value ?? 'Seç', style: AppText.body(16, color: value == null ? AppColors.muted : AppColors.text)),
            ]),
          ),
          const Icon(Icons.chevron_right, color: AppColors.muted),
        ]),
      );
}

class _PlaceSearch extends StatefulWidget {
  const _PlaceSearch();
  @override
  State<_PlaceSearch> createState() => _PlaceSearchState();
}

class _PlaceSearchState extends State<_PlaceSearch> {
  List<Place> results = [];
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _search('');
  }

  void _search(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 150), () async {
      final r = await Astro.instance.searchPlaces(q);
      if (mounted) setState(() => results = r);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.8,
        child: Column(children: [
          const SizedBox(height: 10),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.line, borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              autofocus: true,
              onChanged: _search,
              style: AppText.body(16),
              decoration: const InputDecoration(
                  hintText: 'Şehir veya ilçe ara (ör. Kadıköy, İzmir, Berlin)', prefixIcon: Icon(Icons.search)),
            ),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: results.length,
              separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.line),
              itemBuilder: (_, i) {
                final p = results[i];
                return ListTile(
                  leading: const Glyph('sun', size: 18, stroke: 8, color: AppColors.muted),
                  title: Text(p.name, style: AppText.body(15)),
                  subtitle: Text(p.country, style: AppText.body(12, color: AppColors.muted)),
                  onTap: () => Navigator.of(context).pop(p),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}
