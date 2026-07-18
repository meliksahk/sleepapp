/// Açılış imzasını (aura) gerçekten duyulur kılan katman.
///
/// **Neden `compute()`:** imza ~2.3M `sin()` çağrısı. UI isolate'inde üretilirse
/// açılışta görünür donma olur — tam da "premium his" iddiasının çöktüğü yer.
/// Üretim ayrı isolate'te yapılır, UI akıcı kalır.
///
/// **Neden fade ile durdurma:** kullanıcı 3.6 sn dolmadan bir şeye dokunursa ses
/// ANINDA kesilmemeli; dalga formunun ortasında kesmek tık üretir (DSP'de özenle
/// kaçındığımız şeyi çalma yolunda geri getirirdi).
///
/// **Ne zaman ÇALMAZ:** ayar kapalıysa, ve çağıran yalnız COLD START'ta çağırmalıdır
/// (uyku oturumu, alarm, arka plandan sıcak dönüş → çalınmaz).
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import 'dsp/nocta_signature.dart';
import 'dsp/wav_encoder.dart';
import 'mix_player.dart' show BytesAudioSource;

/// `compute()` için üst-seviye fonksiyon (isolate'e kapanış gönderilemez).
Uint8List _renderSignatureWav(int seed) =>
    encodeWav(noctaSignature(seed: seed), sampleRate: signatureSampleRate);

class SignaturePlayer {
  SignaturePlayer({AudioPlayer Function()? playerFactory, this.seed = 1308})
      : _newPlayer = playerFactory ?? AudioPlayer.new;

  final AudioPlayer Function() _newPlayer;
  final int seed;

  AudioPlayer? _player;

  /// İmzayı bir kez çalar. Hata durumunda SESSİZCE geçilir: açılış sesi
  /// uygulamanın açılmasını asla engellememeli.
  Future<void> play() async {
    try {
      final bytes = await compute(_renderSignatureWav, seed);
      final player = _player ??= _newPlayer();
      await player.setAudioSource(BytesAudioSource(bytes));
      // Seviye buffer'a gömülü (RMS ≈ −20 dBFS); cihaz sesi zaten kullanıcıda.
      await player.setVolume(1.0);
      unawaited(player.play());
    } catch (e, st) {
      // SESSİZ YUTMA YOK. Bu catch bir tur boyunca "ses hiç çalmıyor" hatasını
      // gizledi ve teşhisi imkânsızlaştırdı. Açılışı hâlâ bloklamıyoruz, ama
      // artık sorunu GÖRÜYORUZ (CLAUDE.md §4: boş catch yasak).
      debugPrint('nocta.aura: imza sesi çalınamadı: $e\n$st');
    }
  }

  /// 250 ms kosinüs benzeri fade ile durdurur (ani kesme tık üretir).
  Future<void> stop() async {
    final player = _player;
    if (player == null) return;
    try {
      const steps = 10;
      for (var i = steps - 1; i >= 0; i--) {
        await player.setVolume(i / steps);
        await Future<void>.delayed(const Duration(milliseconds: 25));
      }
      await player.stop();
    } catch (_) {
      // yok say
    }
  }

  Future<void> dispose() async {
    await _player?.dispose();
    _player = null;
  }
}
