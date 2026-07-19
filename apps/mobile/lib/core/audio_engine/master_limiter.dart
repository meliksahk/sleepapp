/// Master limitleyici — toplam çıkış seviyesinin tavanı ve ölçek matematiği.
///
/// **NEDEN AYRI DOSYA:** aynı tavan iki ayrı yerde uygulanıyor ve ikisi de
/// birbirinden habersiz kendi sabitini taşıyordu:
///
/// 1. `soundscape_mix.limitTotalGain` — SUNUCUDAN gelen tarifi çalmadan önce
///    normalize eder (tarif 3 katman × 1.0 verebilir).
/// 2. `MixPlayer` — KULLANICININ sürgüleriyle oluşan toplamı çalarken sınırlar.
///
/// Sabiti tek yerde tutmak, ikisinin birbirinden kayma ihtimalini kapatır.
/// Burası saf Dart: Flutter/IO importu yok (CLAUDE.md §3.1 domain kuralı).
library;

/// İzin verilen toplam çıkış kazancı.
///
/// **NEDEN 1.0 ve neden bu bir tahmin değil:** `MixPlayer` katmanları AYRI
/// `AudioPlayer`'larda çalar; toplama İŞLETİM SİSTEMİ mikserinde olur ve orada
/// ne clamp ne de kırpma raporu vardır (`Mixer.clippedSamples` yalnızca Dart
/// toplama yolunda, yani `renderMix`/video export'ta çalışır).
///
/// Ölçüm (bu kusuru açan ölçüm): 7 sentez katmanı tam kazançta toplandığında
/// örneklerin **%14.1'i** [-1,1] dışına çıkıyor, tepe **1.333**. Varsayılan
/// mikste (toplam 1.00) tepe 0.703 — kırpma yok. Yani sınır tam da toplam
/// kazancın 1.0'ı aştığı yerde gerekiyor.
const double kMasterCeiling = 1.0;

/// [totalGain] için uygulanacak master ölçek katsayısı.
///
/// Dönüş 1.0 → limitleyici DEVREDE DEĞİL. 1.0'dan küçük → tüm katmanlar bu
/// katsayıyla çarpılır; katmanların BİRBİRİNE oranı korunur, yalnızca mutlak
/// seviye iner (gerçek mikserlerin master limiter'ı gibi).
///
/// Katmanları tek tek kısmak (ör. en yükseği geri çekmek) mix'in karakterini
/// bozardı — kullanıcı "yağmuru kıstım mı?" diye sürgüye bakar, sürgü yerinde
/// durur, ses başka türlü gelir. Oransal ölçek bu yalanı üretmez.
double masterLimiterScale(double totalGain) {
  if (totalGain <= kMasterCeiling || totalGain <= 0) return 1.0;
  return kMasterCeiling / totalGain;
}

/// Limitleyici bu ölçekte "devrede" sayılır mı.
///
/// Kayan nokta toleransı ile: 0.9999999 bir limit değil, yuvarlama artığıdır ve
/// kullanıcıya gösterge göstermeyi hak etmez.
bool isLimiterEngaged(double scale) => scale < 1.0 - 1e-6;
