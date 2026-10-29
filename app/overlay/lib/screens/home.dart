import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../ads.dart';
import '../config.dart';
import '../native_bridge.dart';
import '../premium.dart';
import '../repository.dart';
import '../theme.dart';
import '../ui/banner_ad.dart';
import '../ui/glyph.dart';
import '../zodiac.dart';
import 'birth_form.dart';
import 'calendar.dart';
import 'compat.dart';
import 'natal.dart';
import 'personal_today.dart';
import 'yearly.dart';
import 'paywall.dart';
import '../birth.dart';

class HomeScreen extends StatefulWidget {
  final String sign;
  final Repository repo;
  final VoidCallback onChangeSign;
  const HomeScreen({super.key, required this.sign, required this.repo, required this.onChangeSign});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final premium = PremiumService.instance;
  Map<String, DayReading> days = {};
  bool offline = false, loading = true, notifOk = true, privacyOpt = false;
  int offset = 0;
  Timer? _adTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    premium.addListener(_onPremium);
    _load();
    _scheduleAd();
    AdService.instance.privacyOptionsRequired().then((v) {
      if (mounted) setState(() => privacyOpt = v);
    });
  }

  /// Ücretsiz kullanıcıya, yorumu okuması için bir süre geçtikten sonra (günde en fazla kAdsPerDay) reklam
  void _scheduleAd() {
    _adTimer?.cancel();
    if (premium.isPremium) return;
    _adTimer = Timer(kAdDelay, () {
      if (!mounted || premium.isPremium) return;
      if (ModalRoute.of(context)?.isCurrent != true) return; // başka ekrandaysa araya girme
      AdService.instance.maybeShow(context, sign: widget.sign);
    });
  }

  @override
  void dispose() {
    _adTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    premium.removeListener(_onPremium);
    super.dispose();
  }

  void _onPremium() {
    if (!mounted) return;
    setState(() {
      if (!premium.isPremium) offset = 0;
    });
    if (premium.isPremium) _adTimer?.cancel();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _load();
      NativeBridge.sync();
      premium.refresh();
      _scheduleAd();
    } else if (state == AppLifecycleState.paused) {
      _adTimer?.cancel();
    }
  }

  @override
  void didUpdateWidget(covariant HomeScreen old) {
    super.didUpdateWidget(old);
    if (old.sign != widget.sign) _load();
  }

  Future<void> _load() async {
    final r = await widget.repo.load(widget.sign);
    final ok = await NativeBridge.notificationsEnabled();
    if (!mounted) return;
    setState(() {
      days = r.days;
      offline = r.offline;
      loading = false;
      notifOk = ok;
    });
  }

  Future<void> _openPremium(Widget Function() screen) async {
    if (!premium.isPremium) {
      final ok = await PaywallScreen.open(context);
      if (!ok || !mounted) return;
    }
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen()));
  }

  Future<void> _selectDay(int o) async {
    if (o != 0 && !premium.isPremium) {
      final ok = await PaywallScreen.open(context);
      if (!ok) return;
    }
    setState(() => offset = o);
  }

  Future<void> _enterCode() async {
    final ctl = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (dctx) => AlertDialog(
        backgroundColor: AppColors.bg2,
        title: const Text('Erişim kodu'),
        content: TextField(
          controller: ctl,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(hintText: 'ATLAS-XXXX-XXXX'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dctx), child: const Text('Vazgeç')),
          TextButton(onPressed: () => Navigator.pop(dctx, ctl.text), child: const Text('Onayla')),
        ],
      ),
    );
    if (code == null || code.trim().isEmpty || !mounted) return;
    final ok = await premium.redeemCode(code);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? 'Premium özellikler açıldı.' : 'Kod geçersiz.')));
  }

  void _settings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bg2,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(
              leading: const Icon(Icons.swap_horiz, color: AppColors.gold),
              title: const Text('Burcunu değiştir'),
              onTap: () {
                Navigator.pop(ctx);
                widget.onChangeSign();
              },
            ),
            ListTile(
              leading: const Icon(Icons.cake_outlined, color: AppColors.gold),
              title: const Text('Doğum bilgilerim'),
              onTap: () async {
                Navigator.pop(ctx);
                final b = await Astro.instance.loadBirth();
                if (!mounted) return;
                final nb = await BirthFormScreen.open(context, initial: b);
                if (nb != null) await Astro.instance.saveBirth(nb);
              },
            ),
            ListTile(
              leading: Icon(premium.isPremium ? Icons.verified : Icons.workspace_premium_outlined, color: AppColors.gold),
              title: Text(premium.isPremium ? 'Premium üyeliğin aktif' : "Premium'a geç"),
              subtitle: Text(premium.isPremium
                  ? 'İptal: ${Theme.of(ctx).platform == TargetPlatform.iOS ? 'App Store' : 'Google Play'} › Abonelikler'
                  : 'Yıllık ${premium.price(kYearlyProductId)} veya aylık ${premium.price(kMonthlyProductId)}'),
              onTap: () async {
                Navigator.pop(ctx);
                if (!premium.isPremium) await PaywallScreen.open(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.notifications_outlined, color: AppColors.gold),
              title: const Text('Bildirim ayarları'),
              onTap: () {
                Navigator.pop(ctx);
                NativeBridge.openNotificationSettings();
              },
            ),
            if (privacyOpt && !premium.isPremium)
              ListTile(
                leading: const Icon(Icons.privacy_tip_outlined, color: AppColors.gold),
                title: const Text('Reklam gizlilik seçenekleri'),
                onTap: () {
                  Navigator.pop(ctx);
                  AdService.instance.showPrivacyOptions();
                },
              ),
            ListTile(
              leading: const Icon(Icons.policy_outlined, color: AppColors.gold),
              title: const Text('Gizlilik politikası'),
              onTap: () {
                Navigator.pop(ctx);
                launchUrl(Uri.parse('$kContentBaseUrl/'), mode: LaunchMode.externalApplication);
              },
            ),
            if (!premium.isPremium)
              ListTile(
                leading: const Icon(Icons.key_outlined, color: AppColors.muted),
                title: const Text('Erişim kodu gir'),
                onTap: () {
                  Navigator.pop(ctx);
                  _enterCode();
                },
              ),
            if (kDebugMode)
              SwitchListTile(
                secondary: const Icon(Icons.bug_report_outlined, color: AppColors.muted),
                title: const Text('Test: Premium açık'),
                subtitle: const Text('Yalnızca deneme sürümünde görünür'),
                value: premium.isPremium,
                onChanged: (v) {
                  premium.setDebugOverride(v);
                  Navigator.pop(ctx);
                },
              ),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final z = zodiacById(widget.sign);
    final now = DateTime.now();
    final day = DateTime(now.year, now.month, now.day).add(Duration(days: offset));
    final reading = days[isoDate(day)];
    final isPremium = premium.isPremium;

    return Scaffold(
      bottomNavigationBar: isPremium ? null : const BottomBannerAd(),
      body: StarfieldBackground(
        child: SafeArea(
          bottom: false,
          child: RefreshIndicator(
            color: AppColors.gold,
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 36),
              children: [
                // ---------------------------------------------------- üst
                Row(children: [
                  GestureDetector(
                    onTap: widget.onChangeSign,
                    child: Container(
                      width: 58,
                      height: 58,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.gold.withValues(alpha: 0.45)),
                        gradient: RadialGradient(colors: [AppColors.gold.withValues(alpha: 0.16), Colors.transparent]),
                      ),
                      child: Glyph(z.id, size: 32, stroke: 6.5),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(z.name, style: AppText.display(32, w: FontWeight.w700)),
                      Text(trLongDate(day), style: AppText.body(13, color: AppColors.muted)),
                    ]),
                  ),
                  if (isPremium)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      margin: const EdgeInsets.only(right: 4),
                      decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.gold.withValues(alpha: 0.6))),
                      child: Text('PREMIUM', style: AppText.label(10)),
                    ),
                  IconButton(onPressed: _settings, icon: const Icon(Icons.tune_rounded)),
                ]),
                const SizedBox(height: 18),
                _DayTabs(offset: offset, locked: !isPremium, onSelect: _selectDay),
                const SizedBox(height: 18),
                if (!notifOk)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: GlassCard(
                      onTap: () async {
                        await NativeBridge.requestNotificationPermission();
                        await NativeBridge.openNotificationSettings();
                      },
                      padding: const EdgeInsets.all(14),
                      child: Row(children: [
                        const Icon(Icons.notifications_off_outlined, color: AppColors.gold),
                        const SizedBox(width: 12),
                        Expanded(
                            child: Text('Kilit ekranında görmek için bildirimleri aç.',
                                style: AppText.body(14))),
                        const Icon(Icons.chevron_right, color: AppColors.muted),
                      ]),
                    ),
                  ),
                if (offline)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text('İnternet yok, son indirilen yorumlar gösteriliyor.',
                        style: AppText.body(13, color: AppColors.muted)),
                  ),
                if (loading)
                  const Padding(
                      padding: EdgeInsets.all(48), child: Center(child: CircularProgressIndicator(color: AppColors.gold)))
                else if (reading == null)
                  GlassCard(
                    child: Text('Bu gün için yorum henüz hazır değil. Aşağı çekerek yenileyebilirsin.',
                        style: AppText.body(15, color: AppColors.muted)),
                  )
                else ...[
                  _MotivationCard(text: reading.motivation),
                  const SizedBox(height: 14),
                  _ReadingCard(r: reading),
                ],
                const SizedBox(height: 28),
                Row(children: [
                  Text('Sana özel', style: AppText.display(28)),
                  const Spacer(),
                  if (!isPremium) const Icon(Icons.lock_outline, size: 16, color: AppColors.muted),
                  if (!isPremium) const SizedBox(width: 4),
                  if (!isPremium) Text('Premium', style: AppText.body(13, color: AppColors.muted)),
                ]),
                const SizedBox(height: 12),
                _HighlightTile(
                  locked: !isPremium,
                  onTap: () => _openPremium(() => const PersonalTodayScreen()),
                ),
                const SizedBox(height: 10),
                IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Expanded(
                    child: _FeatureTile(
                      glyph: 'venus',
                      title: 'Burç uyumu',
                      text: 'İki harita, gerçek açılar',
                      compact: true,
                      locked: !isPremium,
                      onTap: () => _openPremium(() => const CompatScreen()),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _FeatureTile(
                      glyph: 'moon',
                      title: 'Gökyüzü takvimi',
                      text: 'Retro, Dolunay, tutulma',
                      compact: true,
                      locked: !isPremium,
                      onTap: () => _openPremium(() => const CalendarScreen()),
                    ),
                  ),
                ])),
                const SizedBox(height: 10),
                _FeatureTile(
                  glyph: 'jupiter',
                  title: 'Yıllık öngörü',
                  text: 'Doğum gününden doğum gününe senin yılın',
                  locked: !isPremium,
                  onTap: () => _openPremium(() => const YearlyScreen()),
                ),
                const SizedBox(height: 10),
                _FeatureTile(
                  glyph: 'sun',
                  title: 'Doğum haritan',
                  text: 'Doğduğun anın gerçek gökyüzü, 12 ev ve gezegen yorumları',
                  locked: !isPremium,
                  onTap: () => _openPremium(() => const NatalScreen(view: NatalView.chart)),
                ),
                const SizedBox(height: 10),
                IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Expanded(
                    child: _FeatureTile(
                      glyph: 'koc',
                      title: 'Yükselen',
                      text: 'İlk izlenimin',
                      compact: true,
                      locked: !isPremium,
                      onTap: () => _openPremium(() => const NatalScreen(view: NatalView.rising)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _FeatureTile(
                      glyph: 'moon',
                      title: 'Ay burcu',
                      text: 'Duygusal doğan',
                      compact: true,
                      locked: !isPremium,
                      onTap: () => _openPremium(() => const NatalScreen(view: NatalView.moon)),
                    ),
                  ),
                ])),
                if (!isPremium) ...[
                  const SizedBox(height: 18),
                  GlassCard(
                    onTap: () => PaywallScreen.open(context),
                    gradient: const LinearGradient(
                        colors: [Color(0xFF3B2C6E), Color(0xFF241B45)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight),
                    child: Row(children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Premium ile hepsi açık', style: AppText.display(22, w: FontWeight.w700)),
                          const SizedBox(height: 4),
                          Text('Reklamsız · yıllık ${premium.price(kYearlyProductId)} veya aylık ${premium.price(kMonthlyProductId)}',
                              style: AppText.body(13, color: AppColors.muted)),
                        ]),
                      ),
                      const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.gold),
                    ]),
                  ),
                ],
                if (reading != null) ...[
                  const SizedBox(height: 18),
                  _SkyCard(r: reading),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DayTabs extends StatelessWidget {
  final int offset;
  final bool locked;
  final ValueChanged<int> onSelect;
  const _DayTabs({required this.offset, required this.locked, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    Widget tab(int o, String label) {
      final sel = offset == o;
      return Expanded(
        child: GestureDetector(
          onTap: () => onSelect(o),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: sel ? const LinearGradient(colors: [Color(0xFFF3DFAE), Color(0xFFD9B25F)]) : null,
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              if (locked && o != 0) ...[
                Icon(Icons.lock_outline, size: 14, color: sel ? AppColors.bg : AppColors.muted),
                const SizedBox(width: 5),
              ],
              Text(label,
                  style: AppText.body(14, color: sel ? AppColors.bg : AppColors.muted, w: FontWeight.w700)),
            ]),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(children: [tab(-1, 'Dün'), tab(0, 'Bugün'), tab(1, 'Yarın')]),
    );
  }
}

class _MotivationCard extends StatelessWidget {
  final String text;
  const _MotivationCard({required this.text});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
          gradient: const LinearGradient(
              colors: [Color(0xFF4A3788), Color(0xFF2A2052), Color(0xFF1C1633)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight),
          boxShadow: [BoxShadow(color: AppColors.violet.withValues(alpha: 0.18), blurRadius: 30, offset: const Offset(0, 10))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.auto_awesome, size: 16, color: AppColors.gold),
            const SizedBox(width: 8),
            Text('GÜNÜN CÜMLESİ', style: AppText.label(11.5)),
          ]),
          const SizedBox(height: 12),
          Text('“$text”', style: AppText.display(30, color: AppColors.goldSoft)),
        ]),
      );
}

