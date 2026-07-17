import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/audio_engine/dsp/mix_render.dart';
import '../../core/audio_engine/dsp/wav_encoder.dart';
import '../../core/media/card_renderer.dart';
import '../../core/media/mix_video_channel.dart';
import 'presentation/mix_video_frame.dart';

/// Mix-to-video export'u — **viral kanca #3** (docs/04 §131).
///
/// Ses ve kareler için TEK kaynak: `renderMix` (offline üretim, #95'ten beri var) ve
/// `renderWidgetToRgba` (kartlarla aynı hat). Bu sınıf yalnızca ikisini bir kodlayıcıya
/// bağlar — DSP veya çizim mantığı burada YOK.
typedef FrameRenderer = Future<Uint8List> Function(Widget widget, Size size);

Future<Uint8List> _defaultFrameRenderer(Widget widget, Size size) =>
    renderWidgetToRgba(widget, size: size);

class MixVideoExporter {
  const MixVideoExporter({
    required this.encoder,
    this.size = const Size(1080, 1920),
    this.fps = 24,
    this.sampleRate = 48000,
    this.renderFrame = _defaultFrameRenderer,
  });

  final MixVideoEncoderPort encoder;

  /// Widget → ham RGBA. **Enjekte edilebilir çünkü test edilemez:** altında
  /// `RenderRepaintBoundary.toImage` var ve o, headless test ortamında (GPU yok)
  /// ASILI KALIYOR — #140'ta ölçüldü. Gerçek çizimi cihaz/golden kanıtlar; buradaki
  /// testler bu sınıfın işini, yani ORKESTRASYONU kanıtlar. Sahte bir renderer
  /// koymak testi zayıflatmıyor: zaten çizimi test etmiyorlardı, sadece asılıyorlardı.
  final FrameRenderer renderFrame;

  /// 9:16 (docs/04 §131). Instagram/TikTok'un önerdiği boyut.
  final Size size;

  /// 24: gradyan + yavaş playhead için yeterli. 30/60 kare sayısını (ve dolayısıyla
  /// export süresini) doğrudan artırır, görünürde hiçbir şey kazandırmaz.
  final int fps;

  final int sampleRate;

  /// [spec]'i [seconds] saniyelik mp4'e çevirir ve **dosya yolunu** döndürür.
  ///
  /// [onProgress] 0..1 — export saniyeler sürer, kullanıcı ne olduğunu görmeli.
  ///
  /// Hata durumunda **ATAR**; native oturum her hâlükârda kapatılır (yoksa yarıda
  /// kalan bir export codec'i cihazda kilitli bırakırdı — sonraki denemeler de
  /// başarısız olurdu).
  Future<String> export({
    required MixSpec spec,
    required String title,
    required LinearGradient gradient,
    required int seconds,
    int seed = 0,
    void Function(double progress)? onProgress,
  }) async {
    assert(seconds > 0);

    final samples = renderMix(
      spec,
      seconds: seconds,
      sampleRate: sampleRate,
      seed: seed,
    );
    // Dalga formu BİR KEZ hesaplanır: her karede yeniden çıkarmak aynı sonucu
    // 300+ kez üretmek olurdu.
    final peaks = waveformPeaks(samples);
    final frameCount = seconds * fps;

    await encoder.start(
      width: size.width.toInt(),
      height: size.height.toInt(),
      fps: fps,
      sampleRate: sampleRate,
    );

    try {
      for (var i = 0; i < frameCount; i++) {
        final rgba = await renderFrame(
          MixVideoFrame(
            title: title,
            peaks: peaks,
            // Son kare playhead'i sona getirsin: i/(n-1), i/n değil. i/n ile
            // dalga formunun son sütunu asla "çalınmış" görünmezdi.
            progress: frameCount == 1 ? 1 : i / (frameCount - 1),
            gradient: gradient,
            size: size,
          ),
          size,
        );
        await encoder.pushFrame(rgba);
        // Kareler karelerin %90'ı: ses kodlaması ve mux kalan kısa kuyruk.
        onProgress?.call(0.9 * (i + 1) / frameCount);
      }

      final path = await encoder.finish(
        pcm: encodePcm16(samples),
        name: _fileStamp(title),
      );
      onProgress?.call(1);
      return path;
    } catch (_) {
      // Native oturumu kapat, sonra hatayı yukarı bırak: yutmak, kullanıcıya
      // hiçbir şey olmayan bir buton bırakırdı (CLAUDE.md §4).
      await encoder.cancel();
      rethrow;
    }
  }

  /// Dosya adı parçası: kullanıcı adını tanısın ama dosya sistemi bozulmasın.
  static String _fileStamp(String title) {
    final slug = title
        .toLowerCase()
        .replaceAll(RegExp('[^a-z0-9]+'), '-')
        .replaceAll(RegExp('^-+|-+\$'), '');
    // Boş slug (ör. yalnızca Türkçe/CJK karakterli başlık) dosya adını "nocta--.mp4"
    // yapardı; yedeğe düş.
    return slug.isEmpty ? 'mix' : slug;
  }
}

/// Testlerde ve iOS'ta (D-13/D-14: `AVAssetWriter` yok) kodlayıcı yerine geçer.
///
/// Gerçek bir video ÜRETMEZ — çağrı sırasını ve verilen baytları kaydeder.
class FakeMixVideoEncoder implements MixVideoEncoderPort {
  final List<String> calls = [];
  final List<Uint8List> frames = [];
  Uint8List? pcm;
  bool started = false;
  bool cancelled = false;

  /// Ayarlanırsa [finish] yerine bu hata atılır (hata yolunu test etmek için).
  Object? failOnFinish;

  @override
  Future<void> start({
    required int width,
    required int height,
    required int fps,
    required int sampleRate,
  }) async {
    calls.add('start($width,$height,$fps,$sampleRate)');
    started = true;
  }

  @override
  Future<void> pushFrame(Uint8List rgba) async {
    calls.add('pushFrame(${rgba.length})');
    frames.add(rgba);
  }

  @override
  Future<String> finish({required Uint8List pcm, required String name}) async {
    calls.add('finish($name)');
    if (failOnFinish != null) throw failOnFinish!;
    this.pcm = pcm;
    return '/fake/$name.mp4';
  }

  @override
  Future<void> cancel() async {
    calls.add('cancel');
    cancelled = true;
  }
}
