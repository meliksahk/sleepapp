import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nocta/core/audio_engine/dsp/mix_render.dart';
import 'package:nocta/core/audio_engine/native_mix_player.dart';

/// Native ses grafı slice 1+2 (#172/#173) — **EMÜLATÖR/CİHAZ e2e**.
///
/// #169'un tuzağını (yazıldı ama native derlenmedi/koşmadı) kapatır: gerçek per-blok
/// native mikser yolunu gerçek Android üstünde çalıştırır. Geçerse: (a) Kotlin DERLENDİ,
/// (b) `nocta/native_mix` kanalı uçtan uca çalıştı, (c) çok katman + ÇALARKEN kazanç
/// değişimi `AudioTrack`'te hata atmadı (anlık slider'ın native karşılığı).
///
/// Koşum: `flutter test integration_test/native_mix_test.dart -d <emülatör>`
/// (Flutter CI bunu koşmaz — yalnızca `flutter test` = unit. Cihaz kapısı.)
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('ÇEKİRDEK: native mikser çok katmanı çalar, kazanç CANLI değişir, durur',
      (tester) async {
    final player = NativeMixPlayer(sampleRate: 48000, loopSeconds: 2);
    const spec = MixSpec([
      MixLayer(id: 'a', type: NoiseType.pink, gain: 0.6),
      MixLayer(id: 'b', type: NoiseType.brown, gain: 0.4),
    ]);

    // Çok katmanı native mikser'e ver — kanal + track kurulumu hata atmamalı.
    await player.playLayers(spec);
    await Future<void>.delayed(const Duration(seconds: 2));

    // ÇALARKEN kazançları değiştir (anlık slider'ın native yolu) — hata atmamalı,
    // native yazıcı thread bir sonraki blokta yeni kazancı okur.
    await player.setGain(0, 0.2);
    await player.setGain(1, 0.9);
    await Future<void>.delayed(const Duration(seconds: 2));

    await player.stop();

    // Hatasız buraya gelmek çekirdek kanıt: per-blok native mikser + canlı kazanç
    // gerçek cihazda koştu. (Bu pencerede `dumpsys media.audio_flinger` TEK track görür.)
    expect(true, isTrue);
  });
}
