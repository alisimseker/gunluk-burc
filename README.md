# Günlük Burç

Her gün yapay zekânın gerçek gökyüzü verisine dayanarak yazdığı burç yorumu ve kısa motivasyon cümlesi;
Android'de kilit ekranında ve bildirim çubuğunda, iPhone'da kilit ekranında saatin altında.

## Nasıl çalışıyor

```
GitHub Actions (her gece, ücretsiz)
  ├─ sky.py        → o günün gerçek gezegen konumları, açılar, retrolar, Ay evresi (yerel hesap)
  ├─ generate.py   → Gemini (ücretsiz) 12 burcu yazar → uydurma + tekrar kontrolü → gerekirse yeniden yazdırır
  └─ docs/v1/*.json → GitHub Pages'te yayınlanır (ücretsiz)

Telefon
  ├─ Android: arka plan işi 3 saatte bir + her gece 00:01 indirir → kalıcı bildirim (kilit ekranı + bildirim çubuğu)
  └─ iPhone:  kilit ekranı widget'ı kendisi indirir + uygulama 8 günlük sabah bildirimlerini planlar
```

İçerik her zaman **8 gün önceden** hazırlanır. Bir gece bir sorun olsa bile kullanıcılar etkilenmez,
sistem ertesi çalıştırmada eksik günleri tamamlar. Telefonlar da 8 günlük içeriği saklar; internet yokken bile
kilit ekranındaki yorum her gün değişir.

## Maliyet

| Kalem | Ücret |
|---|---|
| GitHub (kod, günlük üretim, içerik sunucusu) | Ücretsiz |
| Gemini API (günde ~1-4 istek, ücretsiz kota ~20) | Ücretsiz |
| Gökyüzü hesaplama (astronomy-engine) | Ücretsiz |
| Google Play geliştirici hesabı | **25 $ bir kez** |
| Apple Developer (yalnızca iPhone sürümü için) | **99 $ / yıl** |

---

## 1. İçerik sunucusunu kur (~15 dk)

