import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:nocta/core/audio_engine/dsp/noise.dart';

/// DSP golden testleri (docs/04 §80): 5 sn'lik buffer'ın **istatistik** snapshot'ı
/// — birebir örnek eşitliği DEĞİL (platform farkı toleransı). Aşağıdaki beklenen
/// değerler implementasyondan ÖLÇÜLEREK alındı (uydurulmadı) ve DSP davranışını
/// sabitler: üreteç değişirse bu testler kırmızıya döner.
const _sampleRate = 48000;
const _seconds = 5;
const _samples = _sampleRate * _seconds;

double _peak(List<double> b) {
  var p = 0.0;
  for (final s in b) {
    if (s.abs() > p) p = s.abs();
  }
  return p;
}

void main() {
  group('determinizm (golden testlerin ön koşulu)', () {
    test('aynı seed → birebir aynı buffer', () {
      expect(whiteNoise(1000, seed: 7), equals(whiteNoise(1000, seed: 7)));
      expect(brownNoise(1000, seed: 7), equals(brownNoise(1000, seed: 7)));
    });

    test('farklı seed → farklı buffer', () {
      expect(whiteNoise(1000, seed: 7), isNot(equals(whiteNoise(1000, seed: 8))));
    });
  });

  group('beyaz gürültü golden (5 sn @ 48kHz, seed 42)', () {
    final w = whiteNoise(_samples, seed: 42);

    test('RMS teorik 1/√3 değerine oturur', () {
      expect(rms(w), closeTo(1 / math.sqrt(3), 0.02)); // ölçülen 0.5763
    });

    test('DC kayması yok (hoparlörü zorlamaz)', () {
      expect(dcOffset(w).abs(), lessThan(0.01)); // ölçülen 0.0002
    });

    test('pürüzsüzlük snapshot (geniş bant)', () {
      expect(meanAbsDelta(w), closeTo(0.665, 0.03));
    });

    test('örnekler [-1, 1] içinde', () {
      expect(_peak(w), lessThanOrEqualTo(1.0));
    });
  });

  group('kahverengi gürültü golden (5 sn @ 48kHz, seed 42)', () {
    final b = brownNoise(_samples, seed: 42);

    test('RMS snapshot', () {
      expect(rms(b), closeTo(0.252, 0.02));
    });

    test('DC kayması yok (sızıntı drift’i engelliyor)', () {
      expect(dcOffset(b).abs(), lessThan(0.01)); // ölçülen 0.0007
    });

    test('tepe 1.0’a normalize (kırpma yok)', () {
      expect(_peak(b), closeTo(1.0, 1e-6));
    });

    test('pürüzsüzlük snapshot (düşük frekans ağırlıklı)', () {
      expect(meanAbsDelta(b), closeTo(0.0433, 0.01));
    });

    test('beyazdan belirgin daha pürüzsüz (spektral eğim vekili)', () {
      final w = whiteNoise(_samples, seed: 42);
      // ölçülen oran ~15x; 5x eşiği regresyonu yakalar, gürültüye takılmaz.
      expect(meanAbsDelta(b), lessThan(meanAbsDelta(w) / 5));
    });
  });

  group('pembe gürültü golden (5 sn @ 48kHz, seed 42)', () {
    final p = pinkNoise(_samples, seed: 42);

    test('RMS snapshot', () {
      expect(rms(p), closeTo(0.228, 0.02));
    });

    test('pürüzsüzlük snapshot (1/f)', () {
      expect(meanAbsDelta(p), closeTo(0.095, 0.02));
    });

    test('tepe 1.0’a normalize (kırpma yok)', () {
      expect(_peak(p), closeTo(1.0, 1e-6));
    });

    test('artık DC beklenen sınırda (1/f doğası — çalmada high-pass gerekir)', () {
      // white/brown ≈0.000; pembede ölçülen -0.036. Bu HATA DEĞİL: en yavaş satır
      // 32768 örnekte bir yenilenir → sonlu pencerede düşük frekans DC gibi görünür.
      // Eşik gerçeği yansıtır; sessizce gevşetilmiş bir tolerans değil (bkz. noise.dart).
      expect(dcOffset(p).abs(), lessThan(0.05));
    });

    test('spektral eğim 1/f: beyaz > pembe > kahverengi (asıl özellik)', () {
      final w = whiteNoise(_samples, seed: 42);
      final b = brownNoise(_samples, seed: 42);
      final mw = meanAbsDelta(w), mp = meanAbsDelta(p), mb = meanAbsDelta(b);
      expect(mw, greaterThan(mp)); // pembe beyazdan koyu
      expect(mp, greaterThan(mb)); // ama kahverengiden parlak
    });

    test('determinizm: aynı seed → birebir aynı', () {
      expect(pinkNoise(1000, seed: 7), equals(pinkNoise(1000, seed: 7)));
    });
  });

  group('istatistik yardımcıları — sınır durumları', () {
    test('boş buffer → 0', () {
      final empty = whiteNoise(0, seed: 1);
      expect(rms(empty), 0);
      expect(dcOffset(empty), 0);
      expect(meanAbsDelta(empty), 0);
    });

    test('tek örnek → delta 0', () {
      expect(meanAbsDelta(whiteNoise(1, seed: 1)), 0);
    });
  });
}
