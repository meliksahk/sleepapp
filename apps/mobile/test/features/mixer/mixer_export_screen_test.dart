import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:nocta/core/audio_engine/dsp/mix_render.dart';
import 'package:nocta/core/audio_engine/mix_player.dart';
import 'package:nocta/core/share/sharer.dart';
import 'package:nocta/features/mixer/mix_video_exporter.dart';
import 'package:nocta/features/mixer/mixer_controller.dart';
import 'package:nocta/features/mixer/presentation/mixer_screen.dart';
import 'package:nocta/l10n/app_localizations.dart';

/// Mikser ekranında **mix-to-video** (viral kanca #3, docs/04 §131).
///
/// **DÜRÜSTLÜK SINIRI:** burada gerçek bir mp4 üretilmez ve gerçek bir kare
/// çizilmez — kodlayıcı Android çerçeve API'si, `toImage` ise headless asılıyor
/// (#140). Kanıtlanan şey: butonun doğru anda görünmesi, ilerlemenin gösterilmesi,
/// videonun PAYLAŞIMA gitmesi ve hata metninin doğru olması.
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
  Future<void> play() async => playing = true;
  @override
  Future<void> pause() async => playing = false;
  @override
  Future<void> dispose() async {}
  @override
  noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _RecordingSharer implements Sharer {
  final List<ShareContent> shared = [];
  @override
  Future<void> share(ShareContent content) async => shared.add(content);
}

void main() {
  const spec = MixSpec([MixLayer(id: 'pink', type: NoiseType.pink, gain: 0.3)]);

  late FakeMixVideoEncoder encoder;
  late _RecordingSharer sharer;

  /// Doluysa kare render'ı burada BEKLER — test export'un ortasını yakalayabilsin.
  /// Sahte export aksi hâlde tek microtask turunda biter ve "sürerken" diye bir an
  /// olmaz.
  Completer<void>? frameGate;

  MixerController build() {
    encoder = FakeMixVideoEncoder();
    return MixerController(
      spec: spec,
      player: MixPlayer(
        loopSeconds: 1,
        sampleRate: 8000,
        playerFactory: _FakePlayer.new,
      ),
      exporter: MixVideoExporter(
        encoder: encoder,
        size: const Size(16, 32),
        fps: 1,
        sampleRate: 8000,
        // Gerçek renderer headless asılır (bkz. MixVideoExporter.renderFrame).
        renderFrame: (w, size) async {
          if (frameGate != null) await frameGate!.future;
          return Uint8List((size.width * size.height * 4).toInt());
        },
      ),
    );
  }

  Future<void> pump(WidgetTester t, {bool canExport = true}) async {
    sharer = _RecordingSharer();
    frameGate = null;
    await t.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        home: MixerScreen(
          controller: build(),
          sharer: sharer,
          canExportVideo: canExport,
        ),
      ),
    );
  }

  testWidgets('ÇEKİRDEK: export edilen video PAYLAŞIMA gider', (t) async {
    await pump(t);
    await t.tap(find.byKey(const Key('mixer-export-video')));
    await t.pumpAndSettle();

    // Viral kanca sürtünmesizliğe dayanır: dosya üretilip ekranda bırakılırsa
    // kullanıcı onu kendi bulup paylaşmak zorunda kalır — döngü kapanmaz.
    expect(sharer.shared, hasLength(1));
    expect(sharer.shared.single.file, isNotNull);
    expect(sharer.shared.single.file!.mimeType, 'video/mp4');
    // Video DİSKTEN paylaşılır (15 MB'ı RAM'e okumak için sebep yok).
    expect(sharer.shared.single.file!.path, isNotNull);
    expect(sharer.shared.single.file!.bytes, isNull);
  });

  testWidgets('ÇEKİRDEK: iOS\'ta buton YOK (native kodlayıcı yok — D-14)', (t) async {
    await pump(t, canExport: false);
    // Buton görünse basınca MissingPluginException atardı.
    expect(find.byKey(const Key('mixer-export-video')), findsNothing);
  });

  testWidgets('export patlarsa VİDEO hatası gösterilir, ses hatası değil', (t) async {
    await pump(t);
    encoder.failOnFinish = StateError('codec öldü');

    await t.tap(find.byKey(const Key('mixer-export-video')));
    await t.pumpAndSettle();

    // "Sound could not start." demek kullanıcıyı çalan sesi kurcalamaya yollardı.
    expect(find.text('Video could not be created.'), findsOneWidget);
    expect(find.text('Sound could not start.'), findsNothing);
    expect(sharer.shared, isEmpty); // patlayan export paylaşılmaz
  });

  testWidgets('export sürerken buton KİLİTLİ ve ilerleme görünür', (t) async {
    await pump(t);
    frameGate = Completer<void>(); // ilk karede dur
    await t.tap(find.byKey(const Key('mixer-export-video')));
    // settle YOK: export'un ortasını yakalamak istiyoruz.
    await t.pump();

    expect(find.byKey(const Key('mixer-export-progress')), findsOneWidget);
    final button =
        t.widget<OutlinedButton>(find.byKey(const Key('mixer-export-video')));
    // Çift basış ikinci native oturum açardı.
    expect(button.onPressed, isNull);

    frameGate!.complete();
    await t.pumpAndSettle();
    // Bitince ilerleme çubuğu kalkmalı (yoksa ekran sonsuza dek "yapılıyor" der).
    expect(find.byKey(const Key('mixer-export-progress')), findsNothing);
  });

  testWidgets('ÇEKİRDEK: DUYULAN mix export edilir, ilk kazançlar değil', (t) async {
    await pump(t);
    // Kullanıcı slider'ı kısıyor.
    await t.drag(find.byKey(const Key('gain-pink')), const Offset(-500, 0));
    await t.pumpAndSettle();

    await t.tap(find.byKey(const Key('mixer-export-video')));
    await t.pumpAndSettle();

    // Export edilen ses, kullanıcının duyduğu sessiz mix olmalı. Kazanç 0'a
    // düştüyse üretilen PCM de sessizdir; ilk spec (0.3) kullanılsaydı dolu olurdu.
    final pcm = encoder.pcm!;
    expect(pcm, isNotEmpty);
    expect(pcm.every((b) => b == 0), isTrue,
        reason: 'kısılan slider export edilen sese yansımalı');
  });
}
