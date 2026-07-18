import 'package:flutter/services.dart';

import 'dsp/mix_loop.dart';
import 'dsp/mix_render.dart';
import 'dsp/wav_encoder.dart';

/// Native ses grafı — slice 2 (#173). `MixSpec`'in her katmanını AYRI buffer olarak
/// (gain 1.0 render'lı) native mikser'e verir; kazançlar `setGain` ile ÇALARKEN değişir
/// → native tek track'e per-blok miksler (anlık slider korunur, OS-seviye kırpma yok).
///
/// ## Neden per-katman, slice 1'in tek-buffer'ı değil
///
/// Slice 1 (#172) tek mikslenmiş buffer çalıyordu → kazanç değişimi yeniden miks ister,
/// anında olmaz. Canlı yola aday olmak için slider anında değişmeli (yetenek #1). Burada
/// katmanlar ayrı gider; native mikser her blokta güncel kazancı okur.
///
/// ## Canlı yola DEFAULT bağlanmadı (dürüstlük)
///
/// `MixPlayer` (just_audio) hâlâ default canlı yol. Native'i default yapmak sesin KULAKLA
/// temiz olmasını gerektirir (§1.1) ve bu cihazsız doğrulanamaz. Slice 2 native'in anlık
/// slider'ı KORUYABİLDİĞİNİ emülatörde kanıtlar; default swap kulak doğrulaması sonrası.
///
/// Kanal/yöntem adları `MainActivity.kt` `nocta/native_mix` ile eşleşmeli; sözleşme
/// `native_mix_player_test.dart`'ta `setMockMethodCallHandler` ile kilitli.
class NativeMixPlayer {
  NativeMixPlayer({this.sampleRate = 48000, this.loopSeconds = 30});

  static const MethodChannel channel = MethodChannel('nocta/native_mix');

  final int sampleRate;
  final int loopSeconds;

  /// [spec]'in her katmanını gain 1.0 ile AYRI sorunsuz-döngü buffer'a render eder
  /// (seed katman indeksinden → korelasyonsuz) ve katman kazançlarıyla native'e verir.
  Future<void> playLayers(MixSpec spec) async {
    final buffers = <Uint8List>[];
    final gains = <double>[];
    for (var i = 0; i < spec.layers.length; i++) {
      final layer = spec.layers[i];
      final pcm = encodePcm16(
        renderSeamlessLoop(
          MixSpec([MixLayer(id: layer.id, type: layer.type, gain: 1.0)]),
          loopSeconds: loopSeconds,
          sampleRate: sampleRate,
          seed: i * 104729, // asal: MixPlayer ile aynı — katmanlar arası benzerlik olmasın
        ),
      );
      buffers.add(pcm);
      gains.add(layer.gain);
    }
    await channel.invokeMethod<void>('play', <String, Object>{
      'buffers': buffers,
      'sampleRate': sampleRate,
      'gains': gains,
    });
  }

  /// [index]. katmanın kazancını CANLI değiştirir (anlık slider). Bilinmeyen index
  /// native tarafta sessizce yok sayılır (UI/spec geçici uyumsuzluğu sesi kesmesin).
  Future<void> setGain(int index, double gain) {
    return channel.invokeMethod<void>('setGain', <String, Object>{
      'index': index,
      'gain': gain.clamp(0.0, 1.0),
    });
  }

  /// Susturur ve native kaynakları bırakır.
  Future<void> stop() => channel.invokeMethod<void>('stop');
}
