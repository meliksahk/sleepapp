import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:nocta/core/audio_engine/dsp/mix_render.dart';
import 'package:nocta/core/audio_engine/master_limiter.dart';
import 'package:nocta/core/audio_engine/mix_player.dart';
import 'package:nocta/features/mixer/mixer_controller.dart';
import 'package:nocta/features/mixer/presentation/mixer_screen.dart';
import 'package:nocta/l10n/app_localizations.dart';

/// **MASTER LİMİTLEYİCİ** — kırpma koruması.
///
/// ## Neden bu test var (ölçülmüş kusur)
///
/// `MixPlayer` Dart `Mixer`'ını KULLANMIYOR: her katmanı ayrı `AudioPlayer`'da
/// çalıp kazancı `setVolume` ile uyguluyor, toplama İŞLETİM SİSTEMİ mikserinde
/// oluyor. Orada ne clamp var ne kırpma raporu. Ölçüm: 7 sentez katmanı tam
/// kazançta → örneklerin %14.1'i kırpılıyor, tepe 1.333.
///
/// ## Bu testin GERÇEKTEN ölçtüğü şey
///
/// Kulakla "cızırtı yok" DEĞİL (o cihaz işi). Ölçülen: player'lara **gerçekten
/// yazılan** `setVolume` değerlerinin toplamı. Sahte player her çağrıyı
/// kaydediyor; iddia doğrudan o kayıtlardan doğrulanıyor — motorun kendi
/// raporladığı sayıdan değil.
class _FakePlayer implements AudioPlayer {
  /// Bu player'a yazılan TÜM ses seviyeleri, sırayla. Rampanın basamak
  /// büyüklüğü buradan ölçülüyor.
  final List<double> volumes = <double>[];

  double get lastVolume => volumes.isEmpty ? -1 : volumes.last;

  @override
  bool playing = false;

  @override
  Future<Duration?> setAudioSource(
    AudioSource source, {
    bool preload = true,
    int? initialIndex,
    Duration? initialPosition,
  }) async =>
      Duration.zero;

  @override
  Future<void> setVolume(double volume) async => volumes.add(volume);

  @override
  Future<void> setLoopMode(LoopMode mode) async {}

  @override
  Future<void> play() async => playing = true;

  @override
  Future<void> pause() async => playing = false;

  @override
  Future<void> dispose() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late List<_FakePlayer> created;

  /// Rampa testte GERÇEK ZAMAN beklemesin diye adım aralığı sıfır; adım SAYISI
  /// üretimdekiyle aynı (16) — yani ölçülen basamak büyüklüğü üretimdekiyle
  /// birebir aynı, yalnızca daha hızlı akıyor.
  MixPlayer buildPlayer({Duration ramp = Duration.zero}) {
    created = <_FakePlayer>[];
    return MixPlayer(
      loopSeconds: 1,
      sampleRate: 8000,
      limiterRampStep: ramp,
      loopRenderer: (r) async => renderLoopSync(r),
      playerFactory: () {
        final p = _FakePlayer();
        created.add(p);
        return p;
      },
    );
  }

  /// GERÇEKTEN uygulanan toplam: her player'ın SON `setVolume` değerinin
  /// toplamı. Motorun `outputTotalGain` alanına bakmıyoruz — o motorun kendi
  /// iddiası; burada iddianın player'lara ulaşıp ulaşmadığını ölçüyoruz.
  double measuredOutputTotal() =>
      created.fold<double>(0, (sum, p) => sum + p.lastVolume);

  /// Yedi sentez katmanı, hepsi TAM kazançta — kusuru üreten tarif.
  MixSpec sevenAtFullGain() => const MixSpec(<MixLayer>[
        MixLayer(id: 'brown', type: LayerSource.brown, gain: 1.0),
        MixLayer(id: 'pink', type: LayerSource.pink, gain: 1.0),
        MixLayer(id: 'white', type: LayerSource.white, gain: 1.0),
        MixLayer(id: 'waves', type: LayerSource.waves, gain: 1.0),
        MixLayer(id: 'rain', type: LayerSource.rain, gain: 1.0),
        MixLayer(id: 'fire', type: LayerSource.fire, gain: 1.0),
        MixLayer(id: 'pad', type: LayerSource.pad, gain: 1.0),
      ]);

