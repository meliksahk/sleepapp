import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nocta/core/audio_engine/dsp/mix_render.dart';
import 'package:nocta/core/audio_engine/native_mix_player.dart';

/// Native ses grafı slice 2 (#173) — **Dart tarafı** sözleşmesi. Gerçek per-blok miks
/// + canlı kazanç cihaz-kapılıdır ve `integration_test/native_mix_test.dart`'ta
/// emülatörde doğrulanır; buradaki testler kanal sözleşmesini (Kotlin ile eşleşen
/// isim/anahtar) ve per-katman buffer üretimini cihazsız kilitler.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const spec = MixSpec([
    MixLayer(id: 'a', type: NoiseType.pink, gain: 0.6),
    MixLayer(id: 'b', type: NoiseType.brown, gain: 0.4),
  ]);

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

  group('kanal sözleşmesi — MainActivity.kt ile eşleşmeli', () {
    test('ÇEKİRDEK: play PER-KATMAN buffer + kazanç listesi gönderir', () async {
      final player = NativeMixPlayer(sampleRate: 8000, loopSeconds: 1);
      await player.playLayers(spec);

      expect(NativeMixPlayer.channel.name, 'nocta/native_mix');
      expect(calls.single.method, 'play');
      final args = calls.single.arguments as Map;
      expect(args.keys.toSet(), {'buffers', 'sampleRate', 'gains'});

      // İki katman → iki ayrı buffer (tek mikslenmiş DEĞİL) + iki kazanç.
      final buffers = args['buffers'] as List;
      expect(buffers.length, 2);
      expect(args['gains'], [0.6, 0.4]);
      // Her buffer 16-bit PCM: 8000×1×2 bayt (sorunsuz döngü N örnek döndürür).
      expect((buffers.first as List).length, 8000 * 1 * 2);
    });

    test('ÇEKİRDEK: setGain index+gain gönderir (Kotlin canlı okur)', () async {
      final player = NativeMixPlayer();
      await player.setGain(1, 0.25);

      expect(calls.single.method, 'setGain');
      final args = calls.single.arguments as Map;
      expect(args.keys.toSet(), {'index', 'gain'});
      expect(args['index'], 1);
      expect(args['gain'], 0.25);
    });

    test('setGain kazancı [0,1]\'e clamp eder (bozuk değer native\'e sızmaz)', () async {
      final player = NativeMixPlayer();
      await player.setGain(0, 1.8);
      expect((calls.single.arguments as Map)['gain'], 1.0);
    });

    test('stop yöntemi', () async {
      await NativeMixPlayer().stop();
      expect(calls.single.method, 'stop');
    });
  });
}
