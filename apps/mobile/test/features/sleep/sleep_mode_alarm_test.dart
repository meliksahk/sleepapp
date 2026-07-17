import 'dart:async';
import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nocta/core/sleep_tracking/alarm_sound.dart';
import 'package:nocta/core/sleep_tracking/mic_source.dart';
import 'package:nocta/core/sleep_tracking/night_service.dart';
import 'package:nocta/core/sleep_tracking/sleep_recorder.dart';
import 'package:nocta/core/sleep_tracking/smart_alarm.dart';
import 'package:nocta/core/sleep_tracking/sleep_session_builder.dart';
import 'package:nocta/features/sleep/sleep_controller.dart';
import 'package:nocta/features/sleep/sleep_mode_controller.dart';
import 'package:nocta/features/sleep/sleep_models.dart';

/// Akıllı alarmın **bağlanması** (docs/04 §86).
///
/// `SmartAlarm`'ın kendi mantığı #131'de test edilmişti — ve dört iterasyon boyunca
/// hiçbir yerden ÇAĞRILMADI: yeşil testleri olan ölü kod. Buradaki testler o mantığı
/// değil, **onu gerçekten tick'leyen ve sesi çalan halkayı** kanıtlar.
///
/// En tehlikeli hata "yanlış zamanda çalmak" değil, **HİÇ ÇALMAMAK**: kullanıcı işe
/// geç kalır ve nedenini asla öğrenemez. Testlerin ağırlığı orada.
class _FakeAlarmSound implements AlarmSound {
  int playCalls = 0;
  int stopCalls = 0;
  Object? failWith;

  @override
  Future<void> play() async {
    playCalls++;
    if (failWith != null) throw failWith!;
  }

  @override
  Future<void> stop() async => stopCalls++;

  @override
  Future<void> dispose() async {}
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

/// İSTENEN ANDA çerçeve iten mikrofon.
///
/// `FakeMicSource` çerçeveleri constructor'da alıp dinleyici bağlanır bağlanmaz
/// hepsini yayınlıyor — alarm testleri ise "45. dakikada ses çıkar" demek istiyor.
/// Sahte zamanla çalışan bir alarm için itilebilir bir kaynak şart.
class _PushMic implements MicSource {
  /// Varsayılan izinli; testler reddi doğrudan alanı yazarak dener.
  bool permission = true;
  StreamController<Float32List>? _c;

  @override
  Future<bool> hasPermission() async => permission;

  @override
  Stream<Float32List> start({required int sampleRate}) {
    final c = StreamController<Float32List>();
    _c = c;
    return c.stream;
  }

  /// Gürültü tabanının belirgin üstünde [frames] çerçeve — "kullanıcı kıpırdandı".
  void emitLoud({required int frames}) {
    for (var i = 0; i < frames; i++) {
      _c?.add(Float32List.fromList(List.filled(256, i.isEven ? 0.5 : -0.5)));
    }
  }

  /// Sessizlik — taban ölçümü ve "hiçbir şey olmuyor" için.
  void emitQuiet({required int frames}) {
    for (var i = 0; i < frames; i++) {
      _c?.add(Float32List.fromList(List.filled(256, i.isEven ? 0.001 : -0.001)));
    }
  }

  void emitError(Object e) => _c?.addError(e);

