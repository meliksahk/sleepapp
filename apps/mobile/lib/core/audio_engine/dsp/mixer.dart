import 'dart:math' as math;
import 'dart:typed_data';

/// Katman mikseri (docs/04 mikser) — birden çok kaynağı kazançlarıyla toplar.
///
/// **Kazanç rampası (asıl mesele):** kazancı bir örnekten diğerine sıçratmak
/// dalga formunda süreksizlik yaratır → duyulur **tık** ("zipper noise").
/// Kullanıcı mikser sürgüsünü çektiğinde bu olur. Bu yüzden kazançlar hedefe
/// [rampMs] boyunca **doğrusal** yürür; her `mixInto` çağrısı kaldığı yerden
/// devam eder (durumlu → native grafın parçalı callback'lerinde de doğru).
///
/// **Headroom:** kazanç toplamı 1'i aşarsa toplam kırpılabilir. Mikser son çare
/// olarak [-1,1]'e **clamp** eder ve [clippedSamples] ile bunu **raporlar** —
/// sessizce bozmaz; çağıran headroom'u yönetmelidir.
class Mixer {
  Mixer({this.sampleRate = 48000, this.rampMs = 20})
    : assert(sampleRate > 0),
      assert(rampMs > 0);

  final int sampleRate;

  /// Kazancın 0→1 yürümesi için geçen süre (ms). 20 ms tık duyulmaz eşiğin altı.
  final double rampMs;

  final Map<String, double> _current = <String, double>{};
  final Map<String, double> _target = <String, double>{};
  int _clipped = 0;

  /// Clamp'lenen (kırpılan) örnek sayısı — headroom teşhisi için.
  int get clippedSamples => _clipped;

  /// Kazancın o an ulaştığı değer (rampa sürüyorsa hedeften farklı olabilir).
  double gainOf(String layerId) => _current[layerId] ?? 0.0;

  /// Hedef kazanç [0,1]. [immediate] true ise rampa atlanır (ilk kurulum/preset
  /// yükleme; çalarken kullanılırsa tık riski vardır). Katman ilk kez tanıtılıyorsa
  /// mevcut kazanç 0'dan başlar → sessizden içeri yumuşak girer.
  void setGain(String layerId, double target, {bool immediate = false}) {
    final t = target.clamp(0.0, 1.0);
    _target[layerId] = t;
    if (immediate) {
      _current[layerId] = t;
    } else {
      _current.putIfAbsent(layerId, () => 0.0);
    }
  }

  /// Filtre/rampa durumunu sıfırlar (yeni çalma oturumu).
  void reset() {
    _current.clear();
    _target.clear();
    _clipped = 0;
  }

  /// [layers] içindeki buffer'ları kazançlarıyla toplayıp [out]'a yazar (yerinde).
  /// Her buffer en az [out].length uzunluğunda olmalı.
  void mixInto(Float32List out, Map<String, Float32List> layers) {
    final n = out.length;
    final step = 1.0 / (rampMs / 1000.0 * sampleRate); // örnek başına kazanç deltası

    for (var i = 0; i < n; i++) {
      out[i] = 0.0;
    }

    for (final entry in layers.entries) {
      final buf = entry.value;
      assert(buf.length >= n, 'katman buffer’ı çıkıştan kısa: ${entry.key}');
      var g = _current[entry.key] ?? 0.0;
      final t = _target[entry.key] ?? 0.0;
      for (var i = 0; i < n; i++) {
        if (g < t) {
          g = math.min(t, g + step);
        } else if (g > t) {
          g = math.max(t, g - step);
        }
        out[i] += buf[i] * g;
      }
      _current[entry.key] = g;
    }

    for (var i = 0; i < n; i++) {
      if (out[i] > 1.0) {
        out[i] = 1.0;
        _clipped++;
      } else if (out[i] < -1.0) {
        out[i] = -1.0;
        _clipped++;
      }
    }
  }
}
