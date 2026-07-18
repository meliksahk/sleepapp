import 'dart:typed_data';

import 'dc_blocker.dart';
import 'mixer.dart';
import 'noise.dart';

/// Mix tanımı ve **offline render** — DSP zincirinin birleştiği yer:
/// kaynaklar → [Mixer] → [DcBlocker].
///
/// Bu, native grafın (AVAudioEngine/Oboe) eşleşmesi gereken **referans**
/// implementasyondur; ayrıca mix-to-video export'unun (viral kanca #3) ihtiyaç
/// duyduğu offline üretimin ta kendisidir. Spekülatif değil, ürün yolunda.

enum NoiseType { white, pink, brown }

/// Tek bir mikser katmanı: hangi kaynak, hangi kazanç.
class MixLayer {
  const MixLayer({required this.id, required this.type, required this.gain});

  final String id;
  final NoiseType type;

  /// [0,1] — mikser zaten sıkıştırır.
  final double gain;
}

/// Bir mix'in tanımı (preset). Katman sırası render'ı etkilemez (toplama).
class MixSpec {
  const MixSpec(this.layers);

  final List<MixLayer> layers;
}

/// Katman başına seed türetir. **Kritik:** tüm katmanlar aynı seed'i kullanırsa
/// aynı gürültü üretilir → katmanlar birebir korelasyonlu olur ve toplama sesi
/// zenginleştirmek yerine sadece yükseltir. Asal çarpanla ayrıştırıyoruz.
int _layerSeed(int baseSeed, int index) => baseSeed + (index + 1) * 7919;

Float32List _generate(NoiseType type, int samples, int seed) {
  switch (type) {
    case NoiseType.white:
      return whiteNoise(samples, seed: seed);
    case NoiseType.pink:
      return pinkNoise(samples, seed: seed);
    case NoiseType.brown:
      return brownNoise(samples, seed: seed);
  }
}

/// [spec]'i [seconds] saniyelik tek bir buffer'a render eder.
///
/// Kazançlar `immediate` uygulanır (offline render'da rampa gereksiz: tık ancak
/// ÇALARKEN kazanç değişirse olur; burada başlangıç durumu zaten hedeftir).
/// Çıkışta DC engelleyici çalışır → pembe katmanların artık DC'si temizlenir (#95/#96).
///
/// [clippedSamples] non-null verilirse kırpılan örnek sayısı oraya yazılır —
/// çağıran headroom'u görebilsin (mikser sessizce bozmaz).
///
/// [extraSamples] > 0 verilirse `seconds`in ÜSTÜNE o kadar örnek daha üretilir
/// (aynı deterministik gürültü dizisinin devamı). Sorunsuz döngü crossfade'i
/// (`renderSeamlessLoop`) bunu kullanır: kuyruğu başa harmanlamak için döngü
/// uzunluğunun biraz ötesini ister. Süreç aksi halde değişmez.
Float32List renderMix(
  MixSpec spec, {
  required int seconds,
  int sampleRate = 48000,
  int seed = 0,
  int extraSamples = 0,
  void Function(int clipped)? onClipReport,
}) {
  assert(seconds > 0);
  assert(extraSamples >= 0);
  final samples = sampleRate * seconds + extraSamples;

  final buffers = <String, Float32List>{};
  final mixer = Mixer(sampleRate: sampleRate);
  for (var i = 0; i < spec.layers.length; i++) {
    final layer = spec.layers[i];
    buffers[layer.id] = _generate(layer.type, samples, _layerSeed(seed, i));
    mixer.setGain(layer.id, layer.gain, immediate: true);
  }

  final out = Float32List(samples);
  mixer.mixInto(out, buffers);
  DcBlocker().process(out);
  onClipReport?.call(mixer.clippedSamples);
  return out;
}
