import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:nocta/core/audio_engine/dsp/mixer.dart';
import 'package:nocta/core/audio_engine/dsp/noise.dart';

/// Mikser testleri. Beklenen değerler implementasyondan ÖLÇÜLEREK alındı.
const _sampleRate = 48000;

Float32List _const(int n, double v) => Float32List(n)..fillRange(0, n, v);

double _maxDelta(Float32List b) {
  var m = 0.0;
  for (var i = 1; i < b.length; i++) {
    final d = (b[i] - b[i - 1]).abs();
    if (d > m) m = d;
  }
  return m;
}

void main() {
  test('tek katman, kazanç 1.0 (immediate) → çıkış girişe eşit', () {
    final src = whiteNoise(1000, seed: 5);
    final m = Mixer()..setGain('a', 1.0, immediate: true);
    final out = Float32List(1000);
    m.mixInto(out, {'a': src});
    expect(out, equals(src));
  });

  test('iki katman kazançlarıyla toplanır (0.5 + 0.5)', () {
    final ones = _const(100, 1.0);
    final m = Mixer()
      ..setGain('a', 0.5, immediate: true)
      ..setGain('b', 0.5, immediate: true);
    final out = Float32List(100);
    m.mixInto(out, {'a': ones, 'b': ones});
    expect(out.first, closeTo(1.0, 1e-6));
    expect(m.clippedSamples, 0);
  });

  group('kazanç rampası (zipper noise / tık önleme — asıl mesele)', () {
    test('rampalı geçişte örnek-arası sıçrama ≈ 1/960 (tık yok)', () {
      const n = 4800; // 100 ms
      final ones = _const(n, 1.0);
      final m = Mixer(sampleRate: _sampleRate) // rampMs=20 → 960 örnek
        ..setGain('a', 0.0, immediate: true)
        ..setGain('a', 1.0); // rampalı hedef
      final out = Float32List(n);
      m.mixInto(out, {'a': ones});

      // ölçülen 0.00104 = 1/960. Tam ölçekli sıçramanın ~960'ta biri.
      expect(_maxDelta(out), closeTo(1 / 960, 1e-4));
      expect(_maxDelta(out), lessThan(0.01)); // duyulur tık eşiğinin çok altı
    });

    test('rampa hedefe ulaşır', () {
      final ones = _const(4800, 1.0);
      final m = Mixer()
        ..setGain('a', 0.0, immediate: true)
        ..setGain('a', 1.0);
      m.mixInto(Float32List(4800), {'a': ones});
      expect(m.gainOf('a'), closeTo(1.0, 1e-9)); // 960 örnek < 4800 → ulaşmış
    });

    test('KARŞILAŞTIRMA: immediate ani sıçrama üretir (rampanın önlediği şey)', () {
      const n = 480;
      final ones = _const(n, 1.0);
      final m = Mixer()..setGain('a', 0.0, immediate: true);
      final quiet = Float32List(n);
      m.mixInto(quiet, {'a': ones});

      m.setGain('a', 1.0, immediate: true); // ANİ — rampa atlanır
      final loud = Float32List(n);
      m.mixInto(loud, {'a': ones});

      // Buffer sınırında tam ölçekli süreksizlik = duyulur tık (ölçülen 1.00000).
      expect((loud.first - quiet.last).abs(), closeTo(1.0, 1e-6));
    });

    test('yeni katman sessizden yumuşak girer (varsayılan kazanç 0)', () {
      final ones = _const(480, 1.0);
      final m = Mixer()..setGain('a', 1.0); // immediate YOK → 0'dan rampalar
      final out = Float32List(480);
      m.mixInto(out, {'a': ones});
      expect(out.first, lessThan(0.01)); // sessizden başlar
      expect(_maxDelta(out), lessThan(0.01)); // tık yok
    });
  });

  test('headroom aşımı clamp’lenir VE raporlanır (sessizce bozmaz)', () {
    final ones = _const(1000, 1.0);
    final m = Mixer()
      ..setGain('a', 1.0, immediate: true)
      ..setGain('b', 1.0, immediate: true);
    final out = Float32List(1000);
    m.mixInto(out, {'a': ones, 'b': ones}); // toplam 2.0 → kırpılır

    expect(out.every((s) => s.abs() <= 1.0), isTrue);
    expect(m.clippedSamples, 1000); // ölçülen: tüm örnekler
  });

  test('STREAMING DENKLİĞİ: parçalı mixInto = tek seferde (rampa durumu sürer)', () {
    const n = 4800;
    final src = whiteNoise(n, seed: 11);

    final one = Mixer()
      ..setGain('a', 0.0, immediate: true)
      ..setGain('a', 1.0);
    final oneOut = Float32List(n);
    one.mixInto(oneOut, {'a': src});

    final chunked = Mixer()
      ..setGain('a', 0.0, immediate: true)
      ..setGain('a', 1.0);
    final chunkOut = Float32List(n);
    for (var off = 0; off < n; off += 128) {
      final len = math.min(128, n - off);
      final part = Float32List.view(chunkOut.buffer, off * 4, len);
      chunked.mixInto(part, {'a': Float32List.sublistView(src, off, off + len)});
    }

    expect(chunkOut, equals(oneOut));
  });

  test('setGain kazancı [0,1] aralığına sıkıştırır', () {
    final m = Mixer()
      ..setGain('a', 5.0, immediate: true)
      ..setGain('b', -3.0, immediate: true);
    expect(m.gainOf('a'), 1.0);
    expect(m.gainOf('b'), 0.0);
  });

  test('reset() kazançları ve clip sayacını temizler', () {
    final ones = _const(10, 1.0);
    final m = Mixer()
      ..setGain('a', 1.0, immediate: true)
      ..setGain('b', 1.0, immediate: true);
    m.mixInto(Float32List(10), {'a': ones, 'b': ones});
    expect(m.clippedSamples, greaterThan(0));

    m.reset();
    expect(m.clippedSamples, 0);
    expect(m.gainOf('a'), 0.0);
  });
}
