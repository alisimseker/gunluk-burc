import 'dart:io' show Platform;

import 'package:flutter/material.dart';

import 'native_bridge.dart';
import 'repository.dart';
import 'zodiac.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const GunlukBurcApp());
}

// ---------------------------------------------------------------- tema
const _bg = Color(0xFF12101E);
const _card = Color(0xFF1E1A33);
const _gold = Color(0xFFE8C77B);
const _muted = Color(0xFFA9A3C4);

class GunlukBurcApp extends StatelessWidget {
  const GunlukBurcApp({super.key});

  @override
  Widget build(BuildContext context) {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
          seedColor: _gold, brightness: Brightness.dark, surface: _bg),
      scaffoldBackgroundColor: _bg,
    );
    return MaterialApp(
      title: 'Günlük Burç',
      debugShowCheckedModeBanner: false,
      theme: base.copyWith(
        appBarTheme: const AppBarTheme(backgroundColor: _bg, elevation: 0),
      ),
      home: const _Root(),
    );
  }
}

class _Root extends StatefulWidget {
  const _Root();
  @override
  State<_Root> createState() => _RootState();
}

class _RootState extends State<_Root> {
  final repo = Repository();
  String? sign;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    repo.getSign().then((s) {
      setState(() {
        sign = s;
        loading = false;
      });
      if (s != null) NativeBridge.sync();
    });
  }

  Future<void> _onPicked(String s) async {
    await repo.setSign(s);
    await NativeBridge.setSign(s);
    if (!mounted) return;
    setState(() => sign = s);
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Scaffold();
    if (sign == null) return SignPicker(onPicked: _onPicked, firstRun: true);
    return HomeScreen(
      sign: sign!,
      repo: repo,
      onChangeSign: () async {
        final picked = await Navigator.of(context).push<String>(MaterialPageRoute(
          builder: (_) => SignPicker(
              onPicked: (s) async => Navigator.of(context).pop(s), firstRun: false),
        ));
        if (picked != null) await _onPicked(picked);
      },
    );
  }
}

// ---------------------------------------------------------------- burç seçimi
class SignPicker extends StatelessWidget {
  final Future<void> Function(String) onPicked;
  final bool firstRun;
  const SignPicker({super.key, required this.onPicked, required this.firstRun});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: firstRun ? null : AppBar(title: const Text('Burcunu değiştir')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (firstRun) ...[
                const SizedBox(height: 12),
                const Text('Burcun hangisi?',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                const Text(
                    'Her sabah yorumun ve motivasyon cümlen kilit ekranına gelsin.',
                    style: TextStyle(color: _muted, fontSize: 15)),
                const SizedBox(height: 20),
              ],
              Expanded(
                child: GridView.builder(
                  itemCount: kZodiacs.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3, mainAxisSpacing: 12, crossAxisSpacing: 12,
                      childAspectRatio: 0.82),
                  itemBuilder: (_, i) {
                    final z = kZodiacs[i];
                    return InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () async {
                        if (firstRun) {
                          await Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => PermissionScreen(zodiac: z)));
                        }
                        await onPicked(z.id);
                      },
                      child: Ink(
                        decoration: BoxDecoration(
                            color: _card, borderRadius: BorderRadius.circular(16)),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(z.symbol, style: const TextStyle(fontSize: 34, color: _gold)),
                            const SizedBox(height: 6),
                            Text(z.name,
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            Text(z.range,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 11, color: _muted)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- izin + kilit ekranı rehberi
class PermissionScreen extends StatelessWidget {
  final Zodiac zodiac;
  const PermissionScreen({super.key, required this.zodiac});

  @override
  Widget build(BuildContext context) {
    final ios = Platform.isIOS;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),
              Text(zodiac.symbol, style: const TextStyle(fontSize: 56, color: _gold)),
              const SizedBox(height: 12),
              const Text('Kilit ekranında görmek için',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              if (!ios) ...const [
                _Step(n: 1, text: 'Bir sonraki adımda bildirimlere izin ver.'),
                _Step(n: 2, text: 'Yorumun kilit ekranında ve bildirim çubuğunda sabit durur, her gün kendiliğinden yenilenir.'),
                _Step(n: 3, text: 'Samsung\'da görünmüyorsa: Ayarlar › Kilit ekranı › Bildirimler › "Ayrıntılar"ı seç.'),
              ] else ...const [
                _Step(n: 1, text: 'Bir sonraki adımda bildirimlere izin ver; her sabah yorumun gelir.'),
                _Step(n: 2, text: 'Kilit ekranına basılı tut › Özelleştir › Kilit Ekranı.'),
                _Step(n: 3, text: 'Saatin altındaki alana dokun ve "Günlük Burç" widget\'ını ekle.'),
              ],
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                      backgroundColor: _gold, foregroundColor: _bg,
                      padding: const EdgeInsets.symmetric(vertical: 16)),
                  onPressed: () async {
                    await NativeBridge.requestNotificationPermission();
                    if (context.mounted) Navigator.of(context).pop();
                  },
                  child: const Text('Devam et', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final int n;
  final String text;
  const _Step({required this.n, required this.text});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CircleAvatar(
              radius: 13,
              backgroundColor: _card,
              child: Text('$n', style: const TextStyle(color: _gold, fontSize: 13))),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 15, height: 1.4))),
        ]),
      );
}

