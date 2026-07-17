import 'package:audio_session/audio_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:nocta/core/sleep_tracking/alarm_sound.dart';

/// Alarm sesi adaptörü.
///
/// Buradaki testler sesin DUYULDUĞUNU kanıtlamaz (o cihaz işi, `dumpsys audio` ile
/// yapıldı). Kanıtladıkları: alarmın **doğru ses kanalından** çalması ve döngülenmesi.
class _FakePlayer implements AudioPlayer {
  AndroidAudioAttributes? attrs;
  LoopMode? loop;
  double? setVolumeTo;
  int playCalls = 0;
  int stopCalls = 0;
  AudioSource? source;

  @override
  bool playing = false;

  @override
  Future<void> setAndroidAudioAttributes(AndroidAudioAttributes a) async =>
      attrs = a;

  @override
  Future<Duration?> setAudioSource(
    AudioSource s, {
    bool preload = true,
    int? initialIndex,
    Duration? initialPosition,
  }) async {
    source = s;
    return Duration.zero;
  }

  @override
  Future<void> setLoopMode(LoopMode m) async => loop = m;
  @override
  Future<void> setVolume(double v) async => setVolumeTo = v;
  @override
  Future<void> play() async {
    playCalls++;
    playing = true;
  }

  @override
  Future<void> stop() async {
    stopCalls++;
    playing = false;
  }

  @override
  Future<void> dispose() async {}
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  late _FakePlayer player;

  SunriseAlarmSound build() {
    player = _FakePlayer();
    return SunriseAlarmSound(
      playerFactory: () => player,
      sampleRate: 8000,
      loopSeconds: 2,
    );
  }

  test('ÇEKİRDEK: ALARM kanalından çalar — medya kanalından DEĞİL', () async {
    await build().play();

    // Bu, emülatörde `dumpsys audio` ile yakalanan GERÇEK bir hataydı:
    //   usage=USAGE_MEDIA content=CONTENT_TYPE_MUSIC
    // İnsanlar geceleri medyayı kısar → alarm tam da ona ihtiyacı olan kullanıcıda
    // sessiz kalırdı. USAGE_ALARM, Rahatsız Etmeyin/sessiz modda bile duyulur.
    expect(player.attrs?.usage, AndroidAudioUsage.alarm);
    expect(player.attrs?.contentType, AndroidAudioContentType.sonification);
  });

  test('döngüler — bir kez çalıp susmaz', () async {
    await build().play();
    // Tek seferlik bir çalma, kullanıcı uyanmadan biterdi.
    expect(player.loop, LoopMode.one);
    expect(player.playCalls, 1);
  });

  test('tam sesle çalar', () async {
    await build().play();
    expect(player.setVolumeTo, 1);
  });

  test('sustur → player durur', () async {
    final s = build();
    await s.play();
    await s.stop();
    expect(player.stopCalls, 1);
  });

  test('çalmadan sustur → patlamaz', () async {
    // Kullanıcı alarm çalmadan geceyi bitirebilir; stop() yine çağrılır.
    await expectLater(build().stop(), completes);
  });
}
