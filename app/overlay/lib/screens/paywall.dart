import 'dart:io' show Platform;

import 'package:flutter/material.dart';

import '../config.dart';
import '../premium.dart';
import '../theme.dart';
import '../ui/glyph.dart';

/// Premium satın alma ekranı (yıllık / aylık). Satın alma başarılı olursa true ile kapanır.
class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  static Future<bool> open(BuildContext context) async =>
      await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const PaywallScreen())) ?? false;

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  final p = PremiumService.instance;
  String plan = kYearlyProductId;

  @override
  void initState() {
    super.initState();
    p.addListener(_changed);
  }

  @override
  void dispose() {
    p.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (!mounted) return;
    if (p.isPremium) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {});
  }

  static const _features = [
    ('Bugün sana özel', 'Günün gökyüzü kendi doğum haritanla karşılaştırılır'),
    ('Burç uyumu', 'İki doğum haritası: aşk, iletişim, uzun vade'),
    ('Doğum haritan', 'Gerçek gezegen konumları, 12 ev, açılar ve yorumlar'),
    ('Yükselen ve Ay burcun', 'Doğum saatin ve yerine göre hesaplanır'),
    ('Gökyüzü takvimi', 'Retro, Yeniay, Dolunay ve tutulmalar; önceden bildirim'),
    ('Yıllık öngörü', 'Doğum gününden doğum gününe senin yılın'),
    ('Dün ve yarın', 'Kaçırdığın günü oku, yarını önceden gör'),
    ('Reklamsız', 'Premium üyelerine hiç reklam gösterilmez'),
  ];

  @override
  Widget build(BuildContext context) {
    final store = Platform.isIOS ? 'App Store' : 'Google Play';
    final yearly = plan == kYearlyProductId;
    return Scaffold(
      body: StarfieldBackground(
        child: SafeArea(
          child: Column(children: [
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                  tooltip: 'Kapat', onPressed: () => Navigator.of(context).pop(false), icon: const Icon(Icons.close)),
            ),
            Expanded(
              child: ListView(padding: const EdgeInsets.fromLTRB(22, 0, 22, 12), children: [
                const Center(child: Glyph('sun', size: 54, color: AppColors.goldSoft, stroke: 5)),
                const SizedBox(height: 10),
                Text('Burç Atlası Premium', textAlign: TextAlign.center, style: AppText.display(32)),
                const SizedBox(height: 4),
                Text('Gökyüzünün sana özel haritası, reklamsız.',
                    textAlign: TextAlign.center, style: AppText.body(14, color: AppColors.muted)),
                const SizedBox(height: 18),
                for (final f in _features)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 9),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Container(
                        width: 22,
                        height: 22,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: const Color(0xFF2A2150), borderRadius: BorderRadius.circular(11)),
                        child: const Icon(Icons.check, size: 14, color: AppColors.gold),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(f.$1, style: AppText.body(14.5, w: FontWeight.w700, height: 1.3)),
                          Text(f.$2, style: AppText.body(12.5, color: AppColors.muted, height: 1.35)),
                        ]),
                      ),
                    ]),
                  ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
              child: Column(children: [
                if (p.lastError != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(p.lastError!,
                        textAlign: TextAlign.center, style: AppText.body(12.5, color: const Color(0xFFF2A3A3))),
                  ),
                _PlanCard(
                  selected: yearly,
                  badge: 'EN AVANTAJLI · %30 İNDİRİM',
                  title: 'YILLIK ÜYELİK',
                  subtitle: 'Ayda yalnızca ₺208',
                  price: p.price(kYearlyProductId),
                  period: '/ yıl',
                  onTap: () => setState(() => plan = kYearlyProductId),
                ),
                const SizedBox(height: 10),
                _PlanCard(
                  selected: !yearly,
                  title: 'AYLIK ÜYELİK',
                  subtitle: 'İstediğin zaman iptal',
                  price: p.price(kMonthlyProductId),
                  period: '/ ay',
                  onTap: () => setState(() => plan = kMonthlyProductId),
                ),
                const SizedBox(height: 12),
                GoldButton(
                  text: yearly ? 'Yıllık üyeliği başlat' : 'Aylık üyeliği başlat',
                  loading: p.busy,
                  onPressed: () => p.buy(plan),
                ),
                TextButton(
                  onPressed: () async {
                    await p.refresh();
                    if (!context.mounted) return;
                    if (!p.isPremium) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(const SnackBar(content: Text('Bu hesapta aktif bir üyelik bulunamadı.')));
                    }
                  },
                  child: Text('Satın alımları geri yükle', style: AppText.body(13, color: AppColors.muted)),
                ),
                Text(
                  'Seçtiğin dönem sonunda otomatik yenilenir. $store › Abonelikler bölümünden istediğin zaman iptal '
                  'edebilirsin; dönem sonuna kadar kullanmaya devam edersin.',
                  textAlign: TextAlign.center,
                  style: AppText.body(11, color: AppColors.muted, height: 1.4),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final bool selected;
  final String? badge;
  final String title, subtitle, price, period;
  final VoidCallback onTap;
  const _PlanCard(
      {required this.selected,
      this.badge,
      required this.title,
      required this.subtitle,
      required this.price,
      required this.period,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        child: Stack(clipBehavior: Clip.none, children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: selected ? AppColors.gold : AppColors.line, width: selected ? 1.6 : 1),
            ),
            child: Row(children: [
              Icon(selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                  color: selected ? AppColors.gold : AppColors.muted, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: AppText.label(11.5)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: AppText.body(12.5, color: AppColors.muted)),
                ]),
              ),
              Text(price, style: AppText.display(28, color: AppColors.goldSoft, w: FontWeight.w700)),
              const SizedBox(width: 4),
              Text(period, style: AppText.body(12.5, color: AppColors.muted)),
            ]),
          ),
          if (badge != null)
            Positioned(
              top: -9,
              left: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(8)),
                child: Text(badge!,
                    style: AppText.body(9.5, color: AppColors.bg, w: FontWeight.w800, spacing: 0.8, height: 1.2)),
              ),
            ),
        ]),
      ),
    );
  }
}
