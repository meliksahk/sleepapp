import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nocta/core/audio_engine/dsp/mix_loop.dart';
import 'package:nocta/core/audio_engine/dsp/mix_render.dart';
import 'package:nocta/core/audio_engine/dsp/tone.dart';
import 'package:nocta/core/audio_engine/dsp/wav_encoder.dart';
import 'package:nocta/core/audio_engine/mix_player.dart' show LoopRequest, renderLoopSync;

/// Saf ton kaynağı: kullanıcının seçtiği frekanstaki tek sinüs.
///
/// **Bu testler sesin DOĞRU olduğunu kanıtlar, GÜZEL olduğunu kanıtlamaz**
/// (CLAUDE.md §1.1). Buradaki her iddia ÖLÇÜLMÜŞ bir sayıdır.
void main() {
  const sr = 48000;
  const loopSec = 30;
  const n = sr * loopSec;

  double peak(Float32List b) {
    var m = 0.0;
    for (final v in b) {
      if (v.abs() > m) m = v.abs();
    }
    return m;
  }

  /// Sıfır geçişlerinden ölçülen frekans: pozitif yönlü geçişleri sayıp
  /// süreye böler. 30 sn'lik buffer'da 110 Hz için ~3300 geçiş beklenir —
  /// sayım hatası ±1 periyot bile frekansı ~0.03 Hz'den az şaşırtır.
  double measuredHz(Float32List b) {
    var crossings = 0;
    for (var i = 1; i < b.length; i++) {
      if (b[i - 1] < 0 && b[i] >= 0) crossings++;
    }
    return crossings / loopSec;
  }

  /// INTERLEAVED stereo buffer'da TEK bir kanalın ([offset] = 0 sol, 1 sağ)
  /// sıfır-geçiş frekansı.
  double measuredHzChannel(Float32List b, int offset) {
    var crossings = 0;
    for (var i = 2; i < b.length; i += 2) {
      if (b[i - 2 + offset] < 0 && b[i + offset] >= 0) crossings++;
    }
    return crossings / loopSec;
  }

  group('toneSource', () {
    test('frekans DOĞRU üretilir (110 Hz → ölçülen ≈ 110)', () {
      final b = toneSource(n, frequencyHz: 110, sampleRate: sr, loopSamples: n);
      expect(measuredHz(b), closeTo(110, 0.05));
    });

    test('yüksek frekansta da doğru (440.01 → ızgarada 440.0000)', () {
      final b = toneSource(n, frequencyHz: 440.01, sampleRate: sr, loopSamples: n);
      final expected = toneGridHz(440.01, loopSec.toDouble());
      expect(expected, closeTo(440, 1 / loopSec)); // ızgara adımı 1/30 Hz
      expect(measuredHz(b), closeTo(440, 0.05));
    });

    test('tepe genliği kapalı formdaki sınıra eşittir (amp·|sin| ≤ amp)', () {
      final b = toneSource(n, frequencyHz: 110, sampleRate: sr, loopSamples: n);
      final p = peak(b);
      // Tepe tam amp OLMAYABİLİR (örnek tam tepeye düşmeyebilir) ama ASLA aşamaz;
      // 110 Hz @48 kHz'te örnek tepenin çok yakınına düşer.
      expect(p, lessThanOrEqualTo(tonePeakAmp));
      expect(p, greaterThan(tonePeakAmp * 0.99));
    });

    test('deterministiktir: aynı girdi → bit-bit aynı buffer', () {
      final a = toneSource(n ~/ 2, frequencyHz: 110, sampleRate: sr, loopSamples: n);
      final c = toneSource(n ~/ 2, frequencyHz: 110, sampleRate: sr, loopSamples: n);
      expect(a.length, c.length);
      for (var i = 0; i < a.length; i++) {
        expect(a[i], c[i]);
      }
    });

    test('döngü dikişi DEĞERDE süreklidir: s[n] = s[0]', () {
      // Sarma noktası s[n-1]→s[0] DEĞİL, s[n]→s[0]'dır (periyodik kaynakta
      // s[n] = s[0]). O yüzden n+1 örnek üretip s[n]'i ölçüyoruz.
      final b = toneSource(n + 1, frequencyHz: 110, sampleRate: sr, loopSamples: n);
      expect(b[n], closeTo(b[0], 1e-9));
    });

    test('dikişde TÜREV de süreklidir: ardışık farklar hizalanır', () {
      final b = toneSource(n + 1, frequencyHz: 220, sampleRate: sr, loopSamples: n);
      final wrapDelta = b[n] - b[n - 1];
      final headDelta = b[1] - b[0];
      expect(wrapDelta, closeTo(headDelta, 1e-6));
    });

    test('assert aralık dışı frekansı kırar', () {
      expect(
        () => toneSource(sr,
            frequencyHz: toneMinHz - 1, sampleRate: sr, loopSamples: n),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => toneSource(sr,
            frequencyHz: toneMaxHz + 1, sampleRate: sr, loopSamples: n),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('mikser entegrasyonu (renderMix / renderSeamlessLoop)', () {
    test('renderMix tone katmanını frekansıyla üretir', () {
      const spec = MixSpec([
        MixLayer(
          id: 'hum',
          type: LayerSource.tone,
          gain: 0.2,
          frequencyHz: 110,
        ),
      ]);
      final mix = renderMix(spec, seconds: loopSec);
      expect(measuredHz(mix), closeTo(110, 0.05));
      // Kazanç 0.2 × kaynak tepe 0.5 = 0.1 üst sınır.
      expect(peak(mix), lessThan(0.11));
    });

    test('tone DÖNGÜ-PERİYODİKTİR: crossfade ATLANIR (ham kopya)', () {
      const spec = MixSpec([
        MixLayer(
          id: 'hum',
          type: LayerSource.tone,
          gain: 1.0,
          frequencyHz: 110,
        ),
      ]);
      final seamless = renderSeamlessLoop(spec, loopSeconds: loopSec);
      final raw = renderMix(spec, seconds: loopSec);
      // Periyodik yol kuyruğu harmanlamaz: çıkış ham render ile BİT-BİT aynıdır.
      expect(seamless.length, raw.length);
      var maxDiff = 0.0;
      for (var i = 0; i < raw.length; i++) {
        maxDiff = math.max(maxDiff, (seamless[i] - raw[i]).abs());
      }
      expect(maxDiff, 0.0);
    });

    test('gürültü + tone KARIŞIK spec: çalınabilir, deterministik, kırpma yok', () {
      const mixed = MixSpec([
        MixLayer(id: 'deep', type: LayerSource.brown, gain: 0.3),
        MixLayer(id: 'hum', type: LayerSource.tone, gain: 0.2, frequencyHz: 110),
      ]);
      final out = renderSeamlessLoop(mixed, loopSeconds: loopSec);
      expect(out.length, sr * loopSec);
      expect(peak(out), lessThanOrEqualTo(1.0));
      // Karışık spec'te gürültü harmanlanır ama süreç yine deterministiktir:
      // aynı spec iki kez → birebir aynı çıkış (dikiş harmanı dahil).
      final again = renderSeamlessLoop(mixed, loopSeconds: loopSec);
      var maxDiff = 0.0;
      for (var i = 0; i < out.length; i++) {
        maxDiff = math.max(maxDiff, (out[i] - again[i]).abs());
      }
      expect(maxDiff, 0.0);
    });

    test('tone + frequencyHz null çağrılırsa debug modda assert kırar', () {
      const broken = MixSpec([
        MixLayer(id: 'bad', type: LayerSource.tone, gain: 0.5),
      ]);
      expect(() => renderMix(broken, seconds: 1), throwsA(isA<AssertionError>()));
    });

    test('beatHz > 0 → renderMix TREMOLolu mono üretir (export yolu)', () {
      const spec = MixSpec([
        MixLayer(
          id: 'hum',
          type: LayerSource.tone,
          gain: 1.0,
          frequencyHz: 200,
          beatHz: 10,
        ),
      ]);
      final mono = renderMix(spec, seconds: loopSec);

      // İndirgemenin SPEKTRAL kimliği: (sin a + sin b)/2 lineer toplamdır →
      // HER İKİ kısmi (200 ve 210) EŞİT genlikte bulunmalı. Pencere TAM
      // döngü uzunluğu: iki frekans da orada tam sayıda çevrim tamamlar
      // (ızgara kilidi) → sızıntısız ölçüm.
      double goertzel(double hz) {
        final w = 2 * math.pi * hz / sr;
        var coeff = 2 * math.cos(w);
        var s1 = 0.0, s2 = 0.0;
        for (var i = 0; i < n; i++) {
          final s0 = mono[i] + coeff * s1 - s2;
          s2 = s1;
          s1 = s0;
        }
        return math.sqrt(s1 * s1 + s2 * s2 - coeff * s1 * s2);
      }

      final gL = goertzel(200);
      final gR = goertzel(210);
      expect(gL / gR, closeTo(1.0, 0.02),
          reason: 'indirgemek iki orijinal kısmiyi eşit taşır');
      // Yanlış frekansta enerji YOK (negatif kontrol).
      expect(goertzel(300) / gL, lessThan(0.01));

      // Zarf kanıtı: |x|'in vuru periyodundaki (sr/10 örnek) otokorelasyonu
      // YÜKSEK olmalı — tek saf tonda bu lag'de periyodiklik yoktur.
      double acAbs(int lag) {
        var num = 0.0, d0 = 0.0, d1 = 0.0;
        final m = sr * 5;
        for (var i = 0; i < m; i++) {
          num += mono[i].abs() * mono[i + lag].abs();
          d0 += mono[i].abs() * mono[i].abs();
          d1 += mono[i + lag].abs() * mono[i + lag].abs();
        }
        return num / math.sqrt(d0 * d1);
      }

      final beatAc = acAbs(sr ~/ 10);
      expect(beatAc, greaterThan(0.6),
          reason: 'vuru hızında genlik modülasyonu ölçülmeli (ac=$beatAc)');
    });

    test('beatHz ile mono yol da döngü-periyodiktir (ham kopya, crossfade yok)', () {
      const spec = MixSpec([
        MixLayer(id: 'h', type: LayerSource.tone, gain: 1.0, frequencyHz: 200, beatHz: 7.5),
      ]);
      final seamless = renderSeamlessLoop(spec, loopSeconds: loopSec);
      final raw = renderMix(spec, seconds: loopSec);
      // Her iki bileşen frekans da ızgarada → indirgemek periyodik → kilitli yol
      // crossfade'i ATLAYARAK ham kopyalar (tone-mono ile aynı kanıt).
      var maxDiff = 0.0;
      for (var i = 0; i < n; i++) {
        maxDiff = math.max(maxDiff, (seamless[i] - raw[i]).abs());
      }
      expect(maxDiff, lessThan(1e-12));
    });
  });

  group('binaural — toneBinauralSource (interleaved stereo)', () {
    test('kanallar INTERLEAVED ve DOĞRU frekanstadır (L=200, R=210)', () {
      final b = toneBinauralSource(n,
          baseHz: 200, beatHz: 10, sampleRate: sr, loopSamples: n);
      expect(b.length, n * 2);
      expect(measuredHzChannel(b, 0), closeTo(200, 0.05));
      expect(measuredHzChannel(b, 1), closeTo(210, 0.05));
    });

    test('her kanal kendi içinde dikişsizdir (s[n] = s[0], türev dahil)', () {
      final b = toneBinauralSource(n + 2,
          baseHz: 180, beatHz: 6, sampleRate: sr, loopSamples: n);
      for (final ch in [0, 1]) {
        expect(b[2 * n + ch], closeTo(b[ch], 1e-9),
            reason: 'kanal $ch değerde sürekli olmalı');
        final wrapDelta = b[2 * n + ch] - b[2 * (n - 1) + ch];
        final headDelta = b[2 + ch] - b[ch];
        expect(wrapDelta, closeTo(headDelta, 1e-5),
            reason: 'kanal $ch türevde sürekli olmalı');
      }
    });

    test('tepe sınırı KANAL BAŞINA toneStereoPeakBound (toplanmaz)', () {
      final b = toneBinauralSource(n,
          baseHz: 110, beatHz: 12, sampleRate: sr, loopSamples: n);
      double peakOf(int offset) {
        var m = 0.0;
        for (var i = offset; i < b.length; i += 2) {
          if (b[i].abs() > m) m = b[i].abs();
        }
        return m;
      }

      expect(peakOf(0), lessThanOrEqualTo(toneStereoPeakBound));
      expect(peakOf(1), lessThanOrEqualTo(toneStereoPeakBound));
    });

    test('vuru ızgaraya oturur: 30 sn döngüde tam sayıda çevrim', () {
      final g = toneGridBeat(8, loopSec.toDouble());
      expect(g * loopSec % 1, closeTo(0, 1e-9));
    });

    test('aralık dışı vuru assert kırar', () {
      expect(
        () => toneBinauralSource(sr,
            baseHz: 200,
            beatHz: toneBeatMaxHz + 1,
            sampleRate: sr,
            loopSamples: n),
        throwsA(isA<AssertionError>()),
      );
    });

    test('WAV 2 kanalla YAZILIR: başlık alanları + boyut', () {
      final pcm = Float32List(4800); // 2400 frame × 2 ch
      final bytes = encodeWav(pcm, sampleRate: 48000, channels: 2);
      final bd = ByteData.sublistView(bytes);
      expect(bytes.length, 44 + 4800 * 2);
      expect(bd.getUint16(22, Endian.little), 2); // numChannels
      expect(bd.getUint16(32, Endian.little), 4); // blockAlign = 2ch × 2byte
      expect(bd.getUint32(28, Endian.little), 48000 * 4); // byteRate
    });

    test('renderLoopSync beat > 0 → INTERLEAVED stereo döner (çalma yolu)', () {
      final pcm = renderLoopSync(const LoopRequest(
        type: LayerSource.tone,
        id: 'hum',
        loopSeconds: loopSec,
        sampleRate: sr,
        seed: 0,
        frequencyHz: 200,
        beatHz: 10,
      ));
      expect(pcm.length, n * 2, reason: 'stereo interleaved: 2 örnek/frame');
      expect(measuredHzChannel(pcm, 0), closeTo(200, 0.05), reason: 'SOL kanal');
      expect(measuredHzChannel(pcm, 1), closeTo(210, 0.05), reason: 'SAĞ kanal');
    });
  });
}
