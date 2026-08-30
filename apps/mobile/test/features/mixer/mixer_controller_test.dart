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

  /// Master limitleyicinin rampası ASENKRON: `setGain` döndüğünde ölçek henüz
  /// hedefine yürümemiş olabilir. Uygulanan ses seviyesini ölçen testler önce
  /// bunu beklemeli, yoksa rampanın ortasındaki geçici değeri ölçerler.
  late MixPlayer player;

  MixerController build() {
    created = [];
    player = MixPlayer(
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
    );
    return MixerController(spec: spec, player: player);
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
    // Ara adımda toplam 1.1'e çıkıp master limitleyiciyi TETİKLEDİ; rampa
    // ölçeği 1.0'dan indirmeye başladı. Son durumda toplam 0.8 (tavanın altı),
    // yani ölçek 1.0'a GERİ dönmeli — ama rampa asenkron. Beklemezsek burada
    // rampanın ortasındaki değeri (0.1 × 0.9375 = 0.09375) ölçeriz.
    await player.settleLimiter();

    // Yeniden yüklenseydi ses kesilir, tık olurdu.
    expect(created.map((p) => p.setAudioSourceCalls).toList(), sourcesAfterPrepare);
    // Limitleyici DEVREDE DEĞİLKEN uygulanan seviye = sürgü değeri, birebir.
    expect(player.isLimiting, isFalse, reason: 'toplam 0.8, tavanın altında');
    expect(created[0].lastVolume, closeTo(0.1, 1e-9));
    expect(created[1].lastVolume, closeTo(0.7, 1e-9));
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

  group('tone katmanı — kullanıcı Hz seçip ekler', () {
    test('hazırlanmamış mikserde yalnızca state\'e girer (player YOK)', () async {
      final c = build();
      final before = created.length;

      final outcome = await c.addToneLayer(110);

      expect(outcome, AddToneOutcome.added);
      expect(created.length, before, reason: 'mix hazır değil → canlı ekleme yok');
      expect(c.state.layers.last.type, LayerSource.tone);
      expect(c.state.layers.last.frequencyHz, 110);
      // Kullanıcının eklediği katman KALDIRILABİLİR olmalı.
      expect(c.state.userAddedSynthIds, contains('tone'));
    });

    test('prepare sonrası CANLI eklenir ve çalıyorsa hemen başlar', () async {
      final c = build();
      await c.prepare();
      await c.toggle(); // çalıyor
      final before = created.length;

      await c.addToneLayer(110);

      expect(created.length, before + 1, reason: 'yeni katmana yeni player');
      expect(created.last.playing, isTrue,
          reason: 'mix çalarken eklenen katman da başlamalı');
      expect(player.voiceCount, 3);
    });

    test('id benzersiz üretilir: tone, tone-2 ...', () async {
      final c = build();
      await c.addToneLayer(110);
      await c.addToneLayer(220);
      expect(
        c.state.userAddedSynthIds.toSet().length,
        c.state.userAddedSynthIds.length,
        reason: 'çakışan id sürgünün yanlış katmanı oynatması demekti',
      );
      expect(c.state.gains.keys, containsAll(<String>['tone', 'tone-2']));
    });

    test('removeLayer: kullanıcının katmanı state\'ten VE sesi düşer', () async {
      final c = build();
      await c.prepare();
      await c.addToneLayer(110);
      expect(player.voiceCount, 3);

      await c.removeLayer(c.state.userAddedSynthIds.first);

      expect(player.voiceCount, 2,
          reason: 'kaldırılan katmanın sesi de SUSMALI — "kaldırdım ama duyuyorum" olmaz');
      expect(c.state.layers.any((l) => l.id == 'tone'), isFalse);
      expect(c.state.gains.containsKey('tone'), isFalse);
      expect(c.state.userAddedSynthIds, isEmpty);
    });

    test('tariften gelen sentez satırı DA kaldırılabilir (mikser serbest araç)', () async {
      final c = build();
      await c.prepare();

      await c.removeLayer('brown');

      expect(c.state.layers.any((l) => l.id == 'brown'), isFalse,
          reason: 'mikser serbest araçtır; tarif başlangıç noktasıdır, kısıt değil');
    });

    test('tavan doluysa full döner, hiçbir şey değişmez', () async {
      final c = build();
      // spec 2 + 6 ton = 8 (tavan)
      for (var i = 0; i < MixerController.maxTotalLayers - 2; i++) {
        expect(await c.addToneLayer(110), AddToneOutcome.added);
      }
      expect(c.state.layers.length + c.state.assets.length,
          MixerController.maxTotalLayers);

      final outcome = await c.addToneLayer(440);

      expect(outcome, AddToneOutcome.full);
      expect(c.state.layers.length + c.state.assets.length,
          MixerController.maxTotalLayers,
          reason: 'tavan aşılmamalı: sessizce eklemek bütçeyi çiğner');
    });

    test('currentSpec frekansı TAŞIR (export yolu render assert\'ini yememeli)', () async {
      final c = build();
      await c.addToneLayer(110);
      final layer =
          c.currentSpec().layers.firstWhere((l) => l.type == LayerSource.tone);
      expect(layer.frequencyHz, 110);
    });

    test('beatHz > 0 katmana TAŞINIR; 0/null → mono (alan hiç yazılmaz)', () async {
      final c = build();
      await c.addToneLayer(200, beatHz: 8);
      await c.addToneLayer(150); // beat yok

      final layers = c.currentSpec().layers.where((l) => l.type == LayerSource.tone);
      final withBeat = layers.firstWhere((l) => l.id == 'tone');
      final mono = layers.firstWhere((l) => l.id == 'tone-2');
      expect(withBeat.beatHz, 8);
      expect(mono.beatHz, isNull, reason: '0 yerine null: mono tek gösterim olsun');
    });
  });
}
