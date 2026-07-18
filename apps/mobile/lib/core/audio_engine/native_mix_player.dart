import 'package:flutter/services.dart';

import 'dsp/mix_loop.dart';
import 'dsp/mix_render.dart';
import 'dsp/wav_encoder.dart';

/// Native ses grafı — slice 1 (#172). `MixSpec`'i TEK in-app-mikslenmiş buffer'a
/// toplayıp native `AudioTrack`'e verir → tek track (OS-seviye kırpma yok).
///
/// ## Neden ayrı sınıf, `MixPlayer`'ı DEĞİŞTİRMİYOR
///
/// `MixPlayer` katman başına ayrı player kullanır ki slider ANINDA değişsin (yetenek #1).
/// Tek mikslenmiş buffer'da slider değişimi yeniden miks ister → anında olmaz. Bu yüzden
/// slice 1 canlı yolu DEĞİŞTİRMEZ; mekanizmayı (native graf otonom + emülatörde koşar)
/// kanıtlar. Anlık slider'ı koruyan per-blok kazanç okuma slice 2'nin işi — o gelene
/// kadar canlı yol `MixPlayer`'da kalır, hiçbir regresyon yok.
///
/// Kanal/yöntem adları `MainActivity.kt`'deki `nocta/native_mix` ile eşleşmeli;
/// sözleşme aşağıda `native_mix_player_test.dart`'ta `setMockMethodCallHandler` ile kilitli.
class NativeMixPlayer {
  NativeMixPlayer({this.sampleRate = 48000, this.loopSeconds = 30});

  static const MethodChannel channel = MethodChannel('nocta/native_mix');

  final int sampleRate;
  final int loopSeconds;

  /// [spec]'i mikser+kompresör (`renderMix`) üzerinden TEK sorunsuz-döngü buffer'a
  /// toplar ve native tarafa 16-bit PCM olarak verir. Kompresör toplamayı [-1,1]'e
  /// sıkıştırdığı için OS-seviye kırpma olmaz; dikiş crossfade'li (#170) → süreklidir.
  Future<void> playSpec(MixSpec spec) async {
    final samples = renderSeamlessLoop(
      spec,
      loopSeconds: loopSeconds,
      sampleRate: sampleRate,
    );
    await channel.invokeMethod<void>('play', <String, Object>{
      'pcm': encodePcm16(samples),
      'sampleRate': sampleRate,
    });
  }

  /// Susturur ve native kaynakları bırakır.
  Future<void> stop() => channel.invokeMethod<void>('stop');
}