1. [github.com](https://github.com) hesabı aç. Sağ üstte **+ › New repository**:
   ad `gunluk-burc`, **Public** seç, oluştur.
2. Bu klasördeki tüm dosyaları depoya yükle (**Add file › Upload files**, klasörleri sürükleyip bırak).
   `.github` klasörünün de yüklendiğinden emin ol (gizli klasör; Windows'ta "Gizli öğeleri göster"i aç).
3. Ücretsiz yapay zekâ anahtarı al: [aistudio.google.com](https://aistudio.google.com) › **Get API key** › **Create API key**.
   Kart bilgisi istemez. Faturalandırmayı (billing) açma; açarsan ücretsiz kotadan çıkarsın.
4. Depoda **Settings › Secrets and variables › Actions › New repository secret**:
   ad `GEMINI_API_KEY`, değer: aldığın anahtar.
5. **Settings › Pages**: Source = *Deploy from a branch*, Branch = `main`, klasör = `/docs`, **Save**.
6. **Actions** sekmesi › "Günlük burç içeriği" › **Run workflow**. İlk çalıştırma 3 günü üretir;
   2 kez daha çalıştırırsan 8 günlük tampon dolar. Sonrası her gece kendiliğinden çalışır.
7. Kontrol: `https://alisimseker.github.io/gunluk-burc/v1/koc.json` adresi yorumları göstermeli.

Bir gece üretim başarısız olursa GitHub sana e-posta atar; tampon 8 gün olduğu için acele gerekmez.

## 2. Android uygulaması

1. Flutter'ı kur: [docs.flutter.dev/get-started/install/windows](https://docs.flutter.dev/get-started/install/windows)
   (Android Studio zaten kurulu). Kurulumdan sonra `flutter doctor` çalıştır, hepsi yeşil olsun.
2. `app/overlay/lib/config.dart` dosyasında `alisimseker` yerine GitHub kullanıcı adını yaz.
3. Komut satırında `app` klasörüne gir ve çalıştır:
   ```
   dart setup.dart
   ```
4. Telefonda Geliştirici seçenekleri › USB hata ayıklama açık, USB ile bağla:
   ```
   cd gunluk_burc
   flutter run
   ```
5. Burcunu seç, bildirim iznini ver, telefonu kilitle: yorum kilit ekranında görünür.
   *Samsung:* Ayarlar › Kilit ekranı › Bildirimler › **Ayrıntılar**.
6. Mağaza için: `flutter build appbundle` → Google Play Console'a yükle.
   Gizlilik politikası adresi: `https://alisimseker.github.io/gunluk-burc/`

## 3. iPhone uygulaması (Mac gerekir)

Apple, iOS uygulamalarının yalnızca Mac'teki Xcode ile derlenmesine izin verir. Bir kez yapılacak ayar:

1. Mac'te Flutter + Xcode kur, projeyi aç: `open gunluk_burc/ios/Runner.xcworkspace`
2. **File › New › Target › Widget Extension**, ad `BurcWidget`.
   "Include Live Activity" ve "Include Configuration App Intent" kutularını **kaldır**.
   Oluşan `BurcWidget.swift` içeriğini `ios/BurcWidget/BurcWidget.swift` ile değiştir,
   diğer örnek dosyaları (BurcWidgetBundle.swift vb.) sil. Widget hedefinin iOS sürümünü **16.0** yap.
3. **Runner** ve **BurcWidgetExtension** hedeflerinin ikisinde de
   *Signing & Capabilities › + Capability › App Groups* › `group.com.alisimseker.gunlukburc` ekle.
4. `flutter run` ile iPhone'da dene. Kilit ekranına basılı tut › Özelleştir › saatin altına "Günlük Burç".

## Premium (aylık üyelik, 299 TL)

Ücretsiz: yalnızca bugünün yorumu ve günün cümlesi (kilit ekranı dahil).
Premium: dün ve yarın, doğum haritası, yükselen burç, Ay burcu.

- Doğum haritası telefonda **hesaplanır** (`app/overlay/lib/astro/engine.dart`): Meeus algoritmaları (Güneş, Ay,
  yükselen, Placidus evleri) + Mars–Plüton için Swiss Ephemeris'ten üretilmiş 1920–2040 tablosu.
  `dart run tool/astro_check.dart` 60 haritayı Swiss Ephemeris'e karşı doğrular (sapma < 2 yay dakikası).
- Yorumlar yapay zekâ ile bir kez yazılır (`content-engine/natal_library.py`, 300 yerleşim),
  `docs/v1/natal/tr.json` olarak yayınlanır. "Doğum haritası yorum kütüphanesi" iş akışı her gün eksikleri tamamlar.
- Abonelik: Google Play Console › Para kazanma › Abonelikler › ürün kimliği **`aylik_premium`**,
  1 aylık temel plan, fiyat 299 TL. (iOS: App Store Connect'te aynı kimlikle otomatik yenilenen abonelik.)
  Uygulama her açılışta mağazaya sorar; süresi biten üyelikte özellikler kapanır, yenilenince açılır.
- Satın alma yalnızca uygulama Google Play üzerinden (en az "Dahili test" kanalından) yüklendiğinde çalışır.
  Deneme sürümünde (debug) Ayarlar menüsündeki "Test: Premium açık" anahtarıyla özellikler denenebilir.

## Dosyalar

| Yol | Ne işe yarar |
|---|---|
| `content-engine/sky.py` | Gerçek gökyüzü hesaplaması (`python sky.py 2026-10-20` ile deneyebilirsin) |
| `content-engine/generate.py` | Yapay zekâya yazdırma, uydurma ve tekrar kontrolleri, yayınlama |
| `content-engine/similarity.py` | Tekrar ölçümü |
| `.github/workflows/daily-content.yml` | Her gece otomatik çalıştırma |
| `data/archive/` | Üretilen tüm günlerin arşivi (tekrar kontrolü bunu kullanır) |
| `docs/` | Uygulamanın indirdiği yayın dosyaları + gizlilik sayfası |
| `app/overlay/` | Flutter uygulama kodu, Android ve iOS yerel kodu |
| `app/setup.dart` | Flutter projesini oluşturup kodu yerleştiren betik |

API anahtarı olmadan içerik sistemini denemek için: `python content-engine/generate.py --mock`
(deneme çıktısını depoya yükleme).