class _ReadingCard extends StatelessWidget {
  final DayReading r;
  const _ReadingCard({required this.r});
  @override
  Widget build(BuildContext context) => GlassCard(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('GÜNLÜK YORUM', style: AppText.label(11.5)),
            const Spacer(),
            if (r.focus.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
                child: Text(r.focus, style: AppText.body(12, color: AppColors.gold, w: FontWeight.w600)),
              ),
          ]),
          const SizedBox(height: 14),
          Text(r.text, style: AppText.body(16.5, height: 1.65)),
        ]),
      );
}

class _FeatureTile extends StatelessWidget {
  final String glyph, title, text;
  final bool locked, compact;
  final VoidCallback onTap;
  const _FeatureTile(
      {required this.glyph,
      required this.title,
      required this.text,
      required this.locked,
      required this.onTap,
      this.compact = false});

  @override
  Widget build(BuildContext context) {
    final badge = Container(
      width: compact ? 40 : 52,
      height: compact ? 40 : 52,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [AppColors.gold.withValues(alpha: 0.18), Colors.transparent]),
        border: Border.all(color: AppColors.line),
      ),
      child: Glyph(glyph, size: compact ? 22 : 30, stroke: 7),
    );
    final arrow =
        Icon(locked ? Icons.lock_outline : Icons.chevron_right, size: 18, color: locked ? AppColors.muted : AppColors.gold);
    const grad = LinearGradient(
        colors: [Color(0xFF221B3F), Color(0xFF17122B)], begin: Alignment.topLeft, end: Alignment.bottomRight);
    if (compact) {
      // Küçük karo: simge üstte, başlık ve açıklama altta (dar alanda satır bölünmesin)
      return GlassCard(
        onTap: onTap,
        padding: const EdgeInsets.fromLTRB(16, 14, 14, 16),
        gradient: grad,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [badge, const Spacer(), arrow]),
          const SizedBox(height: 12),
          Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.body(15.5, w: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppText.body(12.5, color: AppColors.muted, height: 1.35)),
        ]),
      );
    }
    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.all(18),
      gradient: grad,
      child: Row(children: [
        badge,
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: AppText.body(17, w: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(text,
                maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.body(13, color: AppColors.muted, height: 1.35)),
          ]),
        ),
        arrow,
      ]),
    );
  }
}

