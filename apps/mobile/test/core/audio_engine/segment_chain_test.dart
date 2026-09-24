import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nocta/core/audio_engine/dsp/mix_render.dart';
import 'package:nocta/core/audio_engine/dsp/segment_chain.dart';
import 'package:nocta/core/audio_engine/mix_player.dart';

/// Sonsuz uzatma zinciri, DSP düzeyinde (bkz. `segment_chain.dart`).
///
/// Gerçek döngü uzunluğu (30 sn) kullanılıyor: kilitli kaynakların ızgarası ve
/// olay yerleşimi döngü uzunluğuna bağlı; kısaltılmış döngü başka bir sesi test
/// ederdi. Örnekleme hızı 16 kHz: en tiz kısmi ton (çan, ~3.9 kHz) Nyquist'in
/// altında kalıyor, test süresi üçte birine iniyor.
///
/// **Kanıtlanmayan:** sesin kulakta nasıl duyulduğu. Burada ölçülen, dikişte
/// sıçrama olmaması, seviye basamağı olmaması ve parçaların birbirinin kopyası
/// olmaması. Kulak testi cihazda.
const int _sr = 16000;
const int _loopSeconds = 30;
const int _n = _sr * _loopSeconds;

final List<LayerSource> _regenerating = LayerSource.values.where(regeneratesPerSegment).toList();
final List<LayerSource> _crossfaded = _regenerating.where((t) => !isLoopPeriodic(t)).toList();

MixLayer _layer(LayerSource t) => MixLayer(id: t.name, type: t, gain: 0.5);

/// [count] parçalık zincir, `MixPlayer`'ın besleyicisiyle aynı sırayla.
List<SegmentPcm> _chain(LayerSource t, int count, {int baseSeed = 104729}) {
  final out = <SegmentPcm>[];
  Float32List? tail;
  double? ref;
  for (var k = 0; k < count; k++) {
    final s = renderSegmentPcm(SegmentRequest(
      layer: _layer(t),
      index: k,
      baseSeed: baseSeed,
      loopSeconds: _loopSeconds,
      sampleRate: _sr,
      prevTail: tail,
      refRms: ref,
    ));
    out.add(s);
    tail = s.tail;
    ref = s.refRms ?? ref;
  }
  return out;
}

double _rms(Float32List a) {
  var s = 0.0;
  for (final v in a) {
    s += v * v;
  }
  return math.sqrt(s / a.length);
}

double _maxStep(Float32List a) {
  var m = 0.0;
  for (var i = 1; i < a.length; i++) {
    final d = (a[i] - a[i - 1]).abs();
    if (d > m) m = d;
  }
  return m;
}

/// Gövde korelasyonu: dikiş bölgesi dışarıda bırakılır (ilk 1 sn).
double _bodyCorr(Float32List a, Float32List b) {
  var ab = 0.0, aa = 0.0, bb = 0.0;
  for (var i = _sr; i < a.length; i++) {
    ab += a[i] * b[i];
    aa += a[i] * a[i];
    bb += b[i] * b[i];
  }
  return ab / math.sqrt(aa * bb);
}

double _maxAbsDiff(Float32List a, Float32List b) {
  var m = 0.0;
  for (var i = 0; i < a.length; i++) {
    final d = (a[i] - b[i]).abs();
    if (d > m) m = d;
  }
  return m;
}

