import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:nocta/core/audio_engine/dsp/dc_blocker.dart';
import 'package:nocta/core/audio_engine/dsp/noise.dart';

/// DC engelleyici golden/davranış testleri. Beklenen değerler implementasyondan
/// ÖLÇÜLEREK alındı (docs/04 §80 yaklaşımı).
const _sampleRate = 48000;
const _samples = _sampleRate * 5;

Float32List _copy(Float32List b) => Float32List.fromList(b);

void main() {
  test('sabit (saf DC) giriş sönümlenir', () {
    final dc = Float32List(_sampleRate)..fillRange(0, _sampleRate, 1.0);
    DcBlocker().process(dc);
    // 1 sn sonunda DC tamamen gitmiş olmalı (ölçülen 0.00000).
    expect(dc.last.abs(), lessThan(1e-4));
  });

  test('pembe gürültünün artık DC’si temizlenir (#95 bulgusu kapanır)', () {
    final p = pinkNoise(_samples, seed: 42);
    expect(dcOffset(p).abs(), greaterThan(0.02)); // ÖNCE: ölçülen -0.0357

    final f = _copy(p);
    DcBlocker().process(f);
    expect(dcOffset(f).abs(), lessThan(0.005)); // SONRA: ölçülen 0.0006
  });

  test('sinyali bozmaz: beyaz gürültü RMS’i korunur (yüksek frekans geçer)', () {
    final w = whiteNoise(_samples, seed: 42);
    final f = _copy(w);
    DcBlocker().process(f);
    expect(rms(f), closeTo(rms(w), 0.01)); // ölçülen 0.5763 -> 0.5764
  });

  test('kesim frekansı ≈ 3.8 Hz @48kHz (bas duyulur kalır)', () {
    expect(DcBlocker().cutoffHz(_sampleRate), closeTo(3.82, 0.1));
  });

  test('STREAMING DENKLİĞİ: parça parça işleme = tek seferde işleme', () {
    // Bu testin bütün mesele bu: native graf sesi 128–1024'lük callback'lerle
    // işler. Durumlu filtre orada da aynı sonucu vermeli — "buffer ortalamasını
    // çıkar" yaklaşımının YAPAMADIĞI şey (bkz. #95 defter notu).
    final src = pinkNoise(20000, seed: 3);

    final oneShot = _copy(src);
    DcBlocker().process(oneShot);

    final chunked = _copy(src);
    final f = DcBlocker();
    for (var off = 0; off < chunked.length; off += 128) {
      final end = (off + 128).clamp(0, chunked.length);
      // Aynı belleğe bakan görünüm → yerinde işleme parçalar arasında sürer.
      f.process(Float32List.view(chunked.buffer, off * 4, end - off));
    }

    expect(chunked, equals(oneShot));
  });

  test('reset() durumu temizler (yeni oturum = taze filtre)', () {
    final src = pinkNoise(5000, seed: 9);

    final fresh = _copy(src);
    DcBlocker().process(fresh);

    final reused = DcBlocker();
    reused.process(_copy(src)); // durumu kirlet
    final after = _copy(src);
    reused.reset();
    reused.process(after);

    expect(after, equals(fresh));
  });
}