/// "Bugün sana özel": günün gökyüzünün kendi haritanla buluştuğu yer (öne çıkan kart)
class _HighlightTile extends StatelessWidget {
  final bool locked;
  final VoidCallback onTap;
  const _HighlightTile({required this.locked, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 18, 18, 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.45)),
            gradient: const LinearGradient(
                colors: [Color(0xFF3A2C6C), Color(0xFF231B44)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          ),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('BUGÜN SANA ÖZEL', style: AppText.label(11)),
                const SizedBox(height: 8),
                Text('Gökyüzü bugün senin haritana ne söylüyor?',
                    style: AppText.display(22, color: AppColors.goldSoft, w: FontWeight.w700)),
                const SizedBox(height: 6),
                Text('Günün gezegenleri doğum haritanla gerçek açılarla karşılaştırılır.',
                    style: AppText.body(12.5, color: AppColors.muted, height: 1.35)),
              ]),
            ),
            const SizedBox(width: 12),
            Icon(locked ? Icons.lock_outline : Icons.arrow_forward_ios,
                size: 18, color: locked ? AppColors.muted : AppColors.gold),
          ]),
        ),
      );
}

class _SkyCard extends StatelessWidget {
  final DayReading r;
  const _SkyCard({required this.r});
  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.line),
        ),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            leading: const Glyph('moon', size: 24, stroke: 7),
            title: Text('Bugünün gökyüzü', style: AppText.body(15.5, w: FontWeight.w700)),
            subtitle: Text(r.basis, style: AppText.body(12.5, color: AppColors.muted)),
            childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (r.moonPhase.isNotEmpty)
                Text('Ay evresi: ${r.moonPhase}', style: AppText.body(14, color: AppColors.muted)),
              ...r.skyEvents.map((e) =>
                  Padding(padding: const EdgeInsets.only(top: 6), child: Text('• $e', style: AppText.body(14)))),
              const SizedBox(height: 10),
              Text('GEZEGEN KONUMLARI', style: AppText.label(10.5)),
              ...r.skySummary.map((e) => Padding(
                  padding: const EdgeInsets.only(top: 4), child: Text(e, style: AppText.body(13, color: AppColors.muted)))),
            ],
          ),
        ),
      );
}
