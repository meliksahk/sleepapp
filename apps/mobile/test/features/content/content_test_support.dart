import 'dart:io';

import 'package:nocta/features/content/data/content_library_source.dart';

/// Testlerin GERÇEK üretilmiş içerik kütüphanesini okuması için kaynak.
///
/// **Neden `rootBundle` değil, dosyadan:** kütüphane `tooling/gen-content-library.mjs`
/// ile `db/seed.sql`'den üretilen COMMIT'Lİ bir dosya. Testin onu diskten okuması,
/// iddiaların uydurulmuş bir örnek yerine kullanıcının cihazına giden GERÇEK veriye
/// dayanması demek — asset yolu bozulursa da burada patlar.
///
/// **`readAsStringSync` bilinçli** (archetype_test_support.dart'taki aynı tuzak):
/// widget testleri sahte zaman bölgesinde koşar ve GERÇEK disk G/Ç'si orada
/// tamamlanmaz. `rootBundle` ile bırakılırsa kütüphane ekranındaki yükleme
/// göstergesi hiç kaybolmaz ve `pumpAndSettle` "timed out" ile patlar (bu iş
/// sırasında birebir yaşandı: `sleep_session_strip_test` iki testte kilitlendi).
/// Dosya senkron okunup hazır bir Future olarak verilince mikrotask kuyruğunda
/// çözülür ve pump normal ilerler.
///
/// **/library rotasını çizen HER widget testi bunu override etmeli**
/// (`contentLibrarySourceProvider.overrideWithValue(testLibrarySource())`).
ContentLibrarySource testLibrarySource({DateTime Function()? now}) {
  final cache = <String, String>{};
  return ContentLibrarySource(
    loadAsset: (key) async => cache[key] ??= File(key).readAsStringSync(),
    now: now,
  );
}

/// Kütüphaneyi okuyamayan kaynak — "asset yok/bozuk" hata halini kurar.
ContentLibrarySource brokenLibrarySource() {
  return ContentLibrarySource(
    loadAsset: (key) async => throw const FileSystemException('asset yok'),
  );
}

/// Üretilen kütüphanedeki gerçek değerler — testlerin beklediği sabitler tek yerde.
/// (seed.sql değişirse tek bir dosya güncellenir, altı test değil.)
class LibraryFixture {
  /// `db/seed.sql`'deki yayınlanmış soundscape sayısı.
  static const int soundscapeCount = 7;

  /// #215'te eklenen tam demo tarif — müzik (pad) + gürültü (white) + efekt (fire).
  /// Bu iş öncesinde YALNIZCA seed'de yaşıyordu, kurulan APK'da yoktu.
  static const String demoSlug = 'hearth-and-static';
  static const String demoTitleEn = 'Hearth & Static';

  /// Haftalık yayındaki parça sayısı.
  static const int weeklyCount = 3;
}
