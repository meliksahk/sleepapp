import 'package:flutter/services.dart';

/// Mix-to-video kodlayıcısının **portu** (viral kanca #3).
///
/// Arayüz olarak durur ki: (a) kodlayıcı olmayan platformlarda (iOS — bkz. D-13/D-14)
/// derleme kırılmasın, (b) testlerde sahte ile değiştirilebilsin.
abstract class MixVideoEncoderPort {
  /// Yeni bir kodlama oturumu açar.
  Future<void> start({
    required int width,
    required int height,
    required int fps,
    required int sampleRate,
  });

  /// Tek kare: [rgba] = width*height*4 baytlık RGBA8888.
  Future<void> pushFrame(Uint8List rgba);

  /// Sesi ekler, mp4'ü yazar ve **dosya yolunu** döndürür.
  /// [pcm]: 16-bit LE mono.
  Future<String> finish({required Uint8List pcm, required String name});

  /// Yarıda bırakılan oturumun native kaynaklarını serbest bırakır.
  Future<void> cancel();
}

/// Android `MediaCodec`/`MediaMuxer` uygulaması.
///
/// Kanal ve yöntem adları `MainActivity.kt` ile eşleşmeli — sözleşme testi
/// `mix_video_channel_test.dart` bunu kilitler.
///
/// **iOS'ta ÇALIŞMAZ:** `AVAssetWriter` karşılığı yazılmadı; Mac olmadan yazılamaz da
/// (DECISIONS D-13/D-14). iOS'ta çağrı `MissingPluginException` atar; çağıran taraf
/// kancayı Android'e sınırlamak zorunda. Bu, saklanan değil bilinen bir sınır.
class PlatformMixVideoEncoder implements MixVideoEncoderPort {
  const PlatformMixVideoEncoder();

  static const MethodChannel channel = MethodChannel('nocta/mix_video');

  @override
  Future<void> start({
    required int width,
    required int height,
    required int fps,
    required int sampleRate,
  }) async {
    await channel.invokeMethod<void>('start', <String, Object>{
      'width': width,
      'height': height,
      'fps': fps,
      'sampleRate': sampleRate,
    });
  }

  @override
  Future<void> pushFrame(Uint8List rgba) async {
    await channel.invokeMethod<void>('pushFrame', <String, Object>{'rgba': rgba});
  }

  @override
  Future<String> finish({required Uint8List pcm, required String name}) async {
    final path = await channel.invokeMethod<String>('finish', <String, Object>{
      'pcm': pcm,
      'name': name,
    });
    if (path == null) {
      throw StateError('Video kodlandı ama dosya yolu dönmedi.');
    }
    return path;
  }

  @override
  Future<void> cancel() async {
    await channel.invokeMethod<void>('cancel');
  }
}
