import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:nocta/core/audio_engine/dsp/mix_render.dart';
import 'package:nocta/core/audio_engine/mix_player.dart';
import 'package:nocta/features/mixer/mixer_controller.dart';

/// Mikser denetleyicisi — cihazsız.
///
/// Burada kanıtlanan şey "ses duyuluyor" DEĞİL (o emülatör/cihaz işi). Kanıtlanan:
/// **slider yeniden render TETİKLEMİYOR**. Bu, mimarinin can damarı — tetikleseydi
/// her slider hareketinde ses kesilir ve tık olurdu.
class _FakePlayer implements AudioPlayer {
  int setVolumeCalls = 0;
  int setAudioSourceCalls = 0;
  double lastVolume = -1;
  @override
  bool playing = false;

  @override
  Future<Duration?> setAudioSource(
    AudioSource source, {
    bool preload = true,
    int? initialIndex,
    Duration? initialPosition,
  }) async {
    setAudioSourceCalls++;
    return Duration.zero;
  }

  @override
  Future<void> setVolume(double volume) async {
    setVolumeCalls++;
    lastVolume = volume;
  }

  @override
  Future<void> setLoopMode(LoopMode mode) async {}

  @override
  Future<void> play() async {
    playing = true;
  }

  @override
  Future<void> pause() async {
    playing = false;
  }

  @override
  Future<void> dispose() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  const spec = MixSpec([
    MixLayer(id: 'brown', type: LayerSource.brown, gain: 0.4),
    MixLayer(id: 'pink', type: LayerSource.pink, gain: 0.2),
  ]);

  late List<_FakePlayer> created;

  MixerController build() {
    created = [];
    return MixerController(
      spec: spec,
      player: MixPlayer(
      // Üretimde render ayrı isolate'te (compute) yapılır; widget testinin sabit
      // pump döngüleri gerçek bir isolate'i beklemez. Senkron renderer enjekte
      // ediyoruz — `playerFactory` ile aynı desen.
      loopRenderer: (r) async => renderLoopSync(r),
        // 1 sn: test hızlı koşsun (30 sn render × katman = yavaş).
        loopSeconds: 1,
        sampleRate: 8000,
        playerFactory: () {
          final p = _FakePlayer();
          created.add(p);
          return p;
        },
      ),
    );
  }

  test('başlangıç durumu spec katmanlarını ve kazançlarını taşır', () {
    final c = build();
    expect(c.state.layers.length, 2);
    expect(c.state.gains, {'brown': 0.4, 'pink': 0.2});
    expect(c.state.isPlaying, isFalse);
  });

  test('prepare: KATMAN BAŞINA bir player (tek karışık buffer DEĞİL)', () async {
    final c = build();
    await c.prepare();

    expect(created.length, 2, reason: 'katman başına ayrı player');
    for (final p in created) {
      expect(p.setAudioSourceCalls, 1);
    }
  });

  test('prepare: her player kendi katmanının kazancıyla başlar', () async {
    final c = build();
    await c.prepare();
    expect(created[0].lastVolume, 0.4);
    expect(created[1].lastVolume, 0.2);
  });

  test('ÇEKİRDEK: slider YENİDEN RENDER tetiklemez — yalnızca setVolume', () async {
    final c = build();
    await c.prepare();
    final sourcesAfterPrepare = created.map((p) => p.setAudioSourceCalls).toList();

    await c.setGain('brown', 0.9);
    await c.setGain('brown', 0.1);
    await c.setGain('pink', 0.7);

    // Yeniden yüklenseydi ses kesilir, tık olurdu.
    expect(created.map((p) => p.setAudioSourceCalls).toList(), sourcesAfterPrepare);
    expect(created[0].lastVolume, 0.1);
    expect(created[1].lastVolume, 0.7);
  });

  test('setGain durumu günceller (UI slider\'ı takip eder)', () async {
    final c = build();
    await c.prepare();
    await c.setGain('brown', 0.75);
    expect(c.state.gains['brown'], 0.75);
  });

  test('toggle: hazırlanmamışsa önce prepare eder, sonra çalar', () async {
    final c = build();
    await c.toggle();

    expect(created.length, 2, reason: 'toggle prepare tetiklemeli');
    expect(created.every((p) => p.playing), isTrue);
    expect(c.state.isPlaying, isTrue);
  });

  test('toggle ikinci kez: duraklatır ve YENİDEN RENDER ETMEZ', () async {
    final c = build();
    await c.toggle();
    final sources = created.map((p) => p.setAudioSourceCalls).toList();

    await c.toggle();

    expect(c.state.isPlaying, isFalse);
    expect(created.every((p) => p.playing), isFalse);
    expect(created.map((p) => p.setAudioSourceCalls).toList(), sources);
  });

  test('bilinmeyen katman id\'si sesi KESMEZ (sessizce yok sayılır)', () async {
    final c = build();
    await c.prepare();
    await c.setGain('boyle-bir-katman-yok', 0.5);
    expect(created[0].lastVolume, 0.4, reason: 'diğer katmanlar etkilenmedi');
  });

  test('onChanged her durum değişiminde tetiklenir (UI çizilsin)', () async {
    final c = build();
    var calls = 0;
    c.onChanged = () => calls++;
    await c.prepare();
    await c.setGain('pink', 0.5);
    expect(calls, greaterThanOrEqualTo(2));
  });

  test('varsayılan mix kazançları toplamı 1.0 altında (OS kırpmasın)', () {
    // Referans mikserin kompresörü bu yolda devrede DEĞİL (bkz. MixPlayer);
    // toplam 1'i aşarsa işletim sistemi mikserinde kırpma olur.
    final total = defaultMixSpec().layers.fold<double>(0, (a, l) => a + l.gain);
    expect(total, lessThanOrEqualTo(1.0));
  });
}
