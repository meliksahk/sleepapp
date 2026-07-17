import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';

import '../audio_engine/dsp/sunrise_tone.dart';
import '../audio_engine/dsp/wav_encoder.dart';
import '../audio_engine/mix_player.dart';

/// Alarmı DUYULUR yapan port.
///
/// Soyutlama şart: alarmın çalıp çalmadığını cihazsız test edebilmek gerekiyor —
/// "alarm çaldı mı?" sorusu, bu projede yanlış cevaplanması en pahalı sorudur
/// (kullanıcı işe geç kalır).
abstract class AlarmSound {
  /// Alarmı çalar. Kullanıcı durdurana kadar sürer.
  Future<void> play();

  /// Susturur. Zaten susmuşsa sorun değil.
  Future<void> stop();

  Future<void> dispose();
}

/// `sunriseTone` → hoparlör (docs/04 §86).
///
/// **Neden `just_audio`, neden yeni bir paket değil:** mikserde (#138) zaten kanıtlanmış
/// yol bu; bellekten WAV besleniyor, geçici dosya yok. Alarm için ayrı bir ses paketi
/// eklemek, aynı işi yapan ikinci bir bağımlılık olurdu.
class SunriseAlarmSound implements AlarmSound {
  SunriseAlarmSound({
    AudioPlayer Function()? playerFactory,
    this.sampleRate = 48000,
    this.loopSeconds = 60,
  }) : _newPlayer = playerFactory ?? _newAlarmPlayer;

  /// **`androidApplyAudioAttributes: false` ŞART — cihazda öğrenildi.**
  ///
  /// Varsayılan `true` iken player, GLOBAL `AudioSession`ın yapılandırma akışına
  /// abone olur ve oradan gelen nitelikleri kendi üstüne yazar. Yani aşağıdaki
  /// `setAndroidAudioAttributes(usage: alarm)` çağrısı sessizce EZİLİYORDU:
  /// düzeltmeyi yazdım, testler yeşildi, `dumpsys audio` hâlâ `USAGE_MEDIA` diyordu.
  ///
  /// `false` ile player global oturumu dinlemeyi bırakır ve niteliği biz veririz.
  /// Global oturumu `alarm` yapmak YANLIŞ olurdu: mikserin uyku sesi MEDYA'dır ve
  /// öyle kalmalı — alarm kanalından çalan bir uyku sesi, kullanıcının alarm sesini
  /// gece boyu açık tutmasını gerektirirdi.
  static AudioPlayer _newAlarmPlayer() =>
      AudioPlayer(androidApplyAudioAttributes: false);

  final AudioPlayer Function() _newPlayer;
  final int sampleRate;

  /// Döngü uzunluğu. 60 sn: rampanın (30 sn) tamamı ve sonrası sığar; döngü
  /// başa sarınca ses tam seviyeden devam eder — rampa BAŞA DÖNMEZ, çünkü
  /// döndürseydik alarm her dakika kısılıp kullanıcıyı uyandırmayı bırakırdı.
  final int loopSeconds;

  AudioPlayer? _player;

  @override
  Future<void> play() async {
    final player = _player ??= _newPlayer();

    // **ALARM KANALI — emülatörde YAKALANAN GERÇEK HATA.**
    //
    // Varsayılan `USAGE_MEDIA`dır ve ilk sürüm öyle çıktı: `dumpsys audio` şunu
    // gösterdi → `usage=USAGE_MEDIA content=CONTENT_TYPE_MUSIC`. Yani alarm MEDYA
    // ses kanalından çalıyordu. İnsanlar geceleri medyayı kısar/susturur; alarm tam
    // da ona ihtiyacı olan kullanıcıda SESSİZ kalırdı — hem de testler yeşilken.
    //
    // `USAGE_ALARM` alarm kanalını kullanır ve Rahatsız Etmeyin/sessiz modda bile
    // duyulur. Bir alarmın tek işi bu.
    await player.setAndroidAudioAttributes(const AndroidAudioAttributes(
      contentType: AndroidAudioContentType.sonification,
      usage: AndroidAudioUsage.alarm,
    ));

    final pcm = sunriseTone(seconds: loopSeconds, sampleRate: sampleRate);
    await player.setAudioSource(
      BytesAudioSource(encodeWav(pcm, sampleRate: sampleRate)),
    );
    await player.setLoopMode(LoopMode.one);
    await player.setVolume(1);
    // `play()` beklenmez: döngüdeyiz, beklemek sonsuza kadar asılı kalmak olurdu
    // (MixPlayer'daki aynı gerekçe).
    unawaited(player.play());
  }

  @override
  Future<void> stop() async => _player?.stop();

  @override
  Future<void> dispose() async {
    await _player?.dispose();
    _player = null;
  }
}