void main() {
  group('ilk parça', () {
    test('bugünkü döngü buffer\'ının BİREBİR aynısı', () {
      // Kullanıcının duyduğu ilk 30 sn değişmedi; üretim durursa çalar bu
      // parçayı eskisi gibi dikişsiz döndürür.
      for (final t in _regenerating) {
        final first = renderSegmentPcm(SegmentRequest(
          layer: _layer(t),
          index: 0,
          baseSeed: 104729,
          loopSeconds: _loopSeconds,
          sampleRate: _sr,
        ));
        final today = renderLoopSync(LoopRequest(
          type: t,
          id: t.name,
          loopSeconds: _loopSeconds,
          sampleRate: _sr,
          seed: 104729,
        ));
        expect(first.pcm.length, _n, reason: '$t');
        expect(_maxAbsDiff(first.pcm, today), 0.0, reason: '$t ilk parça farklı');
      }
    });
  });

  group('zincir', () {
    test('ÇEKİRDEK: ardışık parçalar birbirinin kopyası değil', () {
      for (final t in _regenerating) {
        final c = _chain(t, 3);
        for (var k = 1; k < c.length; k++) {
          expect(_maxAbsDiff(c[k].pcm, c[k - 1].pcm), greaterThan(1e-4), reason: '$t parça $k öncekinin kopyası');
        }
        // Gürültü, doğa, sürtünme, çan ve arpejde tohum sesin kendisini
        // değiştirir: gövdeler ilişkisiz. Pad ve seramikte yalnız olaylar
        // değişir, yatakları tasarım gereği periyodik (bkz. segment_chain.dart).
        if (t != LayerSource.pad && t != LayerSource.ceramic) {
          expect(_bodyCorr(c[1].pcm, c[2].pcm).abs(), lessThan(0.9), reason: '$t gövdeleri fazla benzer');
        }
      }
    });

    test('ÇEKİRDEK: parça sınırında sıçrama yok', () {
      for (final t in _regenerating) {
        final c = _chain(t, 3);
        for (var k = 1; k < c.length; k++) {
          final prev = c[k - 1].pcm;
          final seam = (c[k].pcm[0] - prev[_n - 1]).abs();
          // Dikişteki adım, kaynağın kendi içindeki en büyük adımı geçmemeli:
          // geçerse duyulan bir tık olurdu.
          expect(seam, lessThanOrEqualTo(_maxStep(prev)), reason: '$t dikiş $k: $seam');
        }
      }
    });

    test('ÇEKİRDEK: harmanlanan kaynaklarda seviye basamağı yok', () {
      // Ölçülen ham fark pembe gürültüde ≈1.3 dB idi; her 30 sn'de bir duyulan
      // bir basamak olurdu.
      for (final t in _crossfaded) {
        final c = _chain(t, 4);
        final ref = _rms(c[0].pcm);
        for (var k = 1; k < c.length; k++) {
          final db = 20 * math.log(_rms(c[k].pcm) / ref) / math.ln10;
          expect(db.abs(), lessThan(0.5), reason: '$t parça $k: ${db.toStringAsFixed(2)} dB');
        }
      }
    });

    test('uzun zincir: on parça boyunca hiçbir parça bir diğerini tekrar etmiyor', () {
      final c = _chain(LayerSource.brown, 10);
      for (var i = 0; i < c.length; i++) {
        for (var j = i + 1; j < c.length; j++) {
          expect(_bodyCorr(c[i].pcm, c[j].pcm).abs(), lessThan(0.5), reason: 'parça $i ~ parça $j');
        }
      }
    });

    test('aynı tohum aynı akış (deterministik)', () {
      final a = _chain(LayerSource.rain, 3);
      final b = _chain(LayerSource.rain, 3);
      for (var k = 0; k < a.length; k++) {
        expect(_maxAbsDiff(a[k].pcm, b[k].pcm), 0.0, reason: 'parça $k');
      }
    });

    test('kuyruk olmadan sonraki parça üretilmez (sessiz yanlış yerine hata)', () {
      expect(
        () => renderSegmentPcm(SegmentRequest(
          layer: _layer(LayerSource.pink),
          index: 1,
          baseSeed: 0,
          loopSeconds: _loopSeconds,
          sampleRate: _sr,
        )),
        throwsArgumentError,
      );
    });
  });

  group('sınıflandırma ölçümle tutarlı', () {
    test('yeniden üretilen her kaynak tohumla gerçekten değişiyor', () {
      // Değişmeyen bir kaynağı yeniden üretmek, gece boyu boşa işlemci demek.
      for (final t in _regenerating) {
        final a = renderSource(t, _n, seed: 1, sampleRate: _sr, loopSamples: _n);
        final b = renderSource(t, _n, seed: 2, sampleRate: _sr, loopSamples: _n);
        expect(_maxAbsDiff(a, b), greaterThan(1e-4), reason: '$t tohumdan bağımsız');
      }
    });

    test('yeniden üretilmeyenler tohumdan bağımsız', () {
      // Bir gün bu kaynaklara tohuma bağlı bir çeşitlilik eklenirse bu test
      // kırmızıya döner ve kaynağın yeniden üretilen gruba alınmasını hatırlatır.
      for (final t in LayerSource.values.where((t) => !regeneratesPerSegment(t))) {
        final hz = t == LayerSource.tone ? 200.0 : null;
        final a = renderSource(t, _n, seed: 1, sampleRate: _sr, loopSamples: _n, frequencyHz: hz);
        final b = renderSource(t, _n, seed: 2, sampleRate: _sr, loopSamples: _n, frequencyHz: hz);
        expect(_maxAbsDiff(a, b), lessThan(1e-6), reason: '$t tohuma bağlı hâle gelmiş');
      }
    });

    test('sürtünme harmanlanan grupta: yatağı rastgele gürültü', () {
      expect(isLoopPeriodic(LayerSource.friction), isFalse);
      final s = renderSource(LayerSource.friction, _n + 800, seed: 7919, sampleRate: _sr, loopSamples: _n);
      // Aynı tohumun başı ile döngü sonrası devamı ilişkisiz → ham kopya dikişte
      // süreksizlik bırakırdı; eşit-güç harman doğru yol.
      var ab = 0.0, aa = 0.0, bb = 0.0;
      for (var i = 0; i < 800; i++) {
        ab += s[i] * s[_n + i];
        aa += s[i] * s[i];
        bb += s[_n + i] * s[_n + i];
      }
      expect((ab / math.sqrt(aa * bb)).abs(), lessThan(0.3));
    });
  });

  group('melodi ayarları', () {
    test('ÇEKİRDEK: kök nota, dalga, tempo ve dizi çalma yoluna ulaşıyor', () {
      // Eskiden istek bu alanları taşımıyordu; editörde ne seçilirse seçilsin
      // varsayılan akor çalıyordu.
      LoopRequest req(int root) => LoopRequest(
            type: LayerSource.chords,
            id: 'c',
            loopSeconds: _loopSeconds,
            sampleRate: _sr,
            seed: 0,
            rootSemi: root,
            waveform: 'triangle',
            tempoScale: 1.0,
            patternIdx: 1,
          );
      final shifted = renderLoopSync(req(5));
      final base = renderLoopSync(req(0));
      // Referans: dışa aktarma yolu (`renderMix`) ayarları kaynağa doğrudan
      // geçirir. Kilitli kaynakta döngü, tek atımlık render'ın aynısı olmalı.
      // (İlk sürümde referans olarak `renderSeamlessLoop` kullanılmıştı; o da
      // aynı ayarları düşürdüğü için eşitlik yanlış sebeple geçiyordu.)
      final direct = renderMix(
        const MixSpec(<MixLayer>[
          MixLayer(
            id: 'c',
            type: LayerSource.chords,
            gain: 1.0,
            rootSemi: 5,
            waveform: 'triangle',
            tempoScale: 1.0,
            patternIdx: 1,
          ),
        ]),
        seconds: _loopSeconds,
        sampleRate: _sr,
      );
      expect(_maxAbsDiff(shifted, base), greaterThan(1e-3), reason: 'kök nota sesi değiştirmiyor');
      expect(_maxAbsDiff(shifted, direct), 0.0, reason: 'çalma yolu ayarları düşürüyor');
    });
  });
}