  @override
  Future<void> stop() async {
    final c = _c;
    _c = null;
    if (c != null && !c.isClosed) unawaited(c.close());
  }
}

void main() {
  late _PushMic mic;
  late _FakeAlarmSound sound;
  late FakeNightService service;
  late DateTime clock;

  SleepModeController build() {
    mic = _PushMic();
    sound = _FakeAlarmSound();
    service = FakeNightService();
    return SleepModeController(
      recorder: SleepRecorder(mic: mic, now: () => clock),
      sleep: _FakeSleep(),
      nightService: service,
      alarmSound: sound,
      alarmWindow: const Duration(minutes: 30),
      alarmTick: const Duration(seconds: 10),
      now: () => clock,
    );
  }

  Future<void> startNight(SleepModeController c) =>
      c.start(notificationTitle: 't', notificationBody: 'b');

  /// Sessiz oda: dedektörün gürültü TABANINI oturtur.
  ///
  /// Şart, çünkü taban uyarlanır: ilk çerçeveler gürültülüyse taban ORAYA oturur ve
  /// sonraki gürültü "normal" sayılır — hiç olay çıkmaz. Gerçek gece de böyle başlar
  /// (sessiz oda → hareket), test de öyle başlamalı.
  void settleFloor(FakeAsync async) {
    mic.emitQuiet(frames: 100);
    async.flushMicrotasks();
  }

  group('son tarih — PAZARLIKSIZ', () {
    test('ÇEKİRDEK: hafif uyku HİÇ görülmese de pencere sonunda ÇALAR', () {
      fakeAsync((async) {
        clock = DateTime(2026, 7, 17, 6, 0);
        final c = build();
        c.setAlarm(clock.add(const Duration(minutes: 40)));
        startNight(c);
        async.flushMicrotasks();

        // Hiç ses verilmiyor: kullanıcı taş gibi uyuyor.
        clock = clock.add(const Duration(minutes: 41));
        async.elapse(const Duration(minutes: 41));

        // Sinyal beklerken sessiz kalmak = kullanıcı işe geç kalır.
        expect(c.state.alarmRinging, isTrue);
        expect(c.state.alarmTrigger, AlarmTrigger.deadline);
        expect(sound.playCalls, 1);
      });
    });

    test('ÇEKİRDEK: MİKROFON ÖLSE BİLE alarm çalar', () {
      fakeAsync((async) {
        clock = DateTime(2026, 7, 17, 6, 0);
        final c = build();
        c.setAlarm(clock.add(const Duration(minutes: 40)));
        startNight(c);
        async.flushMicrotasks();

        // Mikrofon akışı ölüyor (izin çekildi / OS kesti / cihaz kısıldı).
        mic.emitError(StateError('mic öldü'));
        async.flushMicrotasks();

        clock = clock.add(const Duration(minutes: 41));
        async.elapse(const Duration(minutes: 41));

        // Alarm mikrofonun onProgress'ine bağlı olsaydı BURADA SESSİZ KALIRDI.
        // Tick'in Timer'a bağlı olmasının tek sebebi bu.
        expect(c.state.alarmRinging, isTrue, reason: 'mikrofon ölünce alarm ölmemeli');
        expect(sound.playCalls, 1);
      });
    });
  });

  group('hafif uyku', () {
    test('pencere İÇİNDE aktivite görülünce erken çalar', () {
      fakeAsync((async) {
        clock = DateTime(2026, 7, 17, 6, 0);
        final c = build();
        // Hedef 40 dk sonra → pencere 10. dakikada açılır.
        c.setAlarm(clock.add(const Duration(minutes: 40)));
        startNight(c);
        async.flushMicrotasks();

        settleFloor(async);

        // 15. dakika: pencere açık. Kullanıcı kıpırdanıyor.
        clock = clock.add(const Duration(minutes: 15));
        async.elapse(const Duration(minutes: 15));
        mic.emitLoud(frames: 400);
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 20));

        expect(c.state.alarmRinging, isTrue);
        expect(c.state.alarmTrigger, AlarmTrigger.lightSleep);
      });
    });

    test('ÇEKİRDEK: pencere AÇILMADAN aktivite olsa da ÇALMAZ', () {
      fakeAsync((async) {
        clock = DateTime(2026, 7, 17, 6, 0);
        final c = build();
        c.setAlarm(clock.add(const Duration(minutes: 40)));
        startNight(c);
        async.flushMicrotasks();

        settleFloor(async);

        // 5. dakika: pencere daha açılmadı (10. dakikada açılacak).
        clock = clock.add(const Duration(minutes: 5));
        async.elapse(const Duration(minutes: 5));
        mic.emitLoud(frames: 400);
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 20));

        // Söz verdiğimizden erken uyandırmak, alarmı işe yaramaz kılar.
        expect(c.state.alarmRinging, isFalse);
        expect(sound.playCalls, 0);
      });
    });
  });

  group('kurulum', () {
    test('ÇEKİRDEK: alarm YOKSA hiç çalmaz (opt-in)', () {
      fakeAsync((async) {
        clock = DateTime(2026, 7, 17, 6, 0);
        final c = build();
        startNight(c); // setAlarm YOK
        async.flushMicrotasks();

        clock = clock.add(const Duration(hours: 9));
        async.elapse(const Duration(hours: 9));

        // Varsayılan saat uydurmak, kullanıcıyı beklemediği anda uyandırmak olurdu.
        expect(c.state.alarmRinging, isFalse);
        expect(sound.playCalls, 0);
      });
    });

    test('pencereden KISA alarm: pencere sadece KISALIR (sınır, kabul edilmiş)', () {
      fakeAsync((async) {
        clock = DateTime(2026, 7, 17, 6, 0);
        final c = build();
        // 5 dk sonrası: `at - 30dk` geçmişte kalır → pencere BAŞTAN açık.
        c.setAlarm(clock.add(const Duration(minutes: 5)));
        startNight(c);
        async.flushMicrotasks();
        settleFloor(async);

        mic.emitLoud(frames: 400);
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 20));

        // Kullanıcı henüz uyumadan kıpırdarsa erken çalar. Bu bir HATA değil,
        // kabul edilmiş sınır: hata payı tanım gereği 30 dk'dan küçük ve kullanıcı
        // zaten "beni birazdan uyandır" demiş. Gerçek gecede (8 saat) pencere
        // sabaha kadar açılmaz.
        expect(c.state.alarmRinging, isTrue);
        expect(c.state.alarmTrigger, AlarmTrigger.lightSleep);
      });
    });

    test('kayıt BAŞLAMAZSA alarm da kurulmaz', () {
      fakeAsync((async) {
        clock = DateTime(2026, 7, 17, 6, 0);
        final c = build();
        mic.permission = false; // kullanıcı mikrofonu reddetti
        c.setAlarm(clock.add(const Duration(minutes: 40)));
        startNight(c);
        async.flushMicrotasks();

        clock = clock.add(const Duration(minutes: 41));
        async.elapse(const Duration(minutes: 41));

        // Hiçbir şey kaydetmeyen bir alarm yalan olurdu.
        expect(c.state.permissionDenied, isTrue);
        expect(c.state.alarmRinging, isFalse);
      });
    });
  });

  group('susturma ve bitiş', () {
    test('ÇEKİRDEK: sustur → ses durur, KAYIT DEVAM EDER', () {
      fakeAsync((async) {
        clock = DateTime(2026, 7, 17, 6, 0);
        final c = build();
        c.setAlarm(clock.add(const Duration(minutes: 40)));
        startNight(c);
        async.flushMicrotasks();
        clock = clock.add(const Duration(minutes: 41));
        async.elapse(const Duration(minutes: 41));
        expect(c.state.alarmRinging, isTrue);

        c.dismissAlarm();
        async.flushMicrotasks();

        expect(c.state.alarmRinging, isFalse);
        expect(sound.stopCalls, 1);
        // Alarmı kapatmak geceyi bitirmez: kullanıcı uyumaya dönebilir.
        expect(c.state.isRecording, isTrue);
      });
    });

    test('ÇEKİRDEK: BİR KEZ çalar — her tick\'te yeniden tetiklenmez', () {
      fakeAsync((async) {
        clock = DateTime(2026, 7, 17, 6, 0);
        final c = build();
        c.setAlarm(clock.add(const Duration(minutes: 40)));
        startNight(c);
        async.flushMicrotasks();

        clock = clock.add(const Duration(minutes: 45));
        async.elapse(const Duration(minutes: 45));

        // 10 sn'de bir tick × 5 dk = 30 tick. Ses 30 kez başlatılsaydı üst üste
        // binen bir gürültü olurdu.
        expect(sound.playCalls, 1);
      });
    });

    test('ÇEKİRDEK: gece bitince alarm SUSAR ve bir daha çalmaz', () {
      fakeAsync((async) {
        clock = DateTime(2026, 7, 17, 6, 0);
        final c = build();
        c.setAlarm(clock.add(const Duration(minutes: 40)));
        startNight(c);
        async.flushMicrotasks();

        c.stopAndSave();
        async.flushMicrotasks();

        clock = clock.add(const Duration(hours: 2));
        async.elapse(const Duration(hours: 2));

        // Ekran kapandıktan sonra çalan alarm kabul edilemez.
        expect(c.state.alarmRinging, isFalse);
        expect(sound.playCalls, 0);
      });
    });
  });

  test('ses patlarsa alarm yine de ÇALMIŞ sayılır (ekran uyandırır)', () {
    fakeAsync((async) {
      clock = DateTime(2026, 7, 17, 6, 0);
      final c = build();
      sound.failWith = StateError('hoparlör yok');
      c.setAlarm(clock.add(const Duration(minutes: 40)));
      startNight(c);
      async.flushMicrotasks();

      clock = clock.add(const Duration(minutes: 41));
      async.elapse(const Duration(minutes: 41));

      // Ses çıkmasa da kullanıcı ekranı görürse uyanır; "çalmadı" demek daha kötü.
      expect(c.state.alarmRinging, isTrue);
      expect(c.state.error, isNotNull); // hata YUTULMAZ
    });
  });
}
