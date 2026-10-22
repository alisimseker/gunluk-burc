import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../ads.dart';
import '../theme.dart';
import 'paywall.dart';

/// Markanın tam ekran reklamı: "Reklam" etiketi, geçme sayacı, görsel ya da video, buton.
class AdScreen extends StatefulWidget {
  final Campaign campaign;
  const AdScreen({super.key, required this.campaign});
  @override
  State<AdScreen> createState() => _AdScreenState();
}

class _AdScreenState extends State<AdScreen> {
  late int left = widget.campaign.skipAfter;
  Timer? _timer;
  VideoPlayerController? _video;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => left = left > 0 ? left - 1 : 0);
      if (left == 0) t.cancel();
    });
    final v = widget.campaign.video;
    if (v != null && v.isNotEmpty) {
      _video = VideoPlayerController.networkUrl(Uri.parse(v))
        ..setLooping(true)
        ..initialize().then((_) {
          if (!mounted) return;
          setState(() {});
          _video!.play();
        });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _video?.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    final u = Uri.tryParse(widget.campaign.url);
    if (u == null) return;
    await launchUrl(u, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.campaign;
    final canSkip = left == 0;
    Widget media;
    if (_video != null && _video!.value.isInitialized) {
      media = FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: _video!.value.size.width,
          height: _video!.value.size.height,
          child: VideoPlayer(_video!),
        ),
      );
    } else if (c.image != null && c.image!.isNotEmpty) {
      media = Image.network(c.image!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox());
    } else {
      media = const ColoredBox(color: Color(0xFF2A2450));
    }

    return PopScope(
      canPop: canSkip,
      child: Scaffold(
        backgroundColor: const Color(0xFF0B0915),
        body: Column(children: [
          Expanded(
            child: Stack(fit: StackFit.expand, children: [
              GestureDetector(onTap: _open, child: media),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration:
                          BoxDecoration(color: AppColors.text, borderRadius: BorderRadius.circular(6)),
                      child: Text('REKLAM', style: AppText.body(11, color: AppColors.bg, w: FontWeight.w800, spacing: 1.2)),
                    ),
                    const Spacer(),
                    canSkip
                        ? FilledButton(
                            style: FilledButton.styleFrom(
                                backgroundColor: AppColors.text, foregroundColor: AppColors.bg, minimumSize: const Size(88, 44)),
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Geç ›'),
                          )
                        : Container(
                            height: 44,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.45), borderRadius: BorderRadius.circular(22)),
                            child: Text('$left sn sonra geçebilirsin', style: AppText.body(13.5, w: FontWeight.w600)),
                          ),
                  ]),
                ),
              ),
            ]),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
              child: Column(children: [
                Row(children: [
                  if (c.logo != null && c.logo!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(c.logo!, width: 44, height: 44, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const SizedBox(width: 44, height: 44)),
                      ),
                    ),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(c.brand, style: AppText.body(15, w: FontWeight.w700)),
                      if (c.title.isNotEmpty) Text(c.title, style: AppText.body(13, color: AppColors.muted)),
                    ]),
                  ),
                ]),
                const SizedBox(height: 12),
                GoldButton(text: c.cta, onPressed: _open),
                TextButton(
                  onPressed: () async {
                    Navigator.of(context).pop();
                    await PaywallScreen.open(context);
                  },
                  child: Text('Premium ile reklamsız kullan', style: AppText.body(12.5, color: AppColors.muted)),
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}
