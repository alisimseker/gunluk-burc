import 'dart:io' show Platform;

import 'package:flutter/material.dart';

import '../premium.dart';
import '../theme.dart';
import '../ui/glyph.dart';

/// Aylık üyelik satın alma ekranı. Satın alma başarılı olursa true ile kapanır.
class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  static Future<bool> open(BuildContext context) async =>
      await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const PaywallScreen())) ?? false;

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  final p = PremiumService.instance;

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

  @override
  Widget build(BuildContext context) {
    final store = Platform.isIOS ? 'App Store' : 'Google Play';
    return Scaffold(
      body: StarfieldBackground(
        child: SafeArea(
          child: Column(children: [
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(onPressed: () => Navigator.of(context).pop(false), icon: const Icon(Icons.close)),
            ),
            Expanded(
              child: ListView(padding: const EdgeInsets.fromLTRB(24, 0, 24, 16), children: [
                Center(
                  child: Container(
                    width: 96,
                    height: 96,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(colors: [AppColors.gold.withValues(alpha: 0.28), Colors.transparent]),
                    ),
                    child: const Glyph('sun', size: 56, color: AppColors.goldSoft, stroke: 5),
                  ),
                ),
                const SizedBox(height: 12),
                Text('Günlük Burç Premium', textAlign: TextAlign.center, style: AppText.display(34)),
                const SizedBox(height: 8),
                Text('Gökyüzünün sana özel haritasını aç.',
                    textAlign: TextAlign.center, style: AppText.body(15, color: AppColors.muted)),
                const SizedBox(height: 28),
                const _Feature(
                    glyph: 'sun',
                    title: 'Doğum haritan',
                    text: 'Doğduğun anın gerçek gezegen konumları, 12 ev ve açılar; her yerleşim için ayrıntılı yorum.'),
                const _Feature(
                    glyph: 'koc',
                    title: 'Yükselen burcun',
                    text: 'Doğum saatin ve yerine göre hesaplanır: ilk izlenimin ve hayata yaklaşımın.'),
                const _Feature(
                    glyph: 'moon',
                    title: 'Ay burcun',
                    text: 'Duygusal doğan, iç ihtiyaçların ve kendini güvende hissetme biçimin.'),
                const _Feature(
                    glyph: 'mercury',
                    title: 'Dün ve yarın',
                    text: 'Kaçırdığın günü oku, yarının yorumunu bir gün önceden gör.'),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: Column(children: [
                if (p.lastError != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(p.lastError!,
                        textAlign: TextAlign.center, style: AppText.body(13, color: const Color(0xFFF2A3A3))),
                  ),
                RichText(
                  text: TextSpan(children: [
                    TextSpan(text: p.priceText, style: AppText.display(32, color: AppColors.goldSoft)),
                    TextSpan(text: '  / ay', style: AppText.body(15, color: AppColors.muted)),
                  ]),
                ),
                const SizedBox(height: 14),
                GoldButton(text: 'Aylık üyeliği başlat', loading: p.busy, onPressed: () => p.buy()),
                const SizedBox(height: 6),
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
                  'Üyelik her ay otomatik yenilenir. İstediğin zaman $store › Abonelikler bölümünden iptal '
                  'edebilirsin; iptal edersen dönem sonuna kadar kullanmaya devam edersin.',
                  textAlign: TextAlign.center,
                  style: AppText.body(11.5, color: AppColors.muted, height: 1.4),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _Feature extends StatelessWidget {
  final String glyph, title, text;
  const _Feature({required this.glyph, required this.title, required this.text});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.line),
            ),
            child: Glyph(glyph, size: 26, stroke: 7),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: AppText.body(16, w: FontWeight.w700)),
              const SizedBox(height: 3),
              Text(text, style: AppText.body(14, color: AppColors.muted, height: 1.45)),
            ]),
          ),
        ]),
      );
}