// ---------------------------------------------------------------- ana ekran
class HomeScreen extends StatefulWidget {
  final String sign;
  final Repository repo;
  final VoidCallback onChangeSign;
  const HomeScreen(
      {super.key, required this.sign, required this.repo, required this.onChangeSign});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  Map<String, DayReading> days = {};
  bool offline = false;
  bool loading = true;
  int offset = 0; // -1 dün, 0 bugün, 1 yarın
  bool notifOk = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _load();
      NativeBridge.sync();
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

  @override
  Widget build(BuildContext context) {
    final z = zodiacById(widget.sign);
    final now = DateTime.now();
    final day = DateTime(now.year, now.month, now.day).add(Duration(days: offset));
    final reading = days[isoDate(day)];

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              Row(children: [
                Text(z.symbol, style: const TextStyle(fontSize: 36, color: _gold)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(z.name,
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
                    Text(trLongDate(day), style: const TextStyle(color: _muted)),
                  ]),
                ),
                IconButton(
                    tooltip: 'Burcu değiştir',
                    onPressed: widget.onChangeSign,
                    icon: const Icon(Icons.swap_horiz)),
              ]),
              const SizedBox(height: 16),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: -1, label: Text('Dün')),
                  ButtonSegment(value: 0, label: Text('Bugün')),
                  ButtonSegment(value: 1, label: Text('Yarın')),
                ],
                selected: {offset},
                onSelectionChanged: (s) => setState(() => offset = s.first),
              ),
              const SizedBox(height: 16),
              if (!notifOk) _NotifBanner(onTap: () async {
                await NativeBridge.requestNotificationPermission();
                await NativeBridge.openNotificationSettings();
              }),
              if (offline)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text('İnternet yok, son indirilen yorumlar gösteriliyor.',
                      style: TextStyle(color: _muted, fontSize: 13)),
                ),
              if (loading)
                const Padding(
                    padding: EdgeInsets.all(48),
                    child: Center(child: CircularProgressIndicator()))
              else if (reading == null)
                const _Empty()
              else ...[
                _MotivationCard(text: reading.motivation),
                const SizedBox(height: 12),
                _ReadingCard(r: reading),
                const SizedBox(height: 12),
                _SkyCard(r: reading),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _NotifBanner extends StatelessWidget {
  final VoidCallback onTap;
  const _NotifBanner({required this.onTap});
  @override
  Widget build(BuildContext context) => Card(
        color: const Color(0xFF3A2A1A),
        margin: const EdgeInsets.only(bottom: 12),
        child: ListTile(
          leading: const Icon(Icons.notifications_off_outlined, color: _gold),
          title: const Text('Bildirimler kapalı'),
          subtitle: const Text('Kilit ekranında görmek için bildirimleri aç.'),
          onTap: onTap,
        ),
      );
}

class _MotivationCard extends StatelessWidget {
  final String text;
  const _MotivationCard({required this.text});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
              colors: [Color(0xFF3B2F6B), Color(0xFF1E1A33)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('GÜNÜN CÜMLESİ',
              style: TextStyle(color: _gold, fontSize: 12, letterSpacing: 1.5)),
          const SizedBox(height: 8),
          Text(text,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600, height: 1.3)),
        ]),
      );
}

class _ReadingCard extends StatelessWidget {
  final DayReading r;
  const _ReadingCard({required this.r});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(20),
        decoration:
            BoxDecoration(color: _card, borderRadius: BorderRadius.circular(20)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (r.focus.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                  color: _gold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20)),
              child: Text(r.focus, style: const TextStyle(color: _gold, fontSize: 13)),
            ),
          const SizedBox(height: 12),
          Text(r.text, style: const TextStyle(fontSize: 16.5, height: 1.55)),
        ]),
      );
}

class _SkyCard extends StatelessWidget {
  final DayReading r;
  const _SkyCard({required this.r});
  @override
  Widget build(BuildContext context) => Container(
        decoration:
            BoxDecoration(color: _card, borderRadius: BorderRadius.circular(20)),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            leading: const Icon(Icons.auto_awesome, color: _gold),
            title: const Text('Bu yorum neye dayanıyor?'),
            subtitle: Text(r.basis, style: const TextStyle(color: _muted, fontSize: 13)),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (r.moonPhase.isNotEmpty)
                Text('Ay evresi: ${r.moonPhase}', style: const TextStyle(color: _muted)),
              ...r.skyEvents.map((e) => Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('• $e', style: const TextStyle(fontSize: 14)))),
              const SizedBox(height: 10),
              const Text('Gezegen konumları',
                  style: TextStyle(color: _gold, fontSize: 13)),
              ...r.skySummary.map((e) => Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(e, style: const TextStyle(color: _muted, fontSize: 13)))),
            ],
          ),
        ),
      );
}

class _Empty extends StatelessWidget {
  const _Empty();
  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.all(40),
        child: Text('Bu gün için yorum henüz hazır değil.\nAşağı çekerek yenileyebilirsin.',
            textAlign: TextAlign.center, style: TextStyle(color: _muted)),
      );
}
