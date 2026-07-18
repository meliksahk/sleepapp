import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nocta/core/audio_engine/dsp/mix_render.dart';
import 'package:nocta/core/audio_engine/native_mix_player.dart';

/// Native ses grafı slice 1 (#172) — **EMÜLATÖR/CİHAZ e2e**.
///
/// Bu, #169'un düştüğü tuzağı (yazıldı ama native derlenmedi/koşmadı) kapatır:
/// gerçek `AudioTrack` yolunu gerçek Android üstünde çalıştırır. Geçerse:
/// (a) Kotlin DERLENDİ (uygulama build edildi), (b) `nocta/native_mix` kanalı uçtan
/// uca çalıştı (MissingPluginException yok), (c) `AudioTrack.play()` hata atmadı.
///
/// Koşum: `flutter test integration_test/native_mix_test.dart -d <emülatör>`
/// (Flutter CI bunu koşmaz — yalnızca `flutter test` = unit. Yerel/cihaz kapısı.)
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('ÇEKİRDEK: native mikser tek buffer\'ı emülatörde çalar ve durur',
      (tester) async {
    final player = NativeMixPlayer(sampleRate: 48000, loopSeconds: 2);
    const spec = MixSpec([
      MixLayer(id: 'a', type: NoiseType.pink, gain: 0.6),
      MixLayer(id: 'b', type: NoiseType.brown, gain: 0.4),
    ]);

    // Native AudioTrack başlar — kanal + track kurulumu hata atmamalı.
    await player.playSpec(spec);
    // Birkaç saniye çalsın: yazıcı thread döngü dikişini de en az bir kez geçer,
    // ve bu pencerede `adb shell dumpsys audio` TEK track görebilir.
    await Future<void>.delayed(const Duration(seconds: 3));
    await player.stop();

    // Buraya hatasız gelmek çekirdek kanıt: native yol gerçek cihazda koştu.
    expect(true, isTrue);
  });
}
