import 'dart:io';

import 'package:nocta/features/archetype/data/archetype_matrix_source.dart';

/// Testlerin GERÇEK üretilmiş matrisi okuması için kaynak.
///
/// **Neden `rootBundle` değil, dosyadan:** matris `tooling/gen-archetype-matrix.mjs`
/// ile sunucu domain'inden üretilen COMMIT'Lİ bir dosya. Testin onu diskten
/// okuması, iddiaların uydurulmuş bir örnek yerine kullanıcının cihazına giden
/// GERÇEK veriye dayanması demek — asset yolu bozulursa da burada patlar.
///
/// **`readAsStringSync` bilinçli:** widget testleri sahte zaman bölgesinde koşar
/// ve GERÇEK disk G/Ç'si orada tamamlanmaz — `pumpAndSettle` sonsuza dek dönüp
/// "timed out" ile patlıyordu (yaşandı). Dosya senkron okunup hazır bir Future
/// olarak verilince mikrotask kuyruğunda çözülür ve pump normal ilerler.
ArchetypeMatrixSource testMatrixSource() {
  final cache = <String, String>{};
  return ArchetypeMatrixSource(
    loadAsset: (key) async => cache[key] ??= File(key).readAsStringSync(),
  );
}

/// Matrisi okuyamayan kaynak — "asset yok/bozuk" hata halini kurar.
ArchetypeMatrixSource brokenMatrixSource() {
  return ArchetypeMatrixSource(
    loadAsset: (key) async => throw const FileSystemException('asset yok'),
  );
}

/// Üretilen matristeki gerçek metinler — testlerin beklediği değerler tek yerde.
/// (Matris değişirse tek bir dosya güncellenir, on bir test değil.)
class MatrixFixture {
  /// İlk sorunun EN metni.
  static const String firstPromptEn = 'When your head hits the pillow, your mind…';

  /// Soru sayısı — ilerleme göstergesi iddiaları buna dayanır.
  static const int questionCount = 6;

  /// Her soruda "a" seçeneği deep-ocean'dır → hepsi 'a' = Deep Ocean.
  static const String allAnswersArchetype = 'deep-ocean';
  static const String allAnswersName = 'Deep Ocean';
  static const String allAnswersTagline =
      'You sink into stillness the moment your head hits the pillow.';
}
