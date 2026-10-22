import 'package:flutter/material.dart';

import '../birth.dart';
import '../theme.dart';
import '../ui/glyph.dart';
import 'birth_form.dart';

/// Kullanıcının doğum haritasını döndürür; doğum bilgisi yoksa formu açar (vazgeçerse null).
Future<PersonalChart?> ensureMyChart(BuildContext context, {bool edit = false}) async {
  var b = await Astro.instance.loadBirth();
  if (b == null || edit) {
    if (!context.mounted) return null;
    final nb = await BirthFormScreen.open(context, initial: b);
    if (nb == null) return b == null ? null : PersonalChart.compute(b);
    await Astro.instance.saveBirth(nb);
    b = nb;
  }
  return PersonalChart.compute(b);
}

/// Ortak ekran iskeleti
class FeatureScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  final List<Widget>? actions;
  const FeatureScaffold({super.key, required this.title, required this.body, this.actions});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(title), actions: actions),
        body: StarfieldBackground(child: SafeArea(top: false, child: body)),
      );
}

class SectionLabel extends StatelessWidget {
  final String text;
  const SectionLabel(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 10),
        child: Text(text.toUpperCase(), style: AppText.label(11.5)),
      );
}

class TagChip extends StatelessWidget {
  final String text;
  const TagChip(this.text, {super.key});

  static Color colorFor(String t) => switch (t) {
        'Aşk' => const Color(0xFFF0A0B8),
        'Fırsat' => const Color(0xFF8CC084),
        'Dikkat' => const Color(0xFFF08A5D),
        'İş' => const Color(0xFF7FB7F0),
        'Retro' || 'Retro biter' => const Color(0xFFF08A5D),
        'Yeniay' || 'Dolunay' || 'Tutulma' => const Color(0xFFB8C7F5),
        _ => const Color(0xFFE8C77B),
      };

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: colorFor(text), borderRadius: BorderRadius.circular(10)),
        child: Text(text, style: AppText.body(11, color: AppColors.bg, w: FontWeight.w700, height: 1.2)),
      );
}

const String kTextPending = 'Bu yorum hazırlanıyor; kısa süre içinde burada olacak.';
