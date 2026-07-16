import 'dart:math' as math;
import 'dart:typed_data';

/// Jeneratif ses motorunun DSP çekirdeği — **saf Dart, platformdan bağımsız**
/// (docs/04 core/audio_engine). Buradaki üreteçler referans/doğrulama
/// implementasyonudur: deterministiktir (seed'li) ve golden testlerle sabitlenir.
///
/// ⚠️ Bu katman henüz SES ÇALMAZ. Native graf (iOS AVAudioEngine / Android Oboe)
/// ve `AudioEngineFacade` ayrı gelir; bu dosya onların doğruluk ölçütüdür.
/// Golden test yaklaşımı docs/04 §80: birebir örnek eşitliği DEĞİL, istatistik
/// (RMS/DC/pürüzsüzlük) snapshot'ı — platform farkı toleransı için.

/// Deterministik sözde-rastgele üreteç (LCG). `Random` yerine kullanılır çünkü
/// golden testlerin Dart sürümünden bağımsız olarak tekrarlanabilir olması gerekir.
class _Lcg {
  _Lcg(int seed) : _state = (seed & 0x7fffffff) | 1;

  int _state;

  int _next() {
    _state = (_state * 1103515245 + 12345) & 0x7fffffff;
    return _state;
  }

  /// [-1, 1) aralığında uniform örnek.
  double nextBipolar() => (_next() / 0x7fffffff) * 2.0 - 1.0;
}

/// Beyaz gürültü: her örnek bağımsız uniform [-1, 1). Düz spektrum.
Float32List whiteNoise(int samples, {required int seed}) {
  final rng = _Lcg(seed);
  final out = Float32List(samples);
  for (var i = 0; i < samples; i++) {
    out[i] = rng.nextBipolar();
  }
  return out;
}

/// Kahverengi (Brownian) gürültü: beyazın **sızıntılı integrali** → düşük frekans
/// ağırlıklı, kulağa "derin"/yumuşak gelir. [leak] sıfıra yaklaştıkça daha koyu;
/// sızıntı DC kaymasını (drift) engeller. Çıkış tepe değeri 1'e normalize edilir.
Float32List brownNoise(int samples, {required int seed, double leak = 0.02}) {
  assert(leak > 0 && leak <= 1, 'leak (0,1] aralığında olmalı');
  final rng = _Lcg(seed);
  final out = Float32List(samples);
  var last = 0.0;
  var peak = 0.0;
  for (var i = 0; i < samples; i++) {
    last = last * (1 - leak) + rng.nextBipolar() * leak;
    out[i] = last;
    final a = last.abs();
    if (a > peak) peak = a;
  }
  if (peak > 0) {
    for (var i = 0; i < samples; i++) {
      out[i] = out[i] / peak;
    }
  }
  return out;
}

// --- Golden testlerin ölçtüğü istatistikler (docs/04 §80) ---

/// Kare ortalamanın karekökü — algılanan yükseklik göstergesi.
double rms(Float32List buffer) {
  if (buffer.isEmpty) return 0;
  var sum = 0.0;
  for (final s in buffer) {
    sum += s * s;
  }
  return math.sqrt(sum / buffer.length);
}

/// DC bileşeni (ortalama). Sağlıklı gürültüde ~0 olmalı; kayma hoparlörü zorlar.
double dcOffset(Float32List buffer) {
  if (buffer.isEmpty) return 0;
  var sum = 0.0;
  for (final s in buffer) {
    sum += s;
  }
  return sum / buffer.length;
}

/// Ardışık örnek farklarının ortalama mutlak değeri — **pürüzsüzlük** ölçütü.
/// FFT'siz spektral eğim vekili: küçük değer = düşük frekans ağırlıklı (brown),
/// büyük değer = geniş bant (white).
double meanAbsDelta(Float32List buffer) {
  if (buffer.length < 2) return 0;
  var sum = 0.0;
  for (var i = 1; i < buffer.length; i++) {
    sum += (buffer[i] - buffer[i - 1]).abs();
  }
  return sum / (buffer.length - 1);
}
