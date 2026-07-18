import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nocta/core/audio_engine/dsp/mix_render.dart';
import 'package:nocta/core/audio_engine/mix_player.dart';

/// REGRESYON KİLİDİ: paylaşılan video, kullanıcının DUYDUĞU karakteri taşımalı.
///
/// Denetimde ölçülerek bulundu: `renderMix` döngü periyodunu render SÜRESİNDEN
/// türetiyordu. Çalma yolunda doğru (30 sn render → 30 sn döngü), ama export
/// 15 sn'lik TEK ATIMLIK bir render — döngülenmiyor. Sonuç: dalga kabarması
/// çalarken 10 sn, paylaşılan videoda 7.5 sn oluyordu. Kullanıcı duymadığı bir
/// sesi paylaşıyordu ve bu viral kanca #3'ün tam ortası.
void main() {
  const sampleRate = 48000;

  /// 20 ms blok-RMS zarfı üzerinde verilen periyottaki enerji (Goertzel benzeri).
  double envelopeEnergyAtPeriod(Float32List pcm, double periodSeconds) {
    const block = 960; // 20 ms
    final blocks = pcm.length ~/ block;
    final env = List<double>.filled(blocks, 0);
    for (var b = 0; b < blocks; b++) {
      var sum = 0.0;
      for (var i = b * block; i < (b + 1) * block; i++) {
        sum += pcm[i] * pcm[i];
      }
      env[b] = math.sqrt(sum / block);
    }
    final mean = env.reduce((a, b) => a + b) / blocks;
    final blocksPerPeriod = periodSeconds * sampleRate / block;
    var re = 0.0;
    var im = 0.0;
    for (var b = 0; b < blocks; b++) {
      final w = 2 * math.pi * b / blocksPerPeriod;
      re += (env[b] - mean) * math.cos(w);
      im += (env[b] - mean) * math.sin(w);
    }
    return math.sqrt(re * re + im * im) / blocks / (mean == 0 ? 1 : mean);
  }

  MixSpec wavesOnly() => MixSpec(const [
        MixLayer(id: 'w', type: LayerSource.waves, gain: 0.9),
      ]);

  test('EXPORT ile ÇALMA aynı kabarma periyodunu üretir', () {
    // Çalma yolu: 30 sn render, 30 sn döngü.
    final playback = renderMix(wavesOnly(), seconds: 30, seed: 1234);
    // Export yolu: 15 sn TEK ATIM, ama döngü periyodu çalma yolununki.
    final export = renderMix(
      wavesOnly(),
      seconds: 15,
      seed: 1234,
      loopSeconds: MixPlayer.defaultLoopSeconds,
    );

    // Çalmada modülasyon 10 sn'de (30/3).
    final playbackAt10 = envelopeEnergyAtPeriod(playback, 10);
    expect(playbackAt10, greaterThan(0.2), reason: 'çalmada 10 sn kabarma olmalı');

    // Export AYNI periyotta modüle olmalı — 7.5 sn'de DEĞİL.
    final exportAt10 = envelopeEnergyAtPeriod(export, 10);
    final exportAt75 = envelopeEnergyAtPeriod(export, 7.5);
    expect(
      exportAt10,
      greaterThan(exportAt75),
      reason: 'export kullanıcının duyduğu 10 sn periyodunu taşımalı, '
          'render süresinden (15 sn) türetilen 7.5 sn periyodunu değil',
    );
  });

  test('loopSeconds verilmezse eski davranış korunur (periyot = render süresi)', () {
    // Döngü uzunluğu ile render uzunluğunun aynı olduğu çağrılar için doğru olan
    // davranış; geriye dönük uyumluluk.
    final r = renderMix(wavesOnly(), seconds: 15, seed: 1234);
    expect(
      envelopeEnergyAtPeriod(r, 7.5),
      greaterThan(envelopeEnergyAtPeriod(r, 10)),
    );
  });
}
