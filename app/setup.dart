// Günlük Burç - proje kurulum betiği
//
// Kullanım (bu klasörde, komut satırında):
//     dart setup.dart
//
// Yaptıkları:
//  1. "gunluk_burc" adında Flutter projesini oluşturur (yoksa)
//  2. overlay/ klasöründeki kodları projeye kopyalar
//  3. AndroidManifest ve Gradle dosyalarına gerekli satırları ekler
//  4. iOS kodunu AppDelegate.swift'e ekler, widget dosyasını ios/BurcWidget'a koyar
//  5. Paketleri indirir
//
// Birden fazla kez çalıştırmak güvenlidir.
import 'dart:io';

const project = 'gunluk_burc';
const org = 'com.alisimseker';
const kotlinDir = 'android/app/src/main/kotlin/com/alisimseker/gunluk_burc';

void log(String s) => stdout.writeln('• $s');

Future<void> run(String cmd, List<String> args, {String? cwd}) async {
  log('$cmd ${args.join(' ')}');
  final p = await Process.start(cmd, args,
      workingDirectory: cwd, runInShell: true, mode: ProcessStartMode.inheritStdio);
  final code = await p.exitCode;
  if (code != 0) {
    stderr.writeln('HATA: "$cmd ${args.join(' ')}" başarısız oldu (kod $code).');
    exit(code);
  }
}

void copyDir(Directory from, Directory to) {
  for (final e in from.listSync(recursive: true)) {
    if (e is! File) continue;
    final rel = e.path.substring(from.path.length + 1);
    final target = File('${to.path}${Platform.pathSeparator}$rel');
    target.parent.createSync(recursive: true);
    e.copySync(target.path);
  }
}

String read(String p) => File(p).readAsStringSync();
void write(String p, String s) => File(p).writeAsStringSync(s);

Future<void> main() async {
  final root = Directory(project);
  if (!root.existsSync()) {
    await run('flutter', [
      'create', '--org', org, '--project-name', project,
      '--platforms', 'android,ios', project,
    ]);
  } else {
    log('Proje zaten var, güncelleniyor.');
  }

  // --- Dart kodu ve pubspec
  copyDir(Directory('overlay/lib'), Directory('$project/lib'));
  copyDir(Directory('overlay/assets'), Directory('$project/assets'));
  copyDir(Directory('overlay/tool'), Directory('$project/tool'));
  File('overlay/pubspec.yaml').copySync('$project/pubspec.yaml');
  final t = File('$project/test/widget_test.dart');
  if (t.existsSync()) t.deleteSync();

  // --- Android kodu
  final kt = Directory('$project/$kotlinDir');
  if (kt.existsSync()) {
    for (final f in kt.listSync()) {
      if (f is File && (f.path.endsWith('MainActivity.kt') || f.path.endsWith('MainActivity.java'))) {
        f.deleteSync();
      }
    }
  }
  copyDir(Directory('overlay/android'), Directory('$project/android'));

  // --- AndroidManifest
  final manifestPath = '$project/android/app/src/main/AndroidManifest.xml';
  var m = read(manifestPath);
  if (!m.contains('POST_NOTIFICATIONS')) {
    m = m.replaceFirst('<application', '''<uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
    <application''');
  }
  if (!m.contains('.BootReceiver')) {
    m = m.replaceFirst('</application>', '''    <receiver android:name=".BootReceiver" android:exported="false">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED"/>
                <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
            </intent-filter>
        </receiver>
    </application>''');
  }
  m = m.replaceFirst(RegExp(r'android:label="[^"]*"'), 'android:label="Günlük Burç"');
  write(manifestPath, m);
  log('AndroidManifest güncellendi.');

  // --- Gradle bağımlılıkları
  final kts = File('$project/android/app/build.gradle.kts');
  final groovy = File('$project/android/app/build.gradle');
  if (kts.existsSync()) {
    var g = kts.readAsStringSync().replaceAll(RegExp(r'\n\s*ndkVersion = flutter\.ndkVersion'), '');
    if (!g.contains('androidx.work:work-runtime')) {
      g += '''

dependencies {
    implementation("androidx.work:work-runtime:2.10.0")
    implementation("androidx.core:core:1.13.1")
}
''';
      kts.writeAsStringSync(g);
    }
  } else if (groovy.existsSync()) {
    var g = groovy.readAsStringSync();
    if (!g.contains('androidx.work:work-runtime')) {
      g += '''

dependencies {
    implementation 'androidx.work:work-runtime:2.10.0'
    implementation 'androidx.core:core:1.13.1'
}
''';
      groovy.writeAsStringSync(g);
    }
  }
  log('Gradle bağımlılıkları eklendi.');

  // --- iOS
  final appDelegate = '$project/ios/Runner/AppDelegate.swift';
  var ad = read(appDelegate);
  if (!ad.contains('GunlukBurcPlugin')) {
    final plugin = read('overlay/ios/GunlukBurcPlugin.swift.txt');
    final imports = plugin.split('\n').where((l) => l.startsWith('import ')).join('\n');
    final body = plugin.split('\n').where((l) => !l.startsWith('import ')).join('\n');
    ad = ad.replaceFirst('import Flutter', 'import Flutter\n$imports');
    // GeneratedPluginRegistrant.register(with: X) satırından sonra kendi kanalımızı kaydet
    final re = RegExp(r'GeneratedPluginRegistrant\.register\(with: ([^)]+)\)');
    final match = re.firstMatch(ad);
    if (match == null) {
      stderr.writeln('UYARI: AppDelegate.swift beklenen biçimde değil; iOS kanalı elle eklenmeli.');
    } else {
      final reg = match.group(1)!;
      ad = ad.replaceFirst(re,
          '${match.group(0)}\n    if let r = $reg.registrar(forPlugin: "GunlukBurcPlugin") { GunlukBurcPlugin.register(with: r) }');
    }
    ad += '\n$body';
    write(appDelegate, ad);
  }
  copyDir(Directory('overlay/ios/BurcWidget'), Directory('$project/ios/BurcWidget'));
  log('iOS kodu eklendi (widget hedefi Mac\'te Xcode ile bir kez eklenmeli, rehbere bak).');

  await run('flutter', ['pub', 'get'], cwd: project);
  stdout.writeln('\nKurulum tamam. Telefonunu bağlayıp şunu çalıştır:\n  cd $project\n  flutter run');
}
