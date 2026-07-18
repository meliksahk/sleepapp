import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nocta/core/sleep_tracking/mic_source.dart';
import 'package:nocta/core/sleep_tracking/night_service.dart';
import 'package:nocta/core/sleep_tracking/sleep_recorder.dart';
import 'package:nocta/core/sleep_tracking/sleep_session_builder.dart';
import 'package:nocta/features/sleep/sleep_controller.dart';
import 'package:nocta/features/sleep/sleep_models.dart';
import 'package:nocta/features/sleep/sleep_mode_controller.dart';
import 'package:nocta/features/sleep/sleep_session_beacon.dart';

/// Controller ↔ kabuk şeridi arasındaki TEK bağ: `SleepSessionBeacon`.
///
/// Şeridin widget testleri ilan tahtasını elle doldurup kabuğu doğruluyor;
/// burada da controller'ın o tahtayı GERÇEKTEN doldurduğu kanıtlanıyor. İkisi
/// olmadan "gece başladı ama şerit çıkmadı" hatası testler yeşilken yaşayabilirdi.
class _FakeSleep implements SleepController {
  final List<SleepSessionDraft> saved = [];

  @override
  Future<SleepSession> recordSession(SleepSessionDraft draft) async {
    saved.add(draft);
    return SleepSession(
      id: 's1',
      startedAt: draft.startedAt.toIso8601String(),
      endedAt: draft.endedAt.toIso8601String(),
      nightDate: '2026-07-17',
      durationMinutes: draft.duration.inMinutes,
      movementEvents: draft.movementEvents,
      soundEvents: draft.soundEvents,
    );
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  Float32List frame(double a, {int n = 256}) {
    final f = Float32List(n);
    for (var i = 0; i < n; i++) {
      f[i] = i.isEven ? a : -a;
    }
    return f;
  }

  SleepModeController build({
    required SleepSessionBeacon beacon,
    bool permission = true,
    bool serviceCanStart = true,
  }) {
    return SleepModeController(
      recorder: SleepRecorder(
        mic: FakeMicSource(
          List.generate(40, (_) => frame(0.0001)),
          permission: permission,
        ),
      ),
      sleep: _FakeSleep(),
      nightService: FakeNightService(canStart: serviceCanStart),
      beacon: beacon,
    );
  }

  test('ÇEKİRDEK: gece başlayınca ilan tahtası AKTİF olur', () async {
    final beacon = SleepSessionBeacon();
    final c = build(beacon: beacon);
    expect(beacon.isActive, isFalse);

    await c.start(notificationTitle: 't', notificationBody: 'b');

    expect(beacon.isActive, isTrue);
    expect(beacon.startedAt, c.state.startedAt);
  });

  test('ÇEKİRDEK: gece bitince ilan tahtası TEMİZLENİR (şerit asılı kalmaz)', () async {
    final beacon = SleepSessionBeacon();
    final c = build(beacon: beacon);

    await c.start(notificationTitle: 't', notificationBody: 'b');
    expect(beacon.isActive, isTrue);

    await c.stopAndSave();
    expect(beacon.isActive, isFalse);
  });

  test('izin reddedilirse ilan YAPILMAZ (olmayan gece gösterilmez)', () async {
    final beacon = SleepSessionBeacon();
    final c = build(beacon: beacon, permission: false);

    await c.start(notificationTitle: 't', notificationBody: 'b');

    expect(beacon.isActive, isFalse);
  });

  test('SERVİS başlatılamazsa ilan YAPILMAZ (kayıt da başlamadı)', () async {
    final beacon = SleepSessionBeacon();
    final c = build(beacon: beacon, serviceCanStart: false);

    await c.start(notificationTitle: 't', notificationBody: 'b');

    expect(beacon.isActive, isFalse);
  });

  test('ilan tahtası GEREKSİZ yere dinleyici uyandırmaz (pil)', () async {
    // Olay sayacı gece boyunca defalarca değişir; her değişimde kabuğu yeniden
    // çizdirmek bir uyku uygulamasında doğrudan pil maliyeti demektir.
    final beacon = SleepSessionBeacon();
    var notifications = 0;
    beacon.addListener(() => notifications++);

    final at = DateTime(2026, 7, 17, 23);
    beacon
      ..begin(at)
      ..begin(at)
      ..begin(at);
    expect(notifications, 1);

    beacon
      ..end()
      ..end();
    expect(notifications, 2);
  });

  test('ilan tahtası olmadan da controller çalışır (opsiyonel bağ)', () async {
    final c = SleepModeController(
      recorder: SleepRecorder(
        mic: FakeMicSource(List.generate(40, (_) => frame(0.0001))),
      ),
      sleep: _FakeSleep(),
      nightService: FakeNightService(),
    );

    await c.start(notificationTitle: 't', notificationBody: 'b');
    expect(c.state.isRecording, isTrue);
  });

  test('formatElapsed sa:dk:sn — ekran ve şerit AYNI biçimi kullanır', () {
    expect(formatElapsed(Duration.zero), '00:00:00');
    expect(formatElapsed(const Duration(minutes: 90)), '01:30:00');
    expect(formatElapsed(const Duration(hours: 7, minutes: 5, seconds: 9)),
        '07:05:09');
    // Saat geri alınırsa (DST / kullanıcı saati) negatif fark oluşabilir;
    // "-1:-5:-9" göstermek yerine sıfırlanır.
    expect(formatElapsed(const Duration(seconds: -5)), '00:00:00');
  });
}
