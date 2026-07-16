import 'dart:math' as math;
import 'dart:typed_data';

/// dB zarfı — mikrofon çerçevesi → dBFS (docs/04 §85: "dB zarfı + basit olay
/// sınıflandırması").
///
/// **NEDEN dB, NEDEN HAM GENLİK DEĞİL:** işitme logaritmiktir ve gece sesleri
/// çok geniş bir aralığa yayılır (sessiz oda ~ -60 dBFS, horlama ~ -20 dBFS).
/// Doğrusal genlikte "iki kat" eşiği sessiz odada saçma, gürültülü odada duyarsız
/// olurdu; dB'de fark her seviyede aynı anlama gelir.
///
/// **GİZLİLİK (CLAUDE.md §6, docs/04 §85):** buradan çıkan tek şey bir SAYIDIR.
/// Ham ses diske bile yazılmaz; çağıran RAM ring buffer kullanır ve yalnızca bu
/// skaler zarfı saklar. Zarftan konuşma yeniden kurulamaz — mikrofon iznimizin
/// savunma hattı budur.

/// Tam sessizlik için taban. -inf yerine sonlu bir değer: sonsuz, aşağıdaki tüm
/// aritmetiği (ortalama, eşik) zehirlerdi.
const double silenceDbfs = -100.0;

/// Bir çerçevenin RMS'ini dBFS'e çevirir. Girdi [-1,1] normalize PCM.
///
/// 0 dBFS = tam ölçek sinüs değil, tam ölçek RMS (1.0). Mutlak kalibrasyon
/// (dB SPL) YAPILMAZ: mikrofon hassasiyeti cihazdan cihaza değişir ve bizim
/// ihtiyacımız mutlak ses düzeyi değil, KENDİ tabanına göre DEĞİŞİM.
double frameDbfs(Float32List frame) {
  if (frame.isEmpty) return silenceDbfs;

  var sumSquares = 0.0;
  for (final sample in frame) {
    sumSquares += sample * sample;
  }
  final rms = math.sqrt(sumSquares / frame.length);
  if (rms <= 0) return silenceDbfs;

  final db = 20 * (math.log(rms) / math.ln10);
  // Taban altı değerler (çok küçük ama sıfır olmayan gürültü) sonsuza gitmesin.
  return db < silenceDbfs ? silenceDbfs : db;
}
