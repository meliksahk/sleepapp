import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:nocta/core/audio_engine/dsp/mix_render.dart';
import 'package:nocta/core/audio_engine/mix_player.dart';
import 'package:nocta/features/content/content_models.dart';
import 'package:nocta/features/content/content_providers.dart';
import 'package:nocta/features/mixer/mixer_controller.dart';
import 'package:nocta/features/mixer/presentation/mixer_route.dart';
import 'package:nocta/l10n/app_localizations.dart';

/// `/mixer?soundscape=<slug>` — kütüphanedeki sesin GERÇEKTEN çalındığı yol.

class _FakePlayer implements AudioPlayer {
  double lastVolume = -1;
  @override
  bool playing = false;

  @override
  Future<Duration?> setAudioSource(
    AudioSource source, {
    bool preload = true,
    int? initialIndex,
    Duration? initialPosition,
  }) async => Duration.zero;

  @override
  Future<void> setVolume(double volume) async => lastVolume = volume;

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

late List<_FakePlayer> _createdPlayers;

/// Cihazsız controller: gerçek DSP zinciri koşar, yalnızca hoparlör sahtedir.
MixerController _testController(MixSpec spec) {
  return MixerController(
    spec: spec,
    player: MixPlayer(
      // Üretimde render ayrı isolate'te (compute) yapılır; widget testinin sabit
      // pump döngüleri gerçek bir isolate'i beklemez. Senkron renderer enjekte
      // ediyoruz — `playerFactory` ile aynı desen.
      loopRenderer: (r) async => renderLoopSync(r),
      loopSeconds: 1, // 30 sn render testi yavaşlatırdı
      sampleRate: 8000,
      playerFactory: () {
        final p = _FakePlayer();
        _createdPlayers.add(p);
        return p;
      },
    ),
  );
}

SoundscapeDetail _detailWithSpec(MixSpec spec) => SoundscapeDetail(
  soundscape: Soundscape(
    id: 'id',
    slug: 'deep-ocean-hush',
    titleI18n: const {'en': 'Deep Ocean Hush'},
    archetypeAffinity: const [],
    version: 1,
    mixSpec: spec,
  ),
  presets: const [],
  previewUrl: null,
);

Future<void> _pump(
  WidgetTester tester, {
  required String? slug,
  required List<Override> overrides,
  bool withFactory = false,
}) async {
  _createdPlayers = [];
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        home: MixerRoute(
          soundscapeSlug: slug,
          controllerFactory: withFactory ? _testController : null,
        ),
      ),
    ),
  );
}

double _sliderValue(WidgetTester tester, String id) =>
    tester.widget<Slider>(find.byKey(Key('gain-$id'))).value;

