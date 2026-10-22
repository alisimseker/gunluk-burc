# Burç Atlası – Günlük Burç

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
4. `flutter run` ile iPhone'da dene. Kilit ekranına basılı tut › Özelleştir › saatin altına "Burç Atlası".

## Premium (aylık 299 TL · yıllık 2.499 TL)

Ücretsiz: bugünün yorumu ve günün cümlesi (kilit ekranı dahil), günde en fazla 1 reklam (kurulum günü hiç yok).
Premium: reklamsız; dün ve yarın, **bugün sana özel** (günün gezegenleri × doğum haritan), **burç uyumu**
(iki harita), **gökyüzü takvimi** (retro, Yeniay, Dolunay, tutulma; 1 gün önceden bildirim),
**yıllık öngörü** (güneş dönüşü), doğum haritası, yükselen ve Ay burcu.

- Tüm hesaplar telefonda yapılır (`app/overlay/lib/astro/`): Meeus algoritmaları (Ay, yükselen, Placidus evleri)
  + Güneş–Plüton için Swiss Ephemeris'ten üretilmiş 1920–2050 tablosu.
  `dart run tool/astro_check.dart` 60 haritayı Swiss Ephemeris'e karşı doğrular.
- Yorumlar yapay zekâ ile **bir kez** yazılır ve yayınlanır (`content-engine/library.py`):
  `docs/v1/{natal,transits,synastry,events,solar}/tr.json`. "Yapay zekâ yorum kütüphaneleri" iş akışı
  günde 3 kez eksikleri tamamlar; bitince Gemini'ye hiç istek gitmez. Kullanıcının doğum bilgisi Gemini'ye
  gönderilmez: telefon haritayı hesaplar ve hazır yorumlardan uygun olanları seçer.
- Abonelikler: Google Play Console › Para kazanma › Abonelikler:
  - **`aylik_premium`**: 1 aylık temel plan, 299 TL
  - **`yillik_premium`**: 1 yıllık temel plan, 2.499 TL
  (iOS: App Store Connect'te aynı kimliklerle, aynı abonelik grubunda iki otomatik yenilenen abonelik.)
  Uygulama her açılışta mağazaya sorar; süresi biten üyelikte özellikler kapanır, yenilenince açılır.
- Satın alma yalnızca uygulama Google Play üzerinden (en az "Dahili test" kanalından) yüklendiğinde çalışır.
  Deneme sürümünde (debug) Ayarlar menüsündeki "Test: Premium açık" anahtarıyla özellikler denenebilir.

## Reklamlar

Yalnızca ücretsiz kullanıcılara: ana sayfada 12 saniye geçtikten sonra günde en fazla 1 tam ekran reklam,
ayrıca ana sayfanın en altında, içerikten ayrılmış sabit bir banner (kurulum günü ikisi de yok).
Önce **marka kampanyası** varsa o gösterilir; yoksa **AdMob** reklamı (Google satar, sen kazanırsın).

### Marka kampanyası ekleme / kaldırma

`docs/v1/ads.json` dosyasını GitHub'da düzenle (kalem simgesi › Commit). Telefonlar 10 dakika içinde görür;
uygulama güncellemesi gerekmez. Görsel/video dosyalarını `docs/ads/` klasörüne yükleyebilirsin.

```json
{
  "campaigns": [
    {
      "id": "kahve-kasim",
      "brand": "Örnek Kahve",
      "title": "Yeni sezon kahveleri",
      "subtitle": "Uygulamaya özel %20 indirim",
      "cta": "Hemen incele",
      "url": "https://ornek.com/kampanya",
      "image": "https://alisimseker.github.io/gunluk-burc/ads/kahve.jpg",
      "video": "",
      "logo": "",
      "start": "2026-11-01",
      "end": "2026-11-30",
      "skip_after": 5,
      "weight": 1,
      "signs": []
    }
  ]
}
```

| Alan | Anlamı |
|---|---|
| `image` / `video` | Gösterilecek görsel (jpg/png) ya da kısa video (mp4). Video varsa o oynar. |
| `start`, `end` | Kampanyanın yayında olduğu günler (bu günler dahil). Süre bitince kendiliğinden kalkar. |
| `skip_after` | Kaç saniye sonra "Geç" düğmesi çıksın. |
| `weight` | Aynı anda birden fazla kampanya varsa gösterilme payı (2 = diğerinin 2 katı). |
| `signs` | Boş = herkese. `["koc","aslan"]` = yalnızca bu burçlara. |

Kaldırmak için kampanyayı listeden sil (ya da `end` tarihini geçmişe çek). Liste boşsa AdMob devreye girer.

### AdMob'u gerçek hesaba bağlama (para kazanmak için)

Şu an Google'ın **test** kimlikleri kullanılıyor (ekranda "Test Ad" yazar, para kazandırmaz).
1. [admob.google.com](https://admob.google.com) hesabı aç, Android ve iOS uygulamasını ekle.
2. Her uygulamada bir **Geçiş reklamı (Interstitial)** ve bir **Banner** birimi oluştur.
3. Uygulama kimliklerini (`ca-app-pub-…~…`) `app/setup.dart` başındaki `admobAndroidAppId` / `admobIosAppId`'ye,
   birim kimliklerini (`ca-app-pub-…/…`) `app/overlay/lib/config.dart`'taki `kAdmobInterstitial…` ve `kAdmobBanner…`'a yaz.
4. AdMob › Gizlilik ve mesajlaşma › **GDPR mesajı** oluştur (Avrupa'daki kullanıcılar için izin ekranı).
5. Play Console › Uygulama içeriği › **Reklamlar: Evet** olarak işaretle.

## Dosyalar

| Yol | Ne işe yarar |
|---|---|
| `content-engine/sky.py` | Gerçek gökyüzü hesaplaması (`python sky.py 2026-10-20` ile deneyebilirsin) |
| `content-engine/generate.py` | Yapay zekâya yazdırma, uydurma ve tekrar kontrolleri, yayınlama |
| `content-engine/similarity.py` | Tekrar ölçümü |
| `content-engine/library.py` | Premium yorum kütüphaneleri (harita, transit, uyum, takvim, yıllık) |
| `docs/v1/ads.json` | Marka reklam kampanyaları |
| `.github/workflows/daily-content.yml` | Her gece otomatik çalıştırma |
| `data/archive/` | Üretilen tüm günlerin arşivi (tekrar kontrolü bunu kullanır) |
| `docs/` | Uygulamanın indirdiği yayın dosyaları + gizlilik sayfası |
| `app/overlay/` | Flutter uygulama kodu, Android ve iOS yerel kodu |
| `app/setup.dart` | Flutter projesini oluşturup kodu yerleştiren betik |

API anahtarı olmadan içerik sistemini denemek için: `python content-engine/generate.py --mock`
(deneme çıktısını depoya yükleme).
