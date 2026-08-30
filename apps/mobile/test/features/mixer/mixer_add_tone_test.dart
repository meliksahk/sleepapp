import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:nocta/core/audio_engine/dsp/mix_render.dart';
import 'package:nocta/core/audio_engine/mix_player.dart';
import 'package:nocta/features/mixer/domain/local_sound_library.dart';
import 'package:nocta/features/mixer/mixer_controller.dart';
import 'package:nocta/features/mixer/mixer_providers.dart';
import 'package:nocta/features/mixer/presentation/mixer_screen.dart';
import 'package:nocta/l10n/app_localizations.dart';

/// "Ton ekle" — kullanıcının Hz SEÇİP mikse sentez katmanı eklediği yol.
///
/// DSP zinciri `tone_test.dart`'ta, controller `mixer_controller_test.dart`'ta
/// kanıtlandı. Buradaki konu SON HALKA: ekranda buton var, sheet açılıyor,
/// seçilen frekans katmana dönüşüyor ve satır KALDIRILABİLİYOR.
class _FakePlayer implements AudioPlayer {
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
  Future<void> setVolume(double volume) async {}

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
  MixerController buildController() => MixerController(
        spec: const MixSpec(<MixLayer>[
          MixLayer(id: 'brown', type: LayerSource.brown, gain: 0.3),
        ]),
        player: MixPlayer(
          loopSeconds: 1,
          sampleRate: 8000,
          loopRenderer: (r) async => renderLoopSync(r),
          playerFactory: _FakePlayer.new,
        ),
      );

  Widget wrap(MixerController c) {
    return ProviderScope(
      overrides: <Override>[
        // Sheet'in kardeşi katalog sağlayıcısına uzanmaz ama yerel kütüphane
        // provider'ı override edilmezse path_provider'a düşer (mevcut test
        // dosyasındaki aynı tuzak).
        localSoundLibraryProvider.overrideWithValue(InMemoryLocalSoundLibrary()),
      ],
      child: MaterialApp(
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        home: MixerScreen(controller: c, canExportVideo: false),
      ),
    );
  }

  Future<void> openToneSheet(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('mixer-add-tone')));
    await tester.pumpAndSettle();
  }

  testWidgets('"Ton ekle" butonu görünür ve sheet\'i açar', (tester) async {
    final c = buildController();
    await tester.pumpWidget(wrap(c));
    await tester.pump();

    expect(find.byKey(const Key('mixer-add-tone')), findsOneWidget);
    await openToneSheet(tester);

    expect(find.byKey(const Key('add-tone-title')), findsOneWidget);
    expect(find.byKey(const Key('add-tone-slider')), findsOneWidget);
    expect(find.byKey(const Key('add-tone-confirm')), findsOneWidget);
    // Nota ön ayarları görünür (A2 başta).
    expect(find.byKey(const Key('add-tone-note-A2')), findsOneWidget);
  });

  testWidgets('gösterilen değer DUYULAN (ızgaraya oturmuş) değerdir', (tester) async {
    final c = buildController();
    await tester.pumpWidget(wrap(c));
    await tester.pump();
    await openToneSheet(tester);

    // Başlangıç A2 = 110 → ızgarada tam 110.
    expect(find.text('110 Hz'), findsOneWidget);

    // C3'e dokun: etiket 130.81 DEĞİL, oturmuş değeri gösterir.
    await tester.tap(find.byKey(const Key('add-tone-note-C3')));
    await tester.pumpAndSettle();

    expect(find.text('130.8 Hz'), findsOneWidget,
        reason: 'motor 30 sn döngüde 3924 periyot = 130.8 Hz üretir; '
            'ekranda istenen ham değer yazsaydı yalan olurdu');
  });

  testWidgets('onay → katman eklenir, Hz\'li etiket ve kaldırma butonu görünür',
      (tester) async {
    final c = buildController();
    await tester.pumpWidget(wrap(c));
    await tester.pump();
    await openToneSheet(tester);

    await tester.tap(find.byKey(const Key('add-tone-confirm')));
    await tester.pumpAndSettle();

    expect(c.state.layers.any((l) => l.id == 'tone'), isTrue);
    // Etiket DUYULAN frekansı taşır (i18n adı + grid değeri); vuru kapalı
    // olduğundan etikette vuru kısmı YOKTUR.
    expect(find.text('Pure tone · 110 Hz'), findsOneWidget);
    expect(find.byKey(const Key('remove-tone')), findsOneWidget);
  });

  testWidgets('vuru sürgüsü: varsayılan Kapalı, açınca değer ve etiket oturur',
      (tester) async {
    final c = buildController();
    await tester.pumpWidget(wrap(c));
    await tester.pump();
    await openToneSheet(tester);

    // Başlangıç: KAPALI (binaural opt-in'dir).
    expect(find.text('Off'), findsOneWidget);

    // Vuru sürgüsünü 8'e getir: 0–20 aralığında 40 divisions → her adım 0.5.
    final beatSlider = find.byKey(const Key('add-tone-beat-slider'));
    await tester.drag(beatSlider, const Offset(120, 0));
    await tester.pumpAndSettle();

    final valueText = tester.widget<Text>(find.byKey(const Key('add-tone-beat-value')));
    expect(valueText.data, isNot('Off'), reason: 'sürgü hareketi değeri Off dışına çıkardı');

    await tester.tap(find.byKey(const Key('add-tone-confirm')));
    await tester.pumpAndSettle();

    final layer = c.state.layers.firstWhere((l) => l.type == LayerSource.tone);
    expect(layer.beatHz, isNotNull, reason: 'onayla gelen vurunun katmana yazılması gerekir');
    expect(layer.beatHz!, greaterThan(0));
  });

  testWidgets('kaldırma: satır state\'ten düşer', (tester) async {
    final c = buildController();
    await c.addToneLayer(220);
    await tester.pumpWidget(wrap(c));
    await tester.pump();

    expect(find.text('Pure tone · 220 Hz'), findsOneWidget);

    await tester.tap(find.byKey(const Key('remove-tone')));
    await tester.pumpAndSettle();

    expect(c.state.layers.any((l) => l.id == 'tone'), isFalse);
    expect(find.text('Pure tone · 220 Hz'), findsNothing);
  });

  testWidgets('tavan doluysa sheet AÇILMAZ, uyarı söylenir', (tester) async {
    final c = buildController();
    for (var i = 0; i < MixerController.maxTotalLayers - 1; i++) {
      await c.addToneLayer(110);
    }
    expect(c.state.layers.length + c.state.assets.length,
        MixerController.maxTotalLayers);

    await tester.pumpWidget(wrap(c));
    await tester.pump();
    await tester.tap(find.byKey(const Key('mixer-add-tone')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('add-tone-title')), findsNothing,
        reason: 'dolu mikserde boşuna seçim yaptırmak kötü UX + yarış riski');
    expect(find.byKey(const Key('mixer-error')), findsOneWidget);
    expect(find.text('The mix is full — remove a layer to add another.'),
        findsOneWidget);
  });

  testWidgets('vazgeçmek hata değildir: sheet kapanır, hiçbir şey değişmez',
      (tester) async {
    final c = buildController();
    await tester.pumpWidget(wrap(c));
    await tester.pump();
    await openToneSheet(tester);

    // Sheet dışına dokun = vazgeç (barrierDismissible).
    await tester.tapAt(const Offset(20, 40));
    await tester.pumpAndSettle();

    expect(c.state.layers.any((l) => l.type == LayerSource.tone), isFalse);
    expect(find.byKey(const Key('mixer-error')), findsNothing);
  });
}
