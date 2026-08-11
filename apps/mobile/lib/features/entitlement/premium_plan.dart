/// **Ücretsiz/premium çizgisinin TEK kaynağı** (F5).
///
/// ## Neden bir tablo, neden dağınık `if (premium)` değil
///
/// Bugün uygulamada tek bir kapı var (haftalık trendler) ve o kapı kodun içinde
/// yalnız başına duruyor: hangi özelliğin premium OLDUĞU hiçbir yerde YAZILI
/// değil. İkinci kapı eklendiği gün paywall metni ile gerçek davranış birbirinden
/// ayrılır ve kullanıcı parasını verdiği şeyi bulamaz. Sınır burada bir kez
/// tanımlanır; paywall listesini de kapıları da bu tablo besler.
///
/// ## ⚠️ ARKASI BOŞ — bilinçli ve geçici
///
/// Bu dosya **satın alma yapmaz**. Gerçek IAP en son fazdır (CLAUDE.md §6,
/// docs/10): geliştirici hesapları alınmadan ödeme kodu yazılmaz. Sunucu bugün
/// herkese `plus` döndürüyor (`DevEntitlementService`), yani hiçbir kapı fiilen
/// kapalı değil. Burada kurulan şey **çerçeve**: sınırın tanımı, ekranlar ve
/// kapı mekanizması. O gün geldiğinde değişecek tek şey sunucudaki adaptördür.
library;

/// Ücretsiz katmanın kapsamı — **cömert, çünkü ürünün büyüme motoru bu.**
///
/// Araştırma notu (hot.md): BetterSleep sadık tabanını paywall'la yakıyor
/// ("8 yıldır kullanıyorum, artık para vermem"). Mikserin TAMAMI, kendi
/// kayıtların ve zamanlayıcı ücretsiz kalır; premium olan şey ÖLÇEK
/// (tam kütüphane, sonsuz uzatma, çevrimdışı, alarm, video).
enum PremiumFeature {
  /// Tam ses kütüphanesi (ücretsizde ~40 ses).
  fullLibrary,

  /// Sonsuz jeneratif uzatma — ücretsizde tarif döngülenir (F2 kapalı).
  infiniteExtension,

  /// Çevrimdışı kullanım (indirilmiş içerik).
  offline,

  /// Akıllı alarm.
  smartAlarm,

  /// Sınırsız kayıtlı mix (ücretsizde 3).
  unlimitedMixes,

  /// Mix-to-video dışa aktarma.
  videoExport,

  /// Haftalık uyku trendleri — BUGÜN kodda fiilen kapılı tek özellik.
  weeklyTrends,
}

/// Deneme süresi. **Gerçek deneme** (kredi kartı öncesi tam erişim), araştırma
/// notundaki dönüşüm farkı bu yüzden: 7 gün deneme, denemesiz akışa göre
/// dönüşümü belirgin biçimde artırıyor (hot.md).
const int kTrialDays = 7;

/// Ücretsiz katmanda dinlenebilecek ses sayısı — paywall metninde geçer.
const int kFreeLibrarySize = 40;

/// Ücretsiz katmanda saklanabilecek mix sayısı.
const int kFreeMixSlots = 3;
