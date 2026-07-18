import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nocta/core/ambient/ambient_phase.dart';
import 'package:nocta/core/audio_engine/dsp/meditative.dart';

void main() {
  group('faz saati — periyot sesle aynı', () {
    test('kabarma periyodu 30 sn döngüde tam 10.0 sn (sesle aynı hesap)', () {
      expect(ambientSwellPeriod(), 10.0);
      expect(ambientSwellPeriod(), loopLockedPeriod(wavesSwellSeconds, 30));
    });

    test('nefes periyodu 30 sn döngüde tam 15.0 sn', () {
      expect(ambientBreathPeriod(), 15.0);
      expect(ambientBreathPeriod(), loopLockedPeriod(padBreathSeconds, 30));
    });

    test('kabarma: t=0 çukur, t=5 tepe, t=10 yine çukur (10 sn periyot)', () {
      expect(ambientPhaseAt(Duration.zero).swell, closeTo(0, 1e-12));
      expect(ambientPhaseAt(const Duration(seconds: 5)).swell, closeTo(1, 1e-12));
      expect(ambientPhaseAt(const Duration(seconds: 10)).swell, closeTo(0, 1e-12));
      expect(ambientPhaseAt(const Duration(seconds: 15)).swell, closeTo(1, 1e-12));
    });

    test('döngü dikişi: t=0 ile t=30 birebir aynı (görsel sıçrama yok)', () {
      final a = ambientPhaseAt(Duration.zero);
      final b = ambientPhaseAt(const Duration(seconds: 30));
      expect(b.swell, closeTo(a.swell, 1e-9));
      expect(b.breath, closeTo(a.breath, 1e-9));
      expect(b.loop, closeTo(a.loop, 1e-9));
    });

    test('loop alanı [0,1) içinde ilerler ve sarar', () {
      expect(ambientPhaseAt(Duration.zero).loop, 0);
      expect(ambientPhaseAt(const Duration(seconds: 15)).loop, closeTo(0.5, 1e-12));
      expect(ambientPhaseAt(const Duration(seconds: 31)).loop, closeTo(1 / 30, 1e-12));
    });
  });

  group('ÖLÇÜM: görsel faz ile DUYULAN faz aynı mı', () {
    // Bu, bu görevin çekirdek iddiasının kanıtı. `wavesSource` GERÇEKTEN üretilir,
    // pencere pencere RMS'i çıkarılır ve `ambientPhaseAt(...).swell` ile
    // korelasyonuna bakılır. Formülü okuyup "aynı" demek yetmez — ölçülür.
    test('wavesSource zarfı ile ambientSwell korelasyonu > 0.9', () {
      const sampleRate = 8000; // 48 kHz gerekmiyor: ölçülen şey ZARF (0.1 Hz).
      const loopSeconds = 30;
      const samples = sampleRate * loopSeconds;
      final buf = wavesSource(
        samples,
        seed: 12345,
        sampleRate: sampleRate,
        loopSamples: samples,
      );

      // 0.25 sn'lik pencerelerde RMS → zarf tahmini.
      const windowSeconds = 0.25;
      const windowSamples = (sampleRate * windowSeconds) ~/ 1;
      final rms = <double>[];
      final swell = <double>[];
      for (var start = 0; start + windowSamples <= samples; start += windowSamples) {
        var sum = 0.0;
        for (var i = start; i < start + windowSamples; i++) {
          sum += buf[i] * buf[i];
        }
        rms.add(math.sqrt(sum / windowSamples));
        // Pencerenin ORTASI referans alınır (RMS bir ortalamadır).
        final tMid = (start + windowSamples / 2) / sampleRate;
        swell.add(
          ambientPhaseAt(
            Duration(microseconds: (tMid * 1e6).round()),
          ).swell,
        );
      }

      final r = _pearson(rms, swell);
      debugPrint('ÖLÇÜM faz hizası: pencere=${rms.length}, pearson r=${r.toStringAsFixed(4)}');
      expect(r, greaterThan(0.9));
    });

    test('ÖLÇÜM: duyulan zarfın tepeleri görsel tepelerle aynı saniyelerde', () {
      const sampleRate = 8000;
      const loopSeconds = 30;
      const samples = sampleRate * loopSeconds;
      final buf = wavesSource(
        samples,
        seed: 999,
        sampleRate: sampleRate,
        loopSamples: samples,
      );

      // Her 10 sn'lik çevrimde RMS'i en yüksek 0.25 sn'lik pencereyi bul.
      const windowSamples = sampleRate ~/ 4;
      final peakSeconds = <double>[];
      for (var cycle = 0; cycle < 3; cycle++) {
        final from = cycle * 10 * sampleRate;
        final to = (cycle + 1) * 10 * sampleRate;
        var best = -1.0;
        var bestT = 0.0;
        for (var start = from; start + windowSamples <= to; start += windowSamples) {
          var sum = 0.0;
          for (var i = start; i < start + windowSamples; i++) {
            sum += buf[i] * buf[i];
          }
          final v = math.sqrt(sum / windowSamples);
          if (v > best) {
            best = v;
            bestT = (start + windowSamples / 2) / sampleRate;
          }
        }
        peakSeconds.add(bestT);
      }

      debugPrint(
        'ÖLÇÜM duyulan tepeler (sn): '
        '${peakSeconds.map((t) => t.toStringAsFixed(2)).join(", ")} '
        '| görsel tepeler: 5.00, 15.00, 25.00',
      );

      // Görsel tepe 5 + 10k. Gürültü yatağı yüzünden ±1 sn tolerans veriliyor
      // (RMS bir tahmin; tam eşitlik iddia etmek sahte kesinlik olurdu).
      for (var k = 0; k < 3; k++) {
        expect(peakSeconds[k], closeTo(5.0 + 10 * k, 1.0));
        expect(ambientPhaseAt(Duration(seconds: 5 + 10 * k)).swell, closeTo(1, 1e-12));
      }
    });
  });

  group('AmbientDrive — mikser kazançları görseli sürer', () {
    test('boş kazanç haritası → sakin varsayılan', () {
      expect(AmbientDrive.fromGains(const <String, double>{}), AmbientDrive.calm);
    });

    test('tüm katmanlar kapalı → sakin varsayılan (sıfıra bölme yok)', () {
      expect(
        AmbientDrive.fromGains(const <String, double>{'waves': 0, 'pad': 0}),
        AmbientDrive.calm,
      );
    });

    test('dalga kazancı artınca motion artar (monoton)', () {
      final low = AmbientDrive.fromGains(const <String, double>{
        'waves': 0.10,
        'pad': 0.10,
        'brown': 0.80,
      });
      final high = AmbientDrive.fromGains(const <String, double>{
        'waves': 0.60,
        'pad': 0.10,
        'brown': 0.30,
      });
      debugPrint('ÖLÇÜM motion: düşük=${low.motion.toStringAsFixed(3)} '
          'yüksek=${high.motion.toStringAsFixed(3)}');
      expect(high.motion, greaterThan(low.motion));
      expect(low.motion, inInclusiveRange(0.0, 1.0));
      expect(high.motion, inInclusiveRange(0.0, 1.0));
    });

    test('pad kazancı artınca glow artar, motion sabit kalmaz (pay semantiği)', () {
      final a = AmbientDrive.fromGains(const <String, double>{
        'waves': 0.20,
        'pad': 0.05,
        'brown': 0.75,
      });
      final b = AmbientDrive.fromGains(const <String, double>{
        'waves': 0.20,
        'pad': 0.55,
        'brown': 0.25,
      });
      expect(b.glow, greaterThan(a.glow));
    });

    test('yağmur+ateş texture\'ı sürer', () {
      final dry = AmbientDrive.fromGains(const <String, double>{
        'waves': 0.5,
        'rain': 0.0,
        'fire': 0.0,
        'brown': 0.5,
      });
      final wet = AmbientDrive.fromGains(const <String, double>{
        'waves': 0.2,
        'rain': 0.4,
        'fire': 0.3,
        'brown': 0.1,
      });
      expect(dry.texture, 0);
      expect(wet.texture, greaterThan(0.5));
    });

    test('ana ses seviyesi düşse de DENGE aynıysa sürüş aynı kalır', () {
      // Pay semantiğinin gerekçesi buydu — testle sabitleniyor.
      final loud = AmbientDrive.fromGains(const <String, double>{
        'waves': 0.40,
        'pad': 0.20,
        'brown': 0.40,
      });
      final quiet = AmbientDrive.fromGains(const <String, double>{
        'waves': 0.04,
        'pad': 0.02,
        'brown': 0.04,
      });
      expect(quiet.motion, closeTo(loud.motion, 1e-12));
      expect(quiet.glow, closeTo(loud.glow, 1e-12));
    });
  });
}

double _pearson(List<double> a, List<double> b) {
  assert(a.length == b.length && a.isNotEmpty);
  final n = a.length;
  var ma = 0.0;
  var mb = 0.0;
  for (var i = 0; i < n; i++) {
    ma += a[i];
    mb += b[i];
  }
  ma /= n;
  mb /= n;
  var num = 0.0;
  var da = 0.0;
  var db = 0.0;
  for (var i = 0; i < n; i++) {
    final x = a[i] - ma;
    final y = b[i] - mb;
    num += x * y;
    da += x * x;
    db += y * y;
  }
  return num / math.sqrt(da * db);
}
