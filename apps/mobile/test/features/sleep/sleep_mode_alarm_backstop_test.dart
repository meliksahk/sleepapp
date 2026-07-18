import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nocta/core/sleep_tracking/mic_source.dart';
import 'package:nocta/core/sleep_tracking/night_alarm_scheduler.dart';
import 'package:nocta/core/sleep_tracking/night_service.dart';
import 'package:nocta/core/sleep_tracking/sleep_recorder.dart';
import 'package:nocta/core/sleep_tracking/sleep_session_builder.dart';
import 'package:nocta/features/sleep/sleep_controller.dart';
import 'package:nocta/features/sleep/sleep_mode_controller.dart';
import 'package:nocta/features/sleep/sleep_models.dart';

/// **Sistem-zamanlı alarm backstop'unun BAĞLANMASI (#169).**
///
/// In-app akıllı alarm (Timer) süreç öldürülünce sessizce ölür. Bu testler,
/// controller'ın son-tarih anını sistem scheduler'ına DOĞRU anda kurup/iptal
/// ettiğini kanıtlar — "ölü süreçte gerçekten çalar mı?" cihaz-kapılı ve burada
/// KANITLANMAZ (dürüstlük sınırı: bkz. `PlatformNightAlarmScheduler`).
class _RecordingScheduler implements NightAlarmScheduler {
  final List<DateTime> scheduled = [];
  int cancelCount = 0;

  @override
  Future<void> schedule(DateTime at) async => scheduled.add(at);

  @override
  Future<void> cancel() async => cancelCount++;
}

class _FakeSleep implements SleepController {
  @override
  Future<SleepSession> recordSession(SleepSessionDraft draft) async => SleepSession(
        id: 's1',
        startedAt: draft.startedAt.toIso8601String(),
        endedAt: draft.endedAt.toIso8601String(),
        nightDate: '2026-07-17',
        durationMinutes: draft.duration.inMinutes,
        movementEvents: draft.movementEvents,
        soundEvents: draft.soundEvents,
      );

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _RecordingScheduler scheduler;
  late DateTime clock;

  SleepModeController build() {
    scheduler = _RecordingScheduler();
    return SleepModeController(
      recorder: SleepRecorder(mic: FakeMicSource(const []), now: () => clock),
      sleep: _FakeSleep(),
      nightService: FakeNightService(),
      alarmScheduler: scheduler,
      now: () => clock,
    );
  }

  Future<void> startNight(SleepModeController c) =>
      c.start(notificationTitle: 't', notificationBody: 'b');

  group('backstop bağlanması', () {
    test('ÇEKİRDEK: gece başlayınca sistem alarmı SON-TARİHE kurulur', () async {
      clock = DateTime(2026, 7, 17, 6, 0);
      final c = build();
      final deadline = clock.add(const Duration(minutes: 40));
      c.setAlarm(deadline);
      await startNight(c);

      // In-app alarm hafif uykuda daha erken çalabilir; sistem backstop garanti
      // son-tarihe kurulmalı (ölü süreçte OS'un uyandıracağı an).
      expect(scheduler.scheduled, [deadline]);
    });

    test('alarm YOKSA sistem alarmı da kurulmaz', () async {
      clock = DateTime(2026, 7, 17, 6, 0);
      final c = build();
      await startNight(c); // setAlarm çağrılmadı
      expect(scheduler.scheduled, isEmpty);
    });

    test('ÇEKİRDEK: alarm susturulunca sistem backstop İPTAL edilir', () async {
      clock = DateTime(2026, 7, 17, 6, 0);
      final c = build();
      c.setAlarm(clock.add(const Duration(minutes: 40)));
      await startNight(c);
      await c.dismissAlarm();
      // Kullanıcı uyandı → ölü süreçte OS ikinci kez çalmamalı.
      expect(scheduler.cancelCount, greaterThanOrEqualTo(1));
    });

    test('ÇEKİRDEK: gece bitince sistem backstop İPTAL edilir', () async {
      clock = DateTime(2026, 7, 17, 6, 0);
      final c = build();
      c.setAlarm(clock.add(const Duration(minutes: 40)));
      await startNight(c);
      clock = clock.add(const Duration(minutes: 5));
      await c.stopAndSave();
      // Ekran kapandıktan sonra OS'un alarmı çalması kabul edilemez.
      expect(scheduler.cancelCount, greaterThanOrEqualTo(1));
    });

    test('alarm kaldırılınca (kayıt sürerken) sistem backstop iptal edilir', () async {
      clock = DateTime(2026, 7, 17, 6, 0);
      final c = build();
      c.setAlarm(clock.add(const Duration(minutes: 40)));
      await startNight(c);
      expect(scheduler.scheduled.length, 1);

      c.setAlarm(null); // yatakta fikir değişti
      await Future<void>.delayed(Duration.zero);
      expect(scheduler.cancelCount, greaterThanOrEqualTo(1));
    });
  });

  group('kanal sözleşmesi — Kotlin/native tarafıyla eşleşmeli', () {
    late List<MethodCall> calls;

    setUp(() {
      calls = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(PlatformNightAlarmScheduler.channel, (call) async {
        calls.add(call);
        return null;
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(PlatformNightAlarmScheduler.channel, null);
    });

    test('ÇEKİRDEK: kanal adı, yöntem ve argüman anahtarı native ile aynı', () async {
      const s = PlatformNightAlarmScheduler();
      final at = DateTime.utc(2026, 7, 17, 6, 30);
      await s.schedule(at);
      await s.cancel();

      expect(PlatformNightAlarmScheduler.channel.name, 'nocta/night_alarm');
      expect(calls.map((c) => c.method).toList(), ['schedule', 'cancel']);
      // Native taraf `call.argument<Long>("epochMillis")` ile okuyacak; anahtar
      // değişirse cihazda alarm kurulmaz, testte sessizlik olurdu.
      expect((calls[0].arguments as Map)['epochMillis'], at.millisecondsSinceEpoch);
    });
  });

  group('en iyi çaba — eksik native taraf akışı BOZMAZ', () {
    test('ÇEKİRDEK: native handler yoksa schedule/cancel HATA ATMAZ', () async {
      // Hiç mock handler yok → invokeMethod MissingPluginException atar. Backstop
      // en iyi çabadır: iOS'ta / native handler yazılmadan in-app alarm birincil
      // yol kalmalı, çağrı sessizce tamamlanmalı (yutulur ama loglanır).
      const s = PlatformNightAlarmScheduler();
      await expectLater(s.schedule(DateTime(2026, 7, 17, 6, 0)), completes);
      await expectLater(s.cancel(), completes);
    });
  });
}
