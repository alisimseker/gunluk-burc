import 'package:flutter/material.dart';

import '../theme.dart';
import '../ui/glyph.dart';
import '../zodiac.dart';

class SignPicker extends StatefulWidget {
  final Future<void> Function(String) onPicked;
  final bool firstRun;
  final String? current;
  const SignPicker({super.key, required this.onPicked, required this.firstRun, this.current});

  @override
  State<SignPicker> createState() => _SignPickerState();
}

class _SignPickerState extends State<SignPicker> {
  String? selected;

  @override
  void initState() {
    super.initState();
    selected = widget.current;
  }

  Future<void> _findByDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 25, now.month, now.day),
      firstDate: DateTime(1920),
      lastDate: now,
      helpText: 'Doğum tarihin',
      initialEntryMode: DatePickerEntryMode.calendarOnly,
    );
    if (d == null) return;
    setState(() => selected = kZodiacs[sunSignByDate(d)].id);
  }

  @override
  Widget build(BuildContext context) {
    final z = selected == null ? null : zodiacById(selected!);
    return Scaffold(
      body: StarfieldBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Row(children: [
                  if (!widget.firstRun)
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                    ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _findByDate,
                    icon: const Icon(Icons.cake_outlined, size: 18, color: AppColors.gold),
                    label: Text('Doğum tarihimden bul', style: AppText.body(13, color: AppColors.gold, w: FontWeight.w600)),
                  ),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 4),
                child: Text(widget.firstRun ? 'Burcunu seç' : 'Burcunu değiştir', style: AppText.display(40)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                child: Text('Her sabah yorumun ve günün cümlesi kilit ekranında seni bekleyecek.',
                    style: AppText.body(15, color: AppColors.muted)),
              ),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  itemCount: kZodiacs.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.74),
                  itemBuilder: (_, i) => _SignTile(
                    z: kZodiacs[i],
                    selected: kZodiacs[i].id == selected,
                    onTap: () => setState(() => selected = kZodiacs[i].id),
                  ),
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                decoration: BoxDecoration(
                  color: AppColors.bg.withValues(alpha: 0.92),
                  border: const Border(top: BorderSide(color: AppColors.line)),
                ),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  if (z != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text('${z.element} elementi · ${z.quality} · Yönetici: ${z.ruler}',
                          style: AppText.body(13, color: AppColors.muted)),
                    ),
                  GoldButton(
                    text: z == null ? 'Bir burç seç' : '${z.name} ile devam et',
                    onPressed: z == null ? null : () => widget.onPicked(z.id),
                  ),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SignTile extends StatelessWidget {
  final Zodiac z;
  final bool selected;
  final VoidCallback onTap;
  const _SignTile({required this.z, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final el = AppColors.element(z.element);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: selected
                ? [const Color(0xFF3A2C6E), const Color(0xFF1E1838)]
                : [const Color(0xFF1F1938), const Color(0xFF15112A)],
          ),
          border: Border.all(color: selected ? AppColors.gold : AppColors.line, width: selected ? 1.6 : 1),
          boxShadow: selected
              ? [BoxShadow(color: AppColors.gold.withValues(alpha: 0.22), blurRadius: 18, spreadRadius: 1)]
              : null,
        ),
        child: Stack(children: [
          Positioned(
            top: 10,
            right: 10,
            child: Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: el, shape: BoxShape.circle),
            ),
          ),
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(6, 10, 6, 10),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: SizedBox(
                  width: 104,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      width: 58,
                      height: 58,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(colors: [
                          AppColors.gold.withValues(alpha: selected ? 0.22 : 0.10),
                          Colors.transparent,
                        ]),
                      ),
                      child: Glyph(z.id, size: 40, color: selected ? AppColors.goldSoft : AppColors.gold, stroke: 6.5),
                    ),
                    const SizedBox(height: 8),
                    Text(z.name, maxLines: 1, style: AppText.display(21, w: FontWeight.w700)),
                    const SizedBox(height: 3),
                    Text(z.range.replaceAll(' – ', '\n'),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        style: AppText.body(10.5, color: AppColors.muted, height: 1.3)),
                  ]),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
