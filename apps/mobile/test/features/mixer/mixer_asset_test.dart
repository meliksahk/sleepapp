import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:nocta/core/audio_engine/dsp/mix_render.dart';
import 'package:nocta/core/audio_engine/mix_player.dart';
import 'package:nocta/features/mixer/mixer_controller.dart';
import 'package:nocta/features/mixer/presentation/mixer_screen.dart';
import 'package:nocta/features/mixer/soundscape_mix.dart';
import 'package:nocta/l10n/app_localizations.dart';

/// Asset katmanı MİKSERDE — sürgüsü, kırpma sınırı ve dürüstlük dipnotu.
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
  }) async =>
      Duration.zero;

  @override
  Future<void> setVolume(double volume) async {
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
  const asset = AssetLayer(
    id: 'asset-1',
    title: 'Pad + Fire (demo)',
    url: 'https://minio.test/demo.wav',
    gain: 0.4,
  );

  group('limitTotalGain — asset katmanlarını KAPSAR', () {
    test('yalnızca asset katmanları toplamı aşarsa da ölçeklenir', () {
      // Sentez toplamı 0 — eski (yalnızca `layers` sayan) sürüm burada HİÇBİR
      // ŞEY yapmazdı ve toplam 2.4 ile OS mikserinde kırpardı.
      const spec = MixSpec(
        <MixLayer>[],
        assets: <AssetLayer>[
          AssetLayer(id: 'a', title: 'A', url: 'u', gain: 1.2),
          AssetLayer(id: 'b', title: 'B', url: 'u', gain: 1.2),
        ],
      );
      final limited = limitTotalGain(spec);
      final total = limited.assets.fold<double>(0, (s, a) => s + a.gain);
      expect(total, closeTo(maxPlaybackTotalGain, 1e-9));
      // Oran korunur: ikisi eşitti, eşit kalmalı.
      expect(limited.assets[0].gain, closeTo(limited.assets[1].gain, 1e-9));
    });

    test('sentez + asset KARIŞIK toplam üzerinden ölçeklenir', () {
      const spec = MixSpec(
        <MixLayer>[MixLayer(id: 'brown', type: LayerSource.brown, gain: 0.6)],
        assets: <AssetLayer>[AssetLayer(id: 'a', title: 'A', url: 'u', gain: 0.9)],
      );
      final limited = limitTotalGain(spec);
      final total = limited.layers.fold<double>(0, (s, l) => s + l.gain) +
          limited.assets.fold<double>(0, (s, a) => s + a.gain);
      expect(total, closeTo(maxPlaybackTotalGain, 1e-9));
      // Aynı `k` her iki listeye uygulandı → oran (0.6 : 0.9) korunmalı.
      expect(
        limited.layers.single.gain / limited.assets.single.gain,
        closeTo(0.6 / 0.9, 1e-9),
      );
    });

    test('toplam sınırın altındaysa spec DEĞİŞMEZ', () {
      const spec = MixSpec(
        <MixLayer>[MixLayer(id: 'brown', type: LayerSource.brown, gain: 0.2)],
        assets: <AssetLayer>[AssetLayer(id: 'a', title: 'A', url: 'u', gain: 0.3)],
      );
      final limited = limitTotalGain(spec);
      expect(limited.layers.single.gain, 0.2);
      expect(limited.assets.single.gain, 0.3);
    });
  });

  group('MixerController', () {
    MixerController build(MixSpec spec) => MixerController(
          spec: spec,
          player: MixPlayer(
            loopSeconds: 1,
            sampleRate: 8000,
            loopRenderer: (r) async => renderLoopSync(r),
            playerFactory: _FakePlayer.new,
          ),
        );

    test('asset katmanları başlangıç kazanç haritasına girer', () {
      final c = build(const MixSpec(
        <MixLayer>[MixLayer(id: 'brown', type: LayerSource.brown, gain: 0.3)],
        assets: <AssetLayer>[asset],
      ));
      expect(c.state.assets, hasLength(1));
      expect(c.state.gains, {'brown': 0.3, 'asset-1': 0.4});
    });

    test('setGain asset katmanında da durumu günceller', () async {
      final c = build(const MixSpec(<MixLayer>[], assets: <AssetLayer>[asset]));
      await c.prepare();
      await c.setGain('asset-1', 0.75);
      expect(c.state.gains['asset-1'], 0.75);
    });

    test('currentSpec asset katmanlarını GÜNCEL kazançla taşır', () async {
      final c = build(const MixSpec(<MixLayer>[], assets: <AssetLayer>[asset]));
      await c.prepare();
      await c.setGain('asset-1', 0.75);
      expect(c.currentSpec().assets.single.gain, 0.75);
    });
  });

  group('MixerScreen', () {
    Widget wrap(MixerController c) => ProviderScope(
          child: MaterialApp(
            localizationsDelegates: AppL10n.localizationsDelegates,
            supportedLocales: AppL10n.supportedLocales,
            home: MixerScreen(controller: c, canExportVideo: false),
          ),
        );

    MixerController build(MixSpec spec) => MixerController(
          spec: spec,
          player: MixPlayer(
            loopSeconds: 1,
            sampleRate: 8000,
            loopRenderer: (r) async => renderLoopSync(r),
            playerFactory: _FakePlayer.new,
          ),
        );

    testWidgets('asset katmanı sürgü olarak GÖRÜNÜR ve başlığı yazar',
        (tester) async {
      final c = build(const MixSpec(
        <MixLayer>[MixLayer(id: 'brown', type: LayerSource.brown, gain: 0.3)],
        assets: <AssetLayer>[asset],
      ));
      await tester.pumpWidget(wrap(c));
      await tester.pump();

      expect(find.byKey(const Key('gain-asset-1')), findsOneWidget);
      expect(find.text('Pad + Fire (demo)'), findsOneWidget);
      // Sentez katmanı da yerinde — asset onu ittirmedi.
      expect(find.byKey(const Key('gain-brown')), findsOneWidget);
    });

    testWidgets('asset sürgüsü ÇALIŞIR (kazancı değiştirir)', (tester) async {
      final c = build(const MixSpec(<MixLayer>[], assets: <AssetLayer>[asset]));
      await tester.pumpWidget(wrap(c));
      await tester.pump();

      final slider = find.byKey(const Key('gain-asset-1'));
      await tester.drag(slider, const Offset(200, 0));
      await tester.pump();

      expect(c.state.gains['asset-1'], greaterThan(0.4));
    });

    testWidgets('DÜRÜSTLÜK: asset varsa döngü tıkı dipnotu gösterilir',
        (tester) async {
      final c = build(const MixSpec(<MixLayer>[], assets: <AssetLayer>[asset]));
      await tester.pumpWidget(wrap(c));
      await tester.pump();
      expect(find.byKey(const Key('mixer-asset-loop-notice')), findsOneWidget);
    });

    testWidgets('asset YOKSA dipnot da yok (gereksiz gürültü üretme)',
        (tester) async {
      final c = build(const MixSpec(
        <MixLayer>[MixLayer(id: 'brown', type: LayerSource.brown, gain: 0.3)],
      ));
      await tester.pumpWidget(wrap(c));
      await tester.pump();
      expect(find.byKey(const Key('mixer-asset-loop-notice')), findsNothing);
    });
  });
}
