import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tüm testlerden ÖNCE çalışır (Flutter'ın `flutter_test_config.dart` sözleşmesi).
///
/// ## Golden'lar için TOLERANSLI karşılaştırıcı — neden gerekli
///
/// Golden PNG'leri geliştirme makinesinde (Windows) üretiliyor, CI'da (Linux)
/// karşılaştırılıyor. Aynı widget iki platformda **birebir aynı piksel** vermiyor:
/// anti-aliasing, yazı tipi rasterleştirme ve alpha karışımı ufak farklar üretiyor.
/// Gece raporu kartı bunu somut olarak gösterdi:
///
///     Pixel test failed, 0.24%, 5076px diff detected.
///
/// Kimlik kartı (#140) geçiyordu çünkü düz metin + gradyan; gece makbuzunda
/// `Divider` çizgileri ve yuvarlak köşeler var — AA'ya duyarlı olan tam bu şeyler.
///
/// ## Eşik neden %0.5
///
/// Gözlenen platform farkı **%0.24**. Gerçek bir tasarım değişikliği (satır kayması,
/// yazı boyutu, renk) yüzde BİRKAÇ üretir — mertebe farkı var. %0.5, platform
/// gürültüsünün iki katı ama gerçek regresyonun çok altında.
///
/// **Dürüst sınır:** bu eşik, çok küçük bir gerçek değişikliği (ör. bir pikselin
/// tonu) kaçırabilir. Alternatif, CI'da golden'ı hiç koşturmamaktı — o zaman
/// tasarım regresyonu HİÇ yakalanmazdı. Toleranslı bir kapı, kapalı bir kapıdan iyi.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  // `basedir` MEVCUT karşılaştırıcıdan alınır: bu dosya her test DOSYASI için bir kez
  // çalışır ve o an `goldenFileComparator` doğru dizini biliyor. Kendi Uri'mizi
  // uydurmak golden'ları "dosya yok" hatasına düşürüyordu.
  final previous = goldenFileComparator as LocalFileComparator;
  goldenFileComparator = _ToleranceComparator(
    Uri.parse('${previous.basedir}golden_anchor_test.dart'),
    tolerance: 0.005, // %0.5
  );
  await testMain();
}

class _ToleranceComparator extends LocalFileComparator {
  _ToleranceComparator(super.testFile, {required this.tolerance});

  /// Kabul edilen maksimum piksel farkı oranı (0.005 = %0.5).
  final double tolerance;

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );

    if (result.passed || result.diffPercent <= tolerance) return true;

    // Eşiği aşan fark SESSİZCE geçmez — hata mesajı gerçek oranı yazar ki
    // "platform gürültüsü mü, regresyon mu?" sorusu cevaplanabilsin.
    final error = await generateFailureOutput(result, golden, basedir);
    throw FlutterError(error);
  }
}
