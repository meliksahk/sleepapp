import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:record/record.dart';

import '../domain/sound_recorder.dart';

/// [SoundRecorder]'ın gerçek uygulaması (`record` paketi, BSD-3-Clause).
///
/// **AAC-LC seçildi, ham PCM değil:** 5 dakikalık ham 48 kHz PCM ~28 MB eder ve
/// 150 MB'lık kütüphane tavanının beşte birini tek kayıtla yer. AAC aynı süreyi
/// ~5 MB'a indirir ve her iki platformda da donanım kodlayıcısı vardır (pil).
/// Kalite kaybı, ortam sesi için duyulmaz mertebede.
///
/// **Ses işleme KAPALI** (`autoGain`, `noiseSuppress`, `echoCancel`): ürünün
/// vaadi "gerçek yerlerin sesi". Gürültü bastırma tam olarak kaydetmek
/// istediğimiz şeyi bastırır; AGC ise sessiz bir odayı yapay olarak
/// yükselterek mekânın sessizliğini yok eder.
class RecordSoundRecorder implements SoundRecorder {
  RecordSoundRecorder({AudioRecorder? recorder})
      : _recorder = recorder ?? AudioRecorder();

  final AudioRecorder _recorder;

  @override
  Future<bool> hasPermission() => _recorder.hasPermission();

  /// `record` paketinde izin sorma ve isteme AYNI çağrıdır (sorar, yoksa ister).
  @override
  Future<bool> requestPermission() => _recorder.hasPermission();

  @override
  Future<void> start(String path) => _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          sampleRate: 44100,
          numChannels: 1,
          autoGain: false,
          noiseSuppress: false,
          echoCancel: false,
        ),
        path: path,
      );

  @override
  Future<String?> stop() => _recorder.stop();

  @override
  Future<void> cancel() async {
    final path = await _recorder.stop();
    if (path == null) return;
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } on FileSystemException catch (e) {
      // Yutulmaz (CLAUDE.md §4): yarım dosya diskte kalırsa `reconcile`
      // karantinaya alır — sessiz bir sızıntı değil, görünür bir artık.
      debugPrint('nocta.record: iptal edilen kayıt silinemedi: $e');
    }
  }

  @override
  Future<void> dispose() => _recorder.dispose();
}
