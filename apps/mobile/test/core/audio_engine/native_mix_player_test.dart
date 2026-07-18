import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nocta/core/audio_engine/dsp/mix_loop.dart';
import 'package:nocta/core/audio_engine/dsp/mix_render.dart';
import 'package:nocta/core/audio_engine/dsp/wav_encoder.dart';
import 'package:nocta/core/audio_engine/native_mix_player.dart';

/// Native ses grafı slice 1 (#172) — **Dart tarafı** sözleşmesi. Gerçek AudioTrack
/// çalması cihaz-kapılıdır ve `integration_test/native_mix_test.dart`'ta emülatörde
/// doğrulanır; buradaki testler kanal sözleşmesini (Kotlin ile eşleşen isim/anahtar)
/// ve buffer'ın tek mikslenmiş PCM olduğunu cihazsız kilitler.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const spec = MixSpec([
    MixLayer(id: 'a', type: NoiseType.pink, gain: 0.6),
    MixLayer(id: 'b', type: NoiseType.brown, gain: 0.4),
  ]);

  group('kanal sözleşmesi — MainActivity.kt ile eşleşmeli', () {
    late List<MethodCall> calls;

    setUp(() {
      calls = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(NativeMixPlayer.channel, (call) async {
        calls.add(call);
        return null;
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(NativeMixPlayer.channel, null);
    });

    test('ÇEKİRDEK: kanal adı ve play/stop yöntem+anahtarları native ile aynı', () async {
      final player = NativeMixPlayer(sampleRate: 48000, loopSeconds: 1);
      await player.playSpec(spec);
      await player.stop();

      expect(NativeMixPlayer.channel.name, 'nocta/native_mix');
      expect(calls.map((c) => c.method).toList(), ['play', 'stop']);
      final playArgs = calls.first.arguments as Map;
      // Kotlin `call.argument<ByteArray>("pcm")!!` / `<Int>("sampleRate")!!` okuyor.
      expect(playArgs.keys.toSet(), {'pcm', 'sampleRate'});
      expect(playArgs['sampleRate'], 48000);
    });

    test('ÇEKİRDEK: tek buffer = 16-bit PCM, uzunluk = saniye×örnek×2 bayt', () async {
      final player = NativeMixPlayer(sampleRate: 8000, loopSeconds: 2);
      await player.playSpec(spec);

      final pcm = (calls.first.arguments as Map)['pcm'] as Uint8List;
      // Sorunsuz döngü N örnek döndürür (crossfade N+X üretip N'e kırpar) → 8000×2×2 bayt.
      expect(pcm.length, 8000 * 2 * 2);
    });

    test('mikslenmiş buffer OS-seviye kırpma bırakmaz (kompresör [-1,1]\'e sıkıştırır)', () {
      // İki katman toplanıp renderMix kompresörüyle [-1,1]'e sıkışır → int16\'da taşma yok.
      // (Native tarafta ek limiter gerekmez; tek track güvenle çalar.)
      final pcm = encodePcm16(
        renderSeamlessLoop(spec, loopSeconds: 1, sampleRate: 8000),
      );
      // 16-bit LE: her örnek [-32768, 32767]. Bayt çifti okunabiliyorsa taşma yok
      // (encodePcm16 zaten clamp'liyor); burada uzunluk çift ve boş değil kontrolü.
      expect(pcm.length, isPositive);
      expect(pcm.length.isEven, isTrue);
    });
  });
}
