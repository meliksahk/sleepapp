import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nocta/core/audio_engine/dsp/mix_loop.dart';
import 'package:nocta/core/audio_engine/dsp/mix_render.dart';

/// Sorunsuz döngü crossfade'i (#170) — mikserin **döngü tıkının** giderildiğini
/// cihazsız kanıtlar. "Tık duyulmuyor" kulakla doğrulanır; buradaki testler
/// SÜREKSİZLİĞİN SAYISAL olarak yok olduğunu (dikiş adımı ≈ iç adım) kilitler.
void main() {
  const sr = 48000;
  const loopSeconds = 2;
  const n = sr * loopSeconds;

  MixSpec spec(LayerSource t) => MixSpec([MixLayer(id: 'a', type: t, gain: 1.0)]);

  /// Döngü dikişindeki adım: son örnekten ilk örneğe (buffer kendine eklenince).
  double seamStep(Float32List b) => (b[0] - b[b.length - 1]).abs();

  /// İç adımların [p] yüzdelik dilimi (ör. 0.999 → uçtaki normal sıçramalar).
  double interiorPercentile(Float32List b, double p) {
    final steps = <double>[];
    for (var i = 1; i < b.length; i++) {
      steps.add((b[i] - b[i - 1]).abs());
    }
    steps.sort();
    return steps[(steps.length * p).clamp(0, steps.length - 1).toInt()];
  }

  double rms(Float32List b, int from, int to) {
    var sum = 0.0;
    for (var i = from; i < to; i++) {
      sum += b[i] * b[i];
    }
    return math.sqrt(sum / (to - from));
  }

  group('döngü dikişi sürekliliği', () {
    test('ÇEKİRDEK: KAHVERENGİ gürültüde dikiş sıçraması ham render\'a göre ÇÖKER', () {
      // Kahverengi gürültü integre edilmiş (rastgele yürüyüş) → düz render'da
      // buffer'ın iki ucu birbirinden UZAK; dikiş = büyük bir sıçrama (tık).
      final plain = renderMix(spec(LayerSource.brown),
          seconds: loopSeconds, sampleRate: sr, seed: 3);
      final seamless = renderSeamlessLoop(spec(LayerSource.brown),
          loopSeconds: loopSeconds, sampleRate: sr, seed: 3);

      final plainSeam = seamStep(plain);
      final seamlessSeam = seamStep(seamless);

      // Crossfade dikişi kurgusal olarak sürekli kılar → sıçrama çarpıcı biçimde küçülür.
      expect(seamlessSeam, lessThan(plainSeam * 0.2),
          reason: 'crossfade dikiş sıçramasını en az 5× küçültmeli');
      // Ve dikiş, normal bir İÇ adımdan büyük olmamalı: yani artık "anormal" değil.
      expect(seamlessSeam, lessThanOrEqualTo(interiorPercentile(seamless, 0.999)),
          reason: 'dikiş adımı iç adımların %99.9 diliminden büyük olmamalı');
    });

    test('ÇEKİRDEK: PEMBE gürültüde de dikiş iç adım profiline oturur', () {
      final seamless = renderSeamlessLoop(spec(LayerSource.pink),
          loopSeconds: loopSeconds, sampleRate: sr, seed: 7);
      expect(seamStep(seamless), lessThanOrEqualTo(interiorPercentile(seamless, 0.999)));
    });
  });

  group('eşit-güç: ses seviyesi harman bölgesinde DÜŞMEZ', () {
    test('ÇEKİRDEK: crossfade bölgesi RMS\'i düz bölge RMS\'ine yakın (lineer olsa ~3dB düşerdi)', () {
      final b = renderSeamlessLoop(spec(LayerSource.white),
          loopSeconds: loopSeconds, sampleRate: sr, seed: 11);
      final x = (0.050 * sr).round(); // varsayılan 50ms crossfade
      final blendRms = rms(b, 0, x);
      final plainRms = rms(b, x, 2 * x);
      // Eşit-güç → korelasyonsuz gürültüde güç sabit. Lineer crossfade olsaydı
      // harman ortasında ~%30 (3 dB) düşüş olurdu; %20 tolerans onu ELER.
      expect((blendRms - plainRms).abs() / plainRms, lessThan(0.2),
          reason: 'eşit-güç harmanda RMS düşüşü olmamalı');
    });
  });

  group('güvenlik ve belirlenimcilik', () {
    test('uzunluk tam olarak loopSeconds×sampleRate', () {
      final b = renderSeamlessLoop(spec(LayerSource.pink),
          loopSeconds: loopSeconds, sampleRate: sr, seed: 1);
      expect(b.length, n);
    });

    test('ÇEKİRDEK: crossfade bölgesi [-1,1] içinde (√2 toplam taşması clamp\'lenir)', () {
      // Eşit-güç toplamı √2'ye çıkabilir; clamp yalnızca HARMAN bölgesini bağlar.
      final x = (0.050 * sr).round();
      for (final t in LayerSource.values) {
        final b = renderSeamlessLoop(spec(t),
            loopSeconds: loopSeconds, sampleRate: sr, seed: 42);
        for (var i = 0; i < x; i++) {
          expect(b[i], inInclusiveRange(-1.0, 1.0),
              reason: '$t harman bölgesi örnek $i taşmamalı');
        }
      }
    });

    test('ÇEKİRDEK: crossfade YENİ tepe üretmez — ham render sınırını aşmaz', () {
      // renderMix çıkışı DcBlocker (mikser clamp\'inden SONRA) yüzünden zaten
      // ~±1.01 olabilir (mevcut davranış). Crossfade+clamp bu tepeyi BÜYÜTMEMELİ.
      final x = (0.050 * sr).round();
      double maxAbs(Float32List b) {
        var m = 0.0;
        for (final v in b) {
          if (v.abs() > m) m = v.abs();
        }
        return m;
      }

      for (final t in LayerSource.values) {
        final raw = renderMix(spec(t),
            seconds: loopSeconds, sampleRate: sr, seed: 42, extraSamples: x);
        final seamless = renderSeamlessLoop(spec(t),
            loopSeconds: loopSeconds, sampleRate: sr, seed: 42);
        expect(maxAbs(seamless), lessThanOrEqualTo(maxAbs(raw) + 1e-6),
            reason: '$t: crossfade ham render tepesinden büyük tepe üretmemeli');
      }
    });

    test('aynı seed → birebir aynı buffer (belirlenimci)', () {
      final a = renderSeamlessLoop(spec(LayerSource.brown),
          loopSeconds: loopSeconds, sampleRate: sr, seed: 9);
      final b = renderSeamlessLoop(spec(LayerSource.brown),
          loopSeconds: loopSeconds, sampleRate: sr, seed: 9);
      expect(a, equals(b));
    });

    test('crossfade=0 → düz render\'a düşer (sessiz "sorunsuz" yalanı yok)', () {
      final seamless = renderSeamlessLoop(spec(LayerSource.white),
          loopSeconds: loopSeconds, sampleRate: sr, seed: 5, crossfade: Duration.zero);
      final plain =
          renderMix(spec(LayerSource.white), seconds: loopSeconds, sampleRate: sr, seed: 5);
      expect(seamless, equals(plain));
    });
  });
}