  group('masterLimiterScale — saf matematik', () {
    test('tavanın altında ölçek YOK (limitleyici devreye girmez)', () {
      expect(masterLimiterScale(0.0), 1.0);
      expect(masterLimiterScale(0.5), 1.0);
      expect(masterLimiterScale(kMasterCeiling), 1.0);
      expect(isLimiterEngaged(masterLimiterScale(1.0)), isFalse);
    });

    test('tavanın üstünde ölçek tam olarak tavan/toplam', () {
      expect(masterLimiterScale(2.0), closeTo(0.5, 1e-12));
      expect(masterLimiterScale(7.0), closeTo(1 / 7, 1e-12));
      // Ölçek uygulandıktan sonra toplam TAM tavana oturur.
      expect(7.0 * masterLimiterScale(7.0), closeTo(kMasterCeiling, 1e-12));
    });

    test('negatif/sıfır toplam bölme hatası üretmez', () {
      expect(masterLimiterScale(0), 1.0);
      expect(masterLimiterScale(-1), 1.0);
    });
  });

  group('MixPlayer — ÇIKIŞ ÖLÇÜMÜ', () {
    test('ÇEKİRDEK: 7 katman @1.0 → uygulanan toplam ≤ 1.0', () async {
      final player = buildPlayer();
      await player.load(sevenAtFullGain());
      await player.settleLimiter();

      // İstenen toplam 7.0 — kusurun kendisi.
      expect(player.requestedTotalGain, closeTo(7.0, 1e-9));
      // Uygulanan toplam tavanı AŞMIYOR (player'lardan ölçüldü).
      expect(measuredOutputTotal(), lessThanOrEqualTo(kMasterCeiling + 1e-9));
      expect(measuredOutputTotal(), closeTo(1.0, 1e-9));
      expect(player.isLimiting, isTrue);
    });

    test('katmanların BİRBİRİNE oranı korunur (eşit → eşit kalır)', () async {
      final player = buildPlayer();
      await player.load(sevenAtFullGain());
      await player.settleLimiter();

      final applied = created.map((p) => p.lastVolume).toList();
      for (final v in applied) {
        expect(v, closeTo(1 / 7, 1e-9));
      }
    });

    test('DENGESİZ mikste de oran korunur, yalnız mutlak seviye iner',
        () async {
      final player = buildPlayer();
      await player.load(const MixSpec(<MixLayer>[
        MixLayer(id: 'a', type: LayerSource.brown, gain: 1.0),
        MixLayer(id: 'b', type: LayerSource.pink, gain: 0.5),
      ]));
      await player.settleLimiter();

      expect(measuredOutputTotal(), closeTo(1.0, 1e-9));
      // 1.0 : 0.5 oranı = 2:1 — ölçekten SONRA da 2:1.
      expect(
        created[0].lastVolume / created[1].lastVolume,
        closeTo(2.0, 1e-9),
      );
    });

    test('VARSAYILAN mikste limitleyici DEVREDE DEĞİL (gereksiz kısma yok)',
        () async {
      final player = buildPlayer();
      await player.load(defaultMixSpec());
      await player.settleLimiter();

      expect(player.limiterScale, 1.0);
      expect(player.isLimiting, isFalse);
      // Her katman İSTENEN kazancıyla çalıyor — hiçbiri kısılmadı.
      final spec = defaultMixSpec();
      for (var i = 0; i < spec.layers.length; i++) {
        expect(created[i].lastVolume, closeTo(spec.layers[i].gain, 1e-9));
      }
    });

    test('ASSET katmanı da toplama sayılır (OS mikseri ayrım yapmaz)',
        () async {
      final player = buildPlayer();
      // Sentez toplamı 0.6 — TEK BAŞINA tavanın altında. Asset'ler
      // sayılmasaydı limitleyici hiç devreye girmez, toplam 2.4 ile kırpardı.
      await player.load(const MixSpec(
        <MixLayer>[MixLayer(id: 'brown', type: LayerSource.brown, gain: 0.6)],
        assets: <AssetLayer>[
          AssetLayer(id: 'a1', title: 'A', url: 'file:///a.wav', gain: 0.9),
          AssetLayer(id: 'a2', title: 'B', url: 'file:///b.wav', gain: 0.9),
        ],
      ));
      await player.settleLimiter();

      expect(player.voiceCount, 3);
      expect(player.requestedTotalGain, closeTo(2.4, 1e-9));
      expect(measuredOutputTotal(), lessThanOrEqualTo(kMasterCeiling + 1e-9));
      expect(player.isLimiting, isTrue);
    });

    test('ÇALARKEN eklenen asset limitleyiciyi yeniden tetikler', () async {
      final player = buildPlayer();
      await player.load(const MixSpec(<MixLayer>[
        MixLayer(id: 'brown', type: LayerSource.brown, gain: 0.9),
      ]));
      await player.settleLimiter();
      expect(player.isLimiting, isFalse, reason: '0.9 tavanın altında');

      await player.addAsset(
        const AssetLayer(id: 'a1', title: 'A', url: 'file:///a.wav', gain: 0.9),
      );
      await player.settleLimiter();

      expect(player.isLimiting, isTrue);
      expect(measuredOutputTotal(), lessThanOrEqualTo(kMasterCeiling + 1e-9));
    });

    test('katman KALDIRILINCA limitleyici gevşer (kalıcı kısma yok)', () async {
      final player = buildPlayer();
      await player.load(const MixSpec(
        <MixLayer>[MixLayer(id: 'brown', type: LayerSource.brown, gain: 0.8)],
        assets: <AssetLayer>[
          AssetLayer(id: 'a1', title: 'A', url: 'file:///a.wav', gain: 0.8),
        ],
      ));
      await player.settleLimiter();
      expect(player.isLimiting, isTrue);

      await player.removeVoice('a1');
      await player.settleLimiter();

      expect(player.isLimiting, isFalse);
      // Kalan katman KENDİ istediği kazanca geri döndü — limitin izi kalmadı.
      expect(created[0].lastVolume, closeTo(0.8, 1e-9));
    });
  });

