import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nocta/core/sleep_tracking/mic_source.dart';
import 'package:nocta/core/sleep_tracking/night_service.dart';
import 'package:nocta/core/sleep_tracking/sleep_recorder.dart';
import 'package:nocta/core/storage/key_value_store.dart';
import 'package:nocta/features/sleep/night_sound_player.dart';
import 'package:nocta/features/sleep/sleep_controller.dart';
import 'package:nocta/features/sleep/sleep_mode_controller.dart';

/// 4. özellik "tek tuş" — ritüel sesinin gece akışına bağlanması.
///
/// Mikrofon/servis sahteleri mevcut sleep_mode testlerinin desenidir; ses
/// portu da aynı şekilde enjekte edilir. Her dal ayrı kilitlenir:
/// opt-in, start-bağlantısı, stopAndSave susması, alarm çakışması, hata toleransı,
/// kalıcı tercih.
class _FakeMicSource implements MicSource {
  _FakeMicSource(this.permission);

  final bool permission;
  @override
  Future<bool> hasPermission() async => permission;

  @override
  Stream<Float32List> start({required int sampleRate}) =>
      const Stream<Float32List>.empty();

  @override
  Future<void> stop() async {}
}

class _FakeNightService implements NightService {
  @override
  Future<bool> get isRunning async => true;

  @override
  Future<bool> start({required String title, required String body}) async => true;

  @override
  Future<void> stop() async {}
}

class _FakeSleep implements SleepController {
  @override
  dynamic noSuchMethod(Invocation invocation) async => null;
}

class _FakeSoundPlayer implements NightSoundPlayer {
  int plays = 0;
  int stops = 0;
  Object? playError;

  @override
  bool get isPlaying => plays > stops;

  @override
  Future<void> play() async {
    if (playError != null) throw playError!;
    plays++;
  }

  @override
  Future<void> stop() async => stops++;
}

class _MemoryPrefs implements KeyValueStore {
  final Map<String, String> data = {};
  int writeCount = 0;

  @override
  Future<String?> read(String key) async => data[key];

  @override
  Future<void> write(String key, String value) async {
    writeCount++;
    data[key] = value;
  }
}

SleepModeController _build({
  required _FakeSoundPlayer sound,
  KeyValueStore? prefs,
}) {
  return SleepModeController(
    recorder: SleepRecorder(mic: _FakeMicSource(true)),
    sleep: _FakeSleep(),
    nightService: _FakeNightService(),
    soundPlayer: sound,
    prefs: prefs,
    // Alarm testi saniyeler içinde bitmeli: tick 30 ms, pencere 500 ms.
    alarmTick: const Duration(milliseconds: 30),
    alarmWindow: const Duration(milliseconds: 500),
  );
}

Future<void> _start(SleepModeController c) => c.start(
      notificationTitle: 't',
      notificationBody: 'b',
    );

void main() {
  test('ses KAPALIYKEN start sesi başlatmaz (opt-in pazarlıksız)', () async {
    final sound = _FakeSoundPlayer();
    final c = _build(sound: sound);

    await _start(c);

    expect(c.state.isRecording, isTrue);
    expect(sound.plays, 0);
  });

  test('ses AÇIKKEN start: kayıt+servis sağlamsa ses de başlar', () async {
    final sound = _FakeSoundPlayer();
    final c = _build(sound: sound);
    c.setSoundEnabled(true);

    await _start(c);

    expect(sound.plays, 1);
    expect(c.state.soundEnabled, isTrue);
    expect(c.state.soundFailed, isFalse);
  });

  test('kayıt DIŞINDA açılırsa yalnız tercih işaretlenir; ses start ile başlar',
      () async {
    final sound = _FakeSoundPlayer();
    final c = _build(sound: sound);
    c.setSoundEnabled(true);
    expect(sound.plays, 0, reason: 'kayıt yokken ses çalmaz');

    await _start(c);
    expect(sound.plays, 1);
  });

  test('stopAndSave: ses durur; tercih KORUNUR (kalıcı)', () async {
    final sound = _FakeSoundPlayer();
    final c = _build(sound: sound);
    c.setSoundEnabled(true);
    await _start(c);

    await c.stopAndSave();

    expect(sound.stops, greaterThanOrEqualTo(1));
    // Tercih KORUNUR — soundEnabled bir "oynatma durumu" değil, kullanıcı
    // niyetidir. Gece bitti ama yarın yine ses isteyecektir.
    expect(c.state.soundEnabled, isTrue);
  });

  test('ALARM ÇALARKEN ritüel sesi SUSAR', () async {
    final sound = _FakeSoundPlayer();
    final c = _build(sound: sound);
    c.setSoundEnabled(true);
    await _start(c);

    // Alarmı ~600 ms sonraya kur (pencere 500 ms): ilk tick'lerde henüz çalmaz,
    // son tarih geçince çalar. Bu sırada ritüel sesi SUSMALI.
    c.setAlarm(DateTime.now().add(const Duration(milliseconds: 600)));
    await Future<void>.delayed(const Duration(milliseconds: 900));

    expect(c.state.alarmRinging, isTrue, reason: 'test alarmı tetiklenmeli');
    expect(sound.stops, greaterThanOrEqualTo(1),
        reason: 'iki ses üst üste binerse ikisi de duyulmaz');
  });

  test('ses patlarsa GECE TAKİBİ SÜRER ve dipnot gösterilir', () async {
    final sound = _FakeSoundPlayer()..playError = Exception('audio busy');
    final c = _build(sound: sound);
    c.setSoundEnabled(true);

    await _start(c);

    expect(c.state.isRecording, isTrue, reason: 'ses hatası takibi düşürmez');
    expect(c.state.soundFailed, isTrue);
  });

  test('tercih KALICI: store\'da 1 varsa açılışta enabled=true; geri yükleme YAZMAZ',
      () async {
    final prefs = _MemoryPrefs()..data['night_sound_enabled'] = '1';
    final c = _build(sound: _FakeSoundPlayer(), prefs: prefs);
    await Future<void>.delayed(Duration.zero); // ctor'daki async okuma

    expect(c.state.soundEnabled, isTrue);
    expect(prefs.writeCount, 0,
        reason: 'okuma kendi yazdığını tekrar yazmamalı — gereksiz I/O');
  });

  test('tercih değişimi KAYDEDİLİR (persist default true)', () async {
    final prefs = _MemoryPrefs();
    final c = _build(sound: _FakeSoundPlayer(), prefs: prefs);

    c.setSoundEnabled(true);
    c.setSoundEnabled(false);

    expect(prefs.data['night_sound_enabled'], '0');
    expect(prefs.writeCount, 2);
    // jsonEncode burada yalnızca importun canlı kalması için değil: prefs değeri
    // tel üzerinde de bu biçimde ('0'/'1') saklanır — string şart.
    expect(prefs.data.values.every((v) => v == '0' || v == '1'), isTrue);
    expect(jsonEncode({'k': prefs.data['night_sound_enabled']}),
        contains('"0"'));
  });
}
