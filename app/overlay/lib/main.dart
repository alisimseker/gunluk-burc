import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'ads.dart';
import 'native_bridge.dart';
import 'premium.dart';
import 'repository.dart';
import 'screens/home.dart';
import 'screens/permission.dart';
import 'screens/sign_picker.dart';
import 'theme.dart';
import 'zodiac.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: AppColors.bg,
  ));
  // Önce üyelik durumu; Premium değilse reklam izni ve kampanyalar hazırlanır
  PremiumService.instance.init().whenComplete(AdService.instance.init);
  runApp(const GunlukBurcApp());
}

class GunlukBurcApp extends StatelessWidget {
  const GunlukBurcApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Burç Atlası',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      locale: const Locale('tr', 'TR'),
      supportedLocales: const [Locale('tr', 'TR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // Çok büyük sistem yazı boyutlarında düzen bozulmasın (erişilebilirlik için yine de büyütmeye izin ver)
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(textScaler: mq.textScaler.clamp(minScaleFactor: 0.9, maxScaleFactor: 1.15)),
          child: child!,
        );
      },
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

  Future<void> _save(String s) async {
    await repo.setSign(s);
    await NativeBridge.setSign(s);
    if (mounted) setState(() => sign = s);
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Scaffold(backgroundColor: AppColors.bg);
    if (sign == null) {
      return SignPicker(
        firstRun: true,
        onPicked: (s) async {
          await Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => PermissionScreen(zodiac: zodiacById(s))));
          await _save(s);
        },
      );
    }
    return HomeScreen(
      sign: sign!,
      repo: repo,
      onChangeSign: () async {
        final picked = await Navigator.of(context).push<String>(MaterialPageRoute(
          builder: (ctx) =>
              SignPicker(firstRun: false, current: sign, onPicked: (s) async => Navigator.of(ctx).pop(s)),
        ));
        if (picked != null) await _save(picked);
      },
    );
  }
}
