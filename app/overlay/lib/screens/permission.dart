import 'dart:io' show Platform;

import 'package:flutter/material.dart';

import '../native_bridge.dart';
import '../theme.dart';
import '../ui/glyph.dart';
import '../zodiac.dart';

class PermissionScreen extends StatelessWidget {
  final Zodiac zodiac;
  const PermissionScreen({super.key, required this.zodiac});

  @override
  Widget build(BuildContext context) {
    final ios = Platform.isIOS;
    final steps = ios
        ? const [
            'Bir sonraki adımda bildirimlere izin ver; her sabah yorumun gelsin.',
            'Kilit ekranına basılı tut › Özelleştir › Kilit Ekranı.',
            'Saatin altındaki alana dokun ve "Burç Atlası" widget\'ını ekle.',
          ]
        : const [
            'Bir sonraki adımda bildirimlere izin ver.',
            'Yorumun kilit ekranında ve bildirim çubuğunda durur, her gün kendiliğinden yenilenir.',
            'Kilit ekranında içerik görünmüyorsa: Ayarlar › Bildirimler › Kilit ekranında "Tüm içeriği göster".',
          ];
    return Scaffold(
      body: StarfieldBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Spacer(),
              Glyph(zodiac.id, size: 72, color: AppColors.gold, stroke: 5.5),
              const SizedBox(height: 20),
              Text('Kilit ekranında\nseni beklesin', style: AppText.display(38)),
              const SizedBox(height: 24),
              for (var i = 0; i < steps.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle, border: Border.all(color: AppColors.gold.withValues(alpha: 0.6))),
                      child: Text('${i + 1}', style: AppText.body(13, color: AppColors.gold, w: FontWeight.w700)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(child: Text(steps[i], style: AppText.body(15.5, height: 1.45))),
                  ]),
                ),
              const Spacer(),
              GoldButton(
                text: 'Devam et',
                onPressed: () async {
                  await NativeBridge.requestNotificationPermission();
                  if (context.mounted) Navigator.of(context).pop();
                },
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
