import 'package:flutter_test/flutter_test.dart';
import 'package:nocta/core/audio_engine/dsp/mix_render.dart';
import 'package:nocta/core/audio_engine/dsp/noise.dart';

/// Tam DSP zinciri (kaynaklar → mikser → DC blocker) golden testleri.
/// Beklenen değerler implementasyondan ÖLÇÜLEREK alındı (docs/04 §80).

/// Tipik uyku mix'i: yağmur (pembe) + derin (kahverengi).
const _sleepMix = MixSpec([
  MixLayer(id: 'rain', type: LayerSource.pink, gain: 0.5),
  MixLayer(id: 'deep', type: LayerSource.brown, gain: 0.4),
]);

void main() {
  test('uzunluk = sampleRate × saniye', () {
    final out = renderMix(_sleepMix, seconds: 2, sampleRate: 8000);
    expect(out.length, 16000);
  });

  test('determinizm: aynı spec + seed → birebir aynı render', () {
    final a = renderMix(_sleepMix, seconds: 1, seed: 7);
    final b = renderMix(_sleepMix, seconds: 1, seed: 7);
    expect(a, equals(b));
  });

  test('farklı seed → farklı render', () {
    final a = renderMix(_sleepMix, seconds: 1, seed: 7);
    final b = renderMix(_sleepMix, seconds: 1, seed: 8);
    expect(a, isNot(equals(b)));
  });

  test('KATMAN DEKORELASYONU: aynı tip farklı indekste bağımsız gürültü üretir', () {
    // Tüm katmanlar aynı seed'i kullansaydı iki pembe katman BİREBİR aynı olur,
    // toplama sesi zenginleştirmek yerine sadece yükseltirdi. Asal çarpanla ayrışıyor.
    final soloIndex0 = renderMix(
      const MixSpec([MixLayer(id: 'a', type: LayerSource.pink, gain: 1.0)]),
      seconds: 1,
      seed: 42,
    );
    final atIndex1 = renderMix(
      const MixSpec([
        MixLayer(id: 'x', type: LayerSource.pink, gain: 0.0), // indeks 0 (sessiz)
        MixLayer(id: 'a', type: LayerSource.pink, gain: 1.0), // indeks 1
      ]),
      seconds: 1,
      seed: 42,
    );

    var identical = 0;
    for (var i = 0; i < soloIndex0.length; i++) {
      if (soloIndex0[i] == atIndex1[i]) identical++;
    }
    // ölçülen: %0.0 — tamamen farklı gürültü.
    expect(identical / soloIndex0.length, lessThan(0.01));
  });

  test('DC zincirde temizleniyor: pembe katmanın artık DC’si çıkışta yok', () {
    // Ham pembe dc≈-0.036 (#95); zincirin sonundaki DcBlocker onu siler (#96).
    final out = renderMix(
      const MixSpec([MixLayer(id: 'p', type: LayerSource.pink, gain: 1.0)]),
      seconds: 5,
      seed: 42,
    );
    expect(dcOffset(out).abs(), lessThan(0.005));
  });

  test('kazanç 0 olan katman çıkışa hiç katkı vermez', () {
    final withoutSilent = renderMix(
      const MixSpec([MixLayer(id: 'p', type: LayerSource.pink, gain: 1.0)]),
      seconds: 1,
      seed: 5,
    );
    final withSilent = renderMix(
      const MixSpec([
        MixLayer(id: 'p', type: LayerSource.pink, gain: 1.0), // indeks 0 — aynı seed
        MixLayer(id: 'w', type: LayerSource.white, gain: 0.0), // sessiz
      ]),
      seconds: 1,
      seed: 5,
    );
    expect(withSilent, equals(withoutSilent));
  });

  test('makul kazançlarda kırpma yok (headroom sağlam)', () {
    var clipped = -1;
    renderMix(_sleepMix, seconds: 5, seed: 42, onClipReport: (c) => clipped = c);
    expect(clipped, 0); // ölçülen: 0
  });

  test('aşırı kazançta kırpma RAPORLANIR (sessizce bozulmaz)', () {
    var clipped = -1;
    renderMix(
      const MixSpec([
        MixLayer(id: 'a', type: LayerSource.white, gain: 1.0),
        MixLayer(id: 'b', type: LayerSource.white, gain: 1.0),
        MixLayer(id: 'c', type: LayerSource.white, gain: 1.0),
      ]),
      seconds: 1,
      seed: 1,
      onClipReport: (c) => clipped = c,
    );
    expect(clipped, greaterThan(0));
  });

  test('uyku mix’i golden istatistikleri (5 sn @ 48kHz, seed 42)', () {
    final out = renderMix(_sleepMix, seconds: 5, seed: 42);
    expect(rms(out), closeTo(0.1274, 0.02));
    expect(meanAbsDelta(out), closeTo(0.0457, 0.01));
    expect(dcOffset(out).abs(), lessThan(0.005)); // ölçülen 0.00002
  });
}