void main() {
  const oceanSpec = MixSpec([
    MixLayer(id: 'deep', type: LayerSource.brown, gain: 0.5),
    MixLayer(id: 'surf', type: LayerSource.pink, gain: 0.25),
  ]);

  testWidgets('slug verilince mikser O SESİN tarifiyle kurulur', (tester) async {
    await _pump(
      tester,
      slug: 'deep-ocean-hush',
      overrides: [
        soundscapeDetailProvider(
          'deep-ocean-hush',
        ).overrideWith((ref) async => _detailWithSpec(oceanSpec)),
      ],
    );
    await tester.pumpAndSettle();

    // Katman id'leri soundscape'in tarifinden geliyor — varsayılandan DEĞİL.
    expect(find.byKey(const Key('gain-deep')), findsOneWidget);
    expect(find.byKey(const Key('gain-surf')), findsOneWidget);
    expect(find.byKey(const Key('gain-brown')), findsNothing);

    // Kazançlar da tarifin kendisi.
    expect(_sliderValue(tester, 'deep'), 0.5);
    expect(_sliderValue(tester, 'surf'), 0.25);

    // Kendi tarifi çalıyor → dipnot yok.
    expect(find.byKey(const Key('mixer-recipe-fallback')), findsNothing);

    // Başlık AÇILAN SESİN ADI — jenerik "Mixer" değil. Kullanıcı belirli bir
    // sesi seçip geliyordu ama hangisini duyduğunu söyleyen tek işaret yoktu.
    expect(
      tester.widget<Text>(find.byKey(const Key('mixer-title'))).data,
      'Deep Ocean Hush',
    );
  });

  testWidgets('slug yoksa varsayılan mikser (içerik isteği YOK)', (
    tester,
  ) async {
    var requested = false;
    await _pump(
      tester,
      slug: null,
      overrides: [
        soundscapeDetailProvider('deep-ocean-hush').overrideWith((ref) async {
          requested = true;
          return null;
        }),
      ],
    );
    await tester.pumpAndSettle();

    expect(requested, isFalse, reason: 'slug yokken ağa çıkılmamalı');
    expect(find.byKey(const Key('gain-brown')), findsOneWidget);
    expect(find.byKey(const Key('mixer-recipe-fallback')), findsNothing);

    // Ses seçilmemiş → jenerik başlık (uydurma bir ad yazmak yanıltıcı olurdu).
    expect(
      tester.widget<Text>(find.byKey(const Key('mixer-title'))).data,
      'Mixer',
    );
  });

  testWidgets('bilinmeyen slug (null) → varsayılan tarif + nazik dipnot', (
    tester,
  ) async {
    await _pump(
      tester,
      slug: 'boyle-bir-ses-yok',
      overrides: [
        soundscapeDetailProvider(
          'boyle-bir-ses-yok',
        ).overrideWith((ref) async => null),
      ],
    );
    await tester.pumpAndSettle();

    // HATA EKRANI DEĞİL: mikser açık, katmanlar yerinde.
    expect(find.byKey(const Key('gain-brown')), findsOneWidget);
    expect(find.byKey(const Key('mixer-recipe-fallback')), findsOneWidget);
  });

  testWidgets('OFFLINE: içerik isteği patlarsa mikser yine açılır', (
    tester,
  ) async {
    await _pump(
      tester,
      slug: 'deep-ocean-hush',
      overrides: [
        soundscapeDetailProvider(
          'deep-ocean-hush',
        ).overrideWith((ref) async => throw Exception('ağ yok')),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('gain-brown')), findsOneWidget);
    expect(find.byKey(const Key('mixer-recipe-fallback')), findsOneWidget);
    // Çal butonu ETKİN — kullanıcı ağsız da ses açabilir.
    final toggle = tester.widget<FilledButton>(
      find.byKey(const Key('mixer-toggle')),
    );
    expect(toggle.onPressed, isNotNull);
  });

  testWidgets(
    'DÜRÜSTLÜK MANDALI: bütçe dolduktan SONRA gelen yanıt dipnotu SİLEMEZ',
    (tester) async {
      // Üç ayrı denetim merceği bu yolu bağımsız olarak yakaladı ve mandal
      // eklenmeden ÖNCE bu test kırılıyordu: bütçe dolup varsayılanla açıldıktan
      // sonra ağ yanıtı geç gelince `usedFallback` false oluyor ve dipnot
      // ekrandan siliniyordu — ama ÇALAN SES hâlâ varsayılan mix (spec yalnızca
      // initState'te okunur, bilinçli). Yani kullanıcı seçtiği sesi duymuyor ve
      // bunu söyleyen tek işaret de kayboluyordu.
      final late$ = Completer<SoundscapeDetail?>();

      await _pump(
        tester,
        slug: 'deep-ocean-hush',
        withFactory: true,
        overrides: [
          soundscapeDetailProvider(
            'deep-ocean-hush',
          ).overrideWith((ref) => late$.future),
        ],
      );
      await tester.pump();

      // Bütçe dolar → varsayılan tarif + dürüst dipnot.
      await tester.pump(const Duration(seconds: 4));
      expect(find.byKey(const Key('gain-brown')), findsOneWidget);
      expect(find.byKey(const Key('mixer-recipe-fallback')), findsOneWidget);

      // Yanıt GEÇ gelir (gerçek tarifle).
      late$.complete(_detailWithSpec(MixSpec(const [
        MixLayer(id: 'deep', type: LayerSource.brown, gain: 0.5),
      ])));
      await tester.pump();
      await tester.pump();

      // Ses DEĞİŞMEZ (çalanı kesmeyiz) — ve tam da bu yüzden dipnot KALIR.
      expect(find.byKey(const Key('gain-brown')), findsOneWidget);
      expect(find.byKey(const Key('gain-deep')), findsNothing);
      expect(
        find.byKey(const Key('mixer-recipe-fallback')),
        findsOneWidget,
        reason: 'kullanıcı hâlâ varsayılanı duyuyor; dipnot silinemez',
      );
    },
  );

  testWidgets(
    'OFFLINE: istek asla dönmezse bütçe dolar, mikser varsayılanla AÇILIR ve ÇALAR',
    (tester) async {
      // API istemcisinde timeout yok: ölü bağlantıda future hiç tamamlanmaz.
      final never = Completer<SoundscapeDetail?>();
      addTearDown(() => never.complete(null));

      await _pump(
        tester,
        slug: 'deep-ocean-hush',
        withFactory: true,
        overrides: [
          soundscapeDetailProvider(
            'deep-ocean-hush',
          ).overrideWith((ref) => never.future),
        ],
      );
      await tester.pump();

      // Önce bekliyor...
      expect(find.byKey(const Key('mixer-resolving')), findsOneWidget);

      // ...bütçe dolunca varsayılanla açılıyor (pumpAndSettle DEĞİL: spinner
      // sonsuz animasyon, settle etmez).
      await tester.pump(const Duration(seconds: 4));
      expect(find.byKey(const Key('mixer-resolving')), findsNothing);
      expect(find.byKey(const Key('gain-brown')), findsOneWidget);
      expect(find.byKey(const Key('mixer-recipe-fallback')), findsOneWidget);

      // ÇALIYOR kanıtı: çal'a bas → DSP zinciri koşar, her katman için bir
      // player yüklenir ve çalmaya başlar.
      await tester.tap(find.byKey(const Key('mixer-toggle')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(_createdPlayers.length, defaultMixSpec().layers.length);
      expect(_createdPlayers.every((p) => p.playing), isTrue);
      expect(find.byKey(const Key('mixer-error')), findsNothing);
    },
  );

  testWidgets('SES GÜVENLİĞİ: yüksek tarif kırpma sınırına ölçeklenir', (
    tester,
  ) async {
    const loud = MixSpec([
      MixLayer(id: 'a', type: LayerSource.white, gain: 1.0),
      MixLayer(id: 'b', type: LayerSource.pink, gain: 1.0),
    ]);
    await _pump(
      tester,
      slug: 'gurultu',
      overrides: [
        soundscapeDetailProvider(
          'gurultu',
        ).overrideWith((ref) async => _detailWithSpec(loud)),
      ],
    );
    await tester.pumpAndSettle();

    expect(_sliderValue(tester, 'a') + _sliderValue(tester, 'b'), closeTo(1, 1e-9));
  });
}
