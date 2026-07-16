import 'dart:math' as math;
import 'dart:typed_data';

/// DC engelleyici (tek kutuplu yüksek geçiren) — #95'te ölçülen pembe gürültü
/// artık DC'sini (dc≈-0.036) kaynağında temizler. DC, duyulmaz ama headroom
/// yer ve hoparlör bobinini sabit ofsette tutar → kırpma + gereksiz ısı.
///
/// **Neden bu, "buffer ortalamasını çıkar" değil:** ortalama çıkarma tüm buffer'ı
/// görmeyi gerektirir; native graf (AVAudioEngine/Oboe) sesi **parça parça**
/// (128–1024 örneklik callback'ler) işler. Bu filtre **durumludur** (`_x1`,`_y1`),
/// yani ardışık parçalarda kaldığı yerden devam eder ve tek seferlik işlemeyle
/// **birebir aynı** sonucu verir (testle sabitlendi) → native'e birebir taşınabilir.
///
/// Fark denklemi: `y[n] = x[n] - x[n-1] + R·y[n-1]`
///
/// ⚠️ ÖLÇÜM UYARISI (#100'de bulundu): "DC" bir **pencere ortalamasıyla** ölçülür
/// ve bu istatistik kısa pencerede gürültülüdür. Pembe+kahverengi mix ölçümü:
/// 1sn → 0.0086, 2sn → 0.0030, 5sn → 0.00002, 10sn → 0.00019. Yani 5 sn'deki
/// çok küçük değer **evrensel garanti değil**, o pencereye özgü bir örnektir.
/// Filtre ≥3.8 Hz altını gerçekten söndürür (sabit-DC testi 0.00000 verir), ama
/// kısa pencerede 1/f'in çok düşük frekans artığı ortalamaya sızar.
/// Sonuç: DC iddiaları **ölçüldüğü pencerede** yapılmalı; kısa pencerede DC
/// eşiği regresyon bekçisi olarak ANLAMSIZDIR (ham sinyalinki bazen daha küçük).
class DcBlocker {
  /// [r] kutup yarıçapı; 1'e ne kadar yakınsa kesim frekansı o kadar düşük.
  /// Varsayılan 0.9995 → 48 kHz'de ≈ 3.8 Hz: DC gider, bas duyulur biçimde kalır.
  DcBlocker({this.r = 0.9995}) : assert(r > 0 && r < 1, 'r (0,1) aralığında olmalı');

  final double r;

  double _x1 = 0.0;
  double _y1 = 0.0;

  /// Yaklaşık -3 dB kesim frekansı (Hz) — belgeleme/doğrulama için.
  double cutoffHz(int sampleRate) => (1 - r) * sampleRate / (2 * math.pi);

  /// Filtre durumunu sıfırlar (yeni bir çalma oturumu başlarken).
  void reset() {
    _x1 = 0.0;
    _y1 = 0.0;
  }

  /// [buffer]'ı **yerinde** işler. Ardışık çağrılar durumu sürdürür (streaming).
  void process(Float32List buffer) {
    var x1 = _x1;
    var y1 = _y1;
    for (var i = 0; i < buffer.length; i++) {
      final x = buffer[i].toDouble();
      final y = x - x1 + r * y1;
      x1 = x;
      y1 = y;
      buffer[i] = y;
    }
    _x1 = x1;
    _y1 = y1;
  }
}
