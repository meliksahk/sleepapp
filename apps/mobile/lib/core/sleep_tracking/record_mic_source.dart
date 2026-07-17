import 'dart:typed_data';

import 'package:record/record.dart';

import 'mic_source.dart';

/// [MicSource]'un gerçek mikrofon uygulaması (`record`, BSD-3-Clause).
///
/// **PCM AKIŞI, DOSYA DEĞİL:** `record` dosyaya da kaydedebiliyor; kullanmıyoruz.
/// Gece boyunca diske ham ses yazmak CLAUDE.md §6'yı çiğnerdi ("mikrofon verisi ASLA
/// ham yüklenmez" kuralının ruhu: ham ses hiç KALMAMALI) ve ayrıca saatlerce süren
/// bir kayıt gigabaytlarca yer kaplardı. Akıştaki her çerçeve dB'ye indirgenip düşer
/// (bkz. `SleepRecorder`).
class RecordMicSource implements MicSource {
  RecordMicSource({AudioRecorder? recorder})
      : _recorder = recorder ?? AudioRecorder();

  final AudioRecorder _recorder;

  @override
  Future<bool> hasPermission() => _recorder.hasPermission();

  @override
  Stream<Float32List> start({required int sampleRate}) async* {
    final stream = await _recorder.startStream(
      RecordConfig(
        // 16-bit PCM: `record`ın her platformda desteklediği ham biçim.
        encoder: AudioEncoder.pcm16bits,
        sampleRate: sampleRate,
        numChannels: 1,
        // Otomatik kazanç kontrolü KAPALI: AGC sessiz odada tabanı yükseltir ve
        // dedektörün uyarlanır taban hesabını bozar — sessizlik "gürültü" görünür.
        autoGain: false,
        // Gürültü bastırma KAPALI: bastırılan şey tam olarak ölçmek istediğimiz şey.
        noiseSuppress: false,
        echoCancel: false,
      ),
    );

    await for (final chunk in stream) {
      yield _toFloat32(chunk);
    }
  }

  @override
  Future<void> stop() async {
    await _recorder.stop();
    await _recorder.dispose();
  }

  /// 16-bit little-endian PCM baytları → [-1, 1] float örnekler.
  ///
  /// **32768.0'a bölünür** (32767'ye değil): int16'nın en negatif değeri -32768'dir
  /// ve 32767'ye bölmek onu -1.000030'a taşırdı — `frameDbfs` için zararsız ama
  /// [-1, 1] sözleşmesini sessizce ihlal ederdi.
  static Float32List _toFloat32(Uint8List bytes) {
    final samples = bytes.length ~/ 2;
    final out = Float32List(samples);
    final view = ByteData.sublistView(bytes);
    for (var i = 0; i < samples; i++) {
      out[i] = view.getInt16(i * 2, Endian.little) / 32768.0;
    }
    return out;
  }
}