  group('SÜRGÜ DEĞERLERİ — kullanıcının eli kaydırılmaz', () {
    test('setLayerGain istenen kazancı SAKLAR, çıkışı ölçekler', () async {
      final player = buildPlayer();
      await player.load(const MixSpec(<MixLayer>[
        MixLayer(id: 'a', type: LayerSource.brown, gain: 0.2),
        MixLayer(id: 'b', type: LayerSource.pink, gain: 0.2),
      ]));

      // Kullanıcı iki sürgüyü de tepeye çekiyor → istenen toplam 2.0.
      await player.setLayerGain('a', 1.0);
      await player.setLayerGain('b', 1.0);
      await player.settleLimiter();

      // İSTENEN değer korundu (sürgüde 1.0 yazmaya devam eder)...
      expect(player.requestedTotalGain, closeTo(2.0, 1e-9));
      // ...ama ÇIKIŞ tavanda.
      expect(measuredOutputTotal(), closeTo(1.0, 1e-9));
      expect(player.limiterScale, closeTo(0.5, 1e-9));
    });

    test('TEKRAR TEKRAR tetiklemek kazancı AŞAĞI SÜRÜKLEMEZ', () async {
      // Regresyon kilidi: uygulanan değeri geri okuyup kaynak kabul eden bir
      // uygulama, her tetiklemede kazancı bir kat daha kısardı (0.5 → 0.25 →
      // 0.125...). İstenen kazanç ayrı saklandığı için bu olamaz.
      final player = buildPlayer();
      await player.load(const MixSpec(<MixLayer>[
        MixLayer(id: 'a', type: LayerSource.brown, gain: 1.0),
        MixLayer(id: 'b', type: LayerSource.pink, gain: 1.0),
      ]));
      await player.settleLimiter();

      for (var i = 0; i < 5; i++) {
        await player.setLayerGain('a', 1.0);
        await player.settleLimiter();
      }

      expect(player.requestedTotalGain, closeTo(2.0, 1e-9));
      expect(player.limiterScale, closeTo(0.5, 1e-9));
      expect(measuredOutputTotal(), closeTo(1.0, 1e-9));
    });

    test('MixerController state.gains limitten ETKİLENMEZ', () async {
      final c = MixerController(
        spec: sevenAtFullGain(),
        player: buildPlayer(),
      );
      await c.prepare();

      // Yedi sürgünün hepsi hâlâ 1.0 — kullanıcının eli kaymadı.
      expect(c.state.gains.values.every((g) => g == 1.0), isTrue);
      expect(c.state.isLimiting, isTrue);
    });
  });

