/// İçeriklerin indirildiği adres (GitHub Pages).
/// Aynı adresi Android'de NativeBridge üzerinden, iOS'ta widget'ta da kullanıyoruz.
const String kContentBaseUrl = 'https://alisimseker.github.io/gunluk-burc';

/// Google Play Console ve App Store Connect'te açılacak abonelik ürünlerinin kimlikleri
const String kMonthlyProductId = 'aylik_premium';
const String kYearlyProductId = 'yillik_premium';

/// Mağazaya ulaşılamadığında gösterilecek fiyatlar (gerçek fiyat mağazadan gelir)
const String kMonthlyFallbackPrice = '₺299,99';
const String kYearlyFallbackPrice = '₺2.499,99';

// ---------------------------------------------------------------- reklam
/// GERÇEK REKLAM ANAHTARI. false iken uygulama yalnızca Google'ın test reklamlarını gösterir
/// (yanlışlıkla tıklansa da AdMob hesabına zarar gelmez). Uygulama Play Store'da herkese
/// açılacağı gün true yapılır; app/setup.dart'taki kGercekReklam da aynı anda true olmalı.
const bool kGercekReklam = true;

/// AdMob kimlikleri. Android gerçek kimlikleri: AdMob uygulaması "Burç Atlası - Günlük Burç".
/// iOS: henüz yalnızca test kimlikleri; iOS sürümü çıkınca AdMob'da iOS uygulaması açılacak.
/// (Uygulama kimliği ayrıca AndroidManifest.xml ve iOS Info.plist'te de yazılı; setup.dart ekler.)
const String kAdmobInterstitialAndroid =
    kGercekReklam ? 'ca-app-pub-8986045384678938/7703376872' : 'ca-app-pub-3940256099942544/1033173712';
const String kAdmobInterstitialIos = 'ca-app-pub-3940256099942544/4411468910';

/// Ana sayfanın altındaki sabit banner
const String kAdmobBannerAndroid =
    kGercekReklam ? 'ca-app-pub-8986045384678938/5077213536' : 'ca-app-pub-3940256099942544/9214589741';
const String kAdmobBannerIos = 'ca-app-pub-3940256099942544/2435281174';

/// Ücretsiz kullanıcıya günde en fazla kaç tam ekran reklam gösterilir
const int kAdsPerDay = 1;

/// Reklamdan önce kullanıcının ana sayfada geçirmesi gereken süre (yorumu okusun)
const Duration kAdDelay = Duration(seconds: 12);
