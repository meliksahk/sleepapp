import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nocta/core/audio_engine/dsp/mix_render.dart';
import 'package:nocta/core/design_system/design_system.dart';
import 'package:nocta/core/media/mix_video_channel.dart';
import 'package:nocta/features/mixer/mix_video_exporter.dart';
import 'package:nocta/features/mixer/presentation/mix_video_frame.dart';

/// Mix-to-video — **viral kanca #3** (docs/04 §131).
///
/// **DÜRÜSTLÜK SINIRI:** burada hiçbir test gerçek bir mp4 üretmez. `MediaCodec`
/// Android çerçeve API'si; host VM'de yok. Bu testler Dart tarafını (orkestrasyon,
/// kanal sözleşmesi, dalga formu) kilitler — **kodlayıcının çalıştığını kanıtlamaz**.
/// O kanıt yalnızca emülatör/cihazda üretilmiş, açılabilen bir mp4'tür.
void main() {
  // Kanal testleri binding ister (mock messenger).
  TestWidgetsFlutterBinding.ensureInitialized();

  const gradient = NoctaArchetypeGradient.overthinker;
  const spec = MixSpec([MixLayer(id: 'a', type: LayerSource.pink, gain: 0.5)]);

  /// Gerçek renderer yerine: doğru boyutta ham RGBA döner, çizmez.
  /// Neden: `toImage` headless ASILI KALIYOR (#140) — bkz. `MixVideoExporter.renderFrame`.
  Future<Uint8List> fakeRenderFrame(Widget w, Size size) async =>
      Uint8List((size.width * size.height * 4).toInt());

  MixVideoExporter exporter(
    FakeMixVideoEncoder fake, {
    Size size = const Size(64, 128),
    int fps = 2,
    int sampleRate = 48000,
  }) =>
      MixVideoExporter(
        encoder: fake,
        size: size,
        fps: fps,
        sampleRate: sampleRate,
        renderFrame: fakeRenderFrame,
      );

  group('export orkestrasyonu', () {
    test('ÇEKİRDEK: kare sayısı = saniye × fps', () async {
      final fake = FakeMixVideoEncoder();
      await exporter(fake, fps: 10)
          .export(spec: spec, title: 'Rain', gradient: gradient, seconds: 2);

      expect(fake.frames.length, 20);
    });

    test('ÇEKİRDEK: kare baytı = width × height × 4 (RGBA8888)', () async {
      final fake = FakeMixVideoEncoder();
      await exporter(fake, fps: 2)
          .export(spec: spec, title: 'Rain', gradient: gradient, seconds: 1);

      // Kotlin tarafı bu boyutu `require` ediyor; uyuşmazsa cihazda patlar.
      for (final f in fake.frames) {
        expect(f.length, 64 * 128 * 4);
      }
    });

    test('ÇEKİRDEK: PCM baytı = örnek × 2 (16-bit mono)', () async {
      final fake = FakeMixVideoEncoder();
      await exporter(fake, sampleRate: 8000).export(spec: spec, title: 'Rain', gradient: gradient, seconds: 3);

      // AAC kodlayıcısı PTS'i bayt sayısından hesaplıyor (bayt/2/sampleRate).
      // Bu sayı yanlışsa ses videodan kayar.
      expect(fake.pcm!.length, 8000 * 3 * 2);
    });

    test('çağrı SIRASI: start → kareler → finish', () async {
      final fake = FakeMixVideoEncoder();
      await exporter(fake, fps: 2)
          .export(spec: spec, title: 'Rain', gradient: gradient, seconds: 1);

      expect(fake.calls.first, 'start(64,128,2,48000)');
      expect(fake.calls.last, 'finish(rain)');
      expect(fake.cancelled, isFalse);
    });

    test('ilerleme 0..1 arasında ve MONOTON artar', () async {
      final fake = FakeMixVideoEncoder();
      final seen = <double>[];
      await exporter(fake, fps: 4)
          .export(
        spec: spec,
        title: 'Rain',
        gradient: gradient,
        seconds: 2,
        onProgress: seen.add,
      );

      expect(seen.first, greaterThan(0));
      expect(seen.last, 1.0);
      for (var i = 1; i < seen.length; i++) {
        expect(seen[i], greaterThanOrEqualTo(seen[i - 1]));
      }
    });
  });

  group('hata yolu', () {
    test('ÇEKİRDEK: kodlama patlarsa native oturum KAPATILIR', () async {
      final fake = FakeMixVideoEncoder()..failOnFinish = StateError('codec öldü');

      await expectLater(
        exporter(fake, fps: 2).export(
          spec: spec,
          title: 'Rain',
          gradient: gradient,
          seconds: 1,
        ),
        throwsStateError, // hata YUTULMAZ
      );
      // Kapatılmazsa codec cihazda kilitli kalır ve sonraki export'lar da patlar.
      expect(fake.cancelled, isTrue);
    });
  });

  group('dosya adı', () {
    test('başlık slug olur', () async {
      final fake = FakeMixVideoEncoder();
      await exporter(fake, fps: 2)
          .export(spec: spec, title: 'Deep  Ocean!!', gradient: gradient, seconds: 1);
      expect(fake.calls.last, 'finish(deep-ocean)');
    });

    test('latin dışı başlık boş dosya adı ÜRETMEZ', () async {
      final fake = FakeMixVideoEncoder();
      await exporter(fake, fps: 2)
          .export(spec: spec, title: 'Gece Sesi ЖЖ', gradient: gradient, seconds: 1);
      // "nocta--.mp4" gibi bir isim üretilmemeli.
      expect(fake.calls.last, 'finish(gece-sesi)');
    });
  });

  group('dalga formu', () {
    test('sütun sayısı istenen kadar', () {
      final peaks = waveformPeaks(Float32List.fromList([for (var i = 0; i < 100; i++) 0.5]),
          columns: 8);
      expect(peaks.length, 8);
    });

    test('ÇEKİRDEK: normalize — en yüksek sütun 1.0 olur', () {
      // Uyku mix'leri kısık (-20 dBFS); normalize olmasa dalga formu düz çizgi olurdu.
      final peaks = waveformPeaks(
        Float32List.fromList([0.01, 0.02, 0.05, 0.03]),
        columns: 4,
      );
      expect(peaks.reduce((a, b) => a > b ? a : b), 1.0);
    });

    test('RMS değil TEPE — kısa bir zirve sütunu yükseltir', () {
      // Sütun 0'da tek bir zirve var; RMS bunu ortalayıp söndürürdü.
      final peaks = waveformPeaks(
        Float32List.fromList([1.0, 0.0, 0.0, 0.0, 0.1, 0.1, 0.1, 0.1]),
        columns: 2,
      );
      expect(peaks[0], 1.0);
      expect(peaks[1], closeTo(0.1, 1e-6));
    });

    test('sessiz mix 0/0 bölmesi yapmaz', () {
      final peaks = waveformPeaks(Float32List(64), columns: 4);
      expect(peaks, everyElement(0.0));
    });

    test('boş sinyal boş liste', () {
      expect(waveformPeaks(Float32List(0)), isEmpty);
    });
  });

  group('kanal sözleşmesi — Kotlin tarafıyla eşleşmeli', () {
    late List<MethodCall> calls;

    setUp(() {
      calls = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(PlatformMixVideoEncoder.channel, (call) async {
        calls.add(call);
        return call.method == 'finish' ? '/data/x.mp4' : null;
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(PlatformMixVideoEncoder.channel, null);
    });

    test('ÇEKİRDEK: kanal adı ve argüman anahtarları MainActivity.kt ile aynı', () async {
      // Bu isimler Kotlin'de `call.argument<...>("...")!!` ile okunuyor — biri
      // değişirse cihazda NPE, testte sessizlik olurdu. Sözleşme burada kilitli.
      const e = PlatformMixVideoEncoder();
      await e.start(width: 1080, height: 1920, fps: 24, sampleRate: 48000);
      await e.pushFrame(Uint8List(4));
      await e.finish(pcm: Uint8List(2), name: 'rain');
      await e.cancel();

      expect(PlatformMixVideoEncoder.channel.name, 'nocta/mix_video');
      expect(calls.map((c) => c.method).toList(),
          ['start', 'pushFrame', 'finish', 'cancel']);
      expect(
        (calls[0].arguments as Map).keys.toSet(),
        {'width', 'height', 'fps', 'sampleRate'},
      );
      expect((calls[1].arguments as Map).keys.toSet(), {'rgba'});
      expect((calls[2].arguments as Map).keys.toSet(), {'pcm', 'name'});
    });

    test('finish yol dönmezse SESSİZ kalmaz', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
              PlatformMixVideoEncoder.channel, (call) async => null);

      await expectLater(
        const PlatformMixVideoEncoder().finish(pcm: Uint8List(2), name: 'x'),
        throwsStateError,
      );
    });
  });
}