  group('RAMPA — ani seviye sıçraması yok', () {
    test('limit DEVREYE GİRERKEN ölçek adım adım iner', () async {
      final player = buildPlayer();
      final scales = <double>[];
      player.onLimiterChanged = scales.add;

      // Başlangıç: tavanın altında, ölçek 1.0.
      await player.load(const MixSpec(<MixLayer>[
        MixLayer(id: 'a', type: LayerSource.brown, gain: 0.4),
        MixLayer(id: 'b', type: LayerSource.pink, gain: 0.4),
      ]));
      await player.settleLimiter();
      expect(player.limiterScale, 1.0);

      scales.clear();
      // Sert bir hamle: toplam 0.8 → 4.0, hedef ölçek 0.25.
      await player.setLayerGain('a', 2.0); // clamp → 1.0
      await player.setLayerGain('b', 1.0);
      await player.settleLimiter();

      expect(player.limiterScale, closeTo(0.5, 1e-9));
      expect(scales.length, greaterThan(1),
          reason: 'tek adımda sıçramadı, rampalandı');

      // Hiçbir adım, adım büyüklüğünü (1/16) aşmıyor — "ani sıçrama yok"un
      // ölçülebilir tanımı bu.
      var previous = 1.0;
      for (final s in scales) {
        expect((s - previous).abs(), lessThanOrEqualTo(1 / 16 + 1e-9),
            reason: 'ölçek $previous → $s tek adımda çok fazla değişti');
        previous = s;
      }
    });

    test('limit ÇIKARKEN de rampalanır', () async {
      final player = buildPlayer();
      await player.load(const MixSpec(<MixLayer>[
        MixLayer(id: 'a', type: LayerSource.brown, gain: 1.0),
        MixLayer(id: 'b', type: LayerSource.pink, gain: 1.0),
      ]));
      await player.settleLimiter();
      expect(player.limiterScale, closeTo(0.5, 1e-9));

      final scales = <double>[];
      player.onLimiterChanged = scales.add;
      await player.setLayerGain('b', 0.0); // toplam 1.0 → limit gerekmiyor
      await player.settleLimiter();

      expect(player.limiterScale, 1.0);
      var previous = 0.5;
      for (final s in scales) {
        expect((s - previous).abs(), lessThanOrEqualTo(1 / 16 + 1e-9));
        previous = s;
      }
      expect(scales.length, greaterThan(1), reason: 'çıkışta da rampa var');
    });

    test('rampa sürerken gelen YENİ hedef ikinci rampa açmaz, yakalanır',
        () async {
      final player = buildPlayer();
      await player.load(const MixSpec(<MixLayer>[
        MixLayer(id: 'a', type: LayerSource.brown, gain: 0.2),
        MixLayer(id: 'b', type: LayerSource.pink, gain: 0.2),
      ]));
      await player.settleLimiter();

      // Beklemeden art arda iki hamle: ikincisi ilk rampa sürerken geliyor.
      final first = player.setLayerGain('a', 1.0);
      final second = player.setLayerGain('b', 1.0);
      await Future.wait(<Future<void>>[first, second]);
      await player.settleLimiter();

      // Son hedefe oturdu (ilk hedefte takılı kalmadı).
      expect(player.limiterScale, closeTo(0.5, 1e-9));
      expect(measuredOutputTotal(), closeTo(1.0, 1e-9));
    });

    test('yeniden load ölçeği SIFIRLAR (önceki mix in limitini miras almaz)',
        () async {
      final player = buildPlayer();
      await player.load(sevenAtFullGain());
      await player.settleLimiter();
      expect(player.isLimiting, isTrue);

      await player.load(defaultMixSpec());
      await player.settleLimiter();
      expect(player.limiterScale, 1.0);
      expect(player.isLimiting, isFalse);
    });
  });

  group('GÖSTERGE — limitleyici sessiz değil', () {
    Widget wrap(MixerController c) => ProviderScope(
          child: MaterialApp(
            localizationsDelegates: AppL10n.localizationsDelegates,
            supportedLocales: AppL10n.supportedLocales,
            home: MixerScreen(controller: c, canExportVideo: false),
          ),
        );

    testWidgets('limit DEVREDEYKEN gösterge görünür', (tester) async {
      final c = MixerController(spec: sevenAtFullGain(), player: buildPlayer());
      await tester.pumpWidget(wrap(c));
      await c.prepare();
      await tester.pumpAndSettle();

      final notice = find.byKey(const Key('mixer-limiter-notice'));
      expect(notice, findsOneWidget);
      // Metin GERÇEK kısma oranını söylüyor: 7 katman → ölçek 1/7 → %86 kısıntı.
      expect(c.state.limiterReductionPercent, 86);
      expect(
        tester.widget<Text>(notice).data,
        contains('86'),
        reason: 'gösterge, ne kadar kısıldığını SÖYLEMELİ',
      );
    });

    testWidgets('VARSAYILAN mikste gösterge YOK (gereksiz uyarı üretme)',
        (tester) async {
      final c = MixerController(spec: defaultMixSpec(), player: buildPlayer());
      await tester.pumpWidget(wrap(c));
      await c.prepare();
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('mixer-limiter-notice')), findsNothing);
    });

    testWidgets('sürgü tepeye çekilince gösterge BELİRİR', (tester) async {
      final c = MixerController(
        spec: const MixSpec(<MixLayer>[
          MixLayer(id: 'a', type: LayerSource.brown, gain: 0.4),
          MixLayer(id: 'b', type: LayerSource.pink, gain: 0.4),
        ]),
        player: buildPlayer(),
      );
      await tester.pumpWidget(wrap(c));
      await c.prepare();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('mixer-limiter-notice')), findsNothing);

      await c.setGain('a', 1.0);
      await c.setGain('b', 1.0);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('mixer-limiter-notice')), findsOneWidget);
      // Sürgüler kullanıcının bıraktığı yerde — gösterge onları oynatmadı.
      expect(c.state.gains['a'], 1.0);
      expect(c.state.gains['b'], 1.0);
    });
  });
}
