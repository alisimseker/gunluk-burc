/// İçeriklerin indirildiği adres (GitHub Pages).
/// Aynı adresi Android'de NativeBridge üzerinden, iOS'ta widget'ta da kullanıyoruz.
const String kContentBaseUrl = 'https://alisimseker.github.io/gunluk-burc';

/// Google Play Console ve App Store Connect'te açılacak abonelik ürünlerinin kimlikleri
const String kMonthlyProductId = 'aylik_premium';
const String kYearlyProductId = 'yillik_premium';

/// Mağazaya ulaşılamadığında gösterilecek fiyatlar (gerçek fiyat mağazadan gelir)
const String kMonthlyFallbackPrice = '₺299';
const String kYearlyFallbackPrice = '₺2.499';

// ---------------------------------------------------------------- reklam
/// AdMob kimlikleri. ŞU AN GOOGLE'IN TEST KİMLİKLERİ: AdMob hesabı açınca kendi kimliklerinle değiştir.
/// (Uygulama kimliği ayrıca AndroidManifest.xml ve iOS Info.plist'te de yazılı; setup.dart ekler.)
const String kAdmobInterstitialAndroid = 'ca-app-pub-3940256099942544/1033173712';
const String kAdmobInterstitialIos = 'ca-app-pub-3940256099942544/4411468910';

/// Ana sayfanın altındaki sabit banner (uyarlanabilir banner test kimlikleri)
const String kAdmobBannerAndroid = 'ca-app-pub-3940256099942544/9214589741';
const String kAdmobBannerIos = 'ca-app-pub-3940256099942544/2435281174';

/// Ücretsiz kullanıcıya günde en fazla kaç tam ekran reklam gösterilir
const int kAdsPerDay = 1;

/// Reklamdan önce kullanıcının ana sayfada geçirmesi gereken süre (yorumu okusun)
const Duration kAdDelay = Duration(seconds: 12);
