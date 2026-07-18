import 'package:flutter_test/flutter_test.dart';
import 'package:nocta/core/sleep_tracking/mic_source.dart';
import 'package:nocta/core/sleep_tracking/night_service.dart';
import 'package:nocta/core/sleep_tracking/sleep_recorder.dart';
import 'package:nocta/core/sleep_tracking/sleep_session_builder.dart';
import 'package:nocta/core/sleep_tracking/sleep_session_queue.dart';
import 'package:nocta/core/storage/key_value_store.dart';
import 'package:nocta/features/sleep/sleep_controller.dart';
import 'package:nocta/features/sleep/sleep_mode_controller.dart';
import 'package:nocta/features/sleep/sleep_models.dart';

/// Çevrimdışı kuyruğun CONTROLLER'a bağlanması (#177). Saf kuyruk mantığı
/// `sleep_session_queue_test.dart`'ta; buradaki testler onu gerçekten TETİKLEYEN
/// halkayı kanıtlar: kayıt başarısız→kuyruğa, başarı sonrası + açılışta DRAIN.
/// Müdür şartı: "kuyruğa yaz ama hiç boşaltma" = ölü kod → drain tetikleri test'li.
class _ControllableSleep implements SleepController {
  bool fail = false;
  final List<SleepSessionDraft> uploaded = [];

  @override
  Future<SleepSession> recordSession(SleepSessionDraft draft) async {
    if (fail) throw Exception('çevrimdışı');
    uploaded.add(draft);
    return SleepSession(
      id: 's${uploaded.length}',
      startedAt: draft.startedAt.toIso8601String(),
      endedAt: draft.endedAt.toIso8601String(),
      nightDate: '2026-07-18',
      durationMinutes: draft.duration.inMinutes,
      movementEvents: draft.movementEvents,
      soundEvents: draft.soundEvents,
    );
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 20));

void main() {
  late _ControllableSleep sleep;
  late SleepSessionQueue queue;
  late InMemoryKeyValueStore store;
  late DateTime clock;

  SleepModeController build() {
    store = InMemoryKeyValueStore();
    queue = SleepSessionQueue(store);
    return SleepModeController(
      recorder: SleepRecorder(mic: FakeMicSource(const []), now: () => clock),
      sleep: sleep,
      nightService: FakeNightService(),
      sessionQueue: queue,
      now: () => clock,
    );
  }

  Future<void> night(SleepModeController c) async {
    await c.start(notificationTitle: 't', notificationBody: 'b');
    clock = clock.add(const Duration(hours: 7));
    await c.stopAndSave();
  }

  setUp(() {
    sleep = _ControllableSleep();
    clock = DateTime(2026, 7, 18, 23, 0);
  });

  test('ÇEKİRDEK: kayıt BAŞARISIZ olunca gece KUYRUĞA alınır (kaybolmaz)', () async {
    sleep.fail = true;
    final c = build();
    await settle(); // açılış drain'i (boş kuyruk) bitsin
    await night(c);

    expect(sleep.uploaded, isEmpty); // sunucuya yazılamadı
    expect(await queue.pending(), 1); // ama gece korundu
  });

  test('ÇEKİRDEK: bir sonraki BAŞARILI kayıttan sonra kuyruk DRAIN edilir', () async {
    // Gece 1: çevrimdışı → kuyruğa.
    sleep.fail = true;
    final c = build();
    await settle();
    await night(c);
    expect(await queue.pending(), 1);

    // Gece 2: online → hem gece 2 yazılır hem kuyruktaki gece 1 boşaltılır.
    sleep.fail = false;
    await night(c);

    expect(await queue.pending(), 0); // kuyruk boşaldı
    expect(sleep.uploaded.length, 2); // gece 2 + drain edilen gece 1
  });

  test('ÇEKİRDEK: AÇILIŞTA bekleyen çevrimdışı geceler boşaltılır (init drain)', () async {
    // Önceki oturumdan kalan bir gece (aynı store'a doğrudan yazılmış).
    store = InMemoryKeyValueStore();
    queue = SleepSessionQueue(store);
    await queue.enqueue(SleepSessionDraft(
      startedAt: DateTime.utc(2026, 7, 17, 23),
      endedAt: DateTime.utc(2026, 7, 18, 6),
      movementEvents: 5,
      soundEvents: 9,
    ));

    sleep.fail = false;
    // Controller kurulunca constructor init-drain'i tetikler.
    SleepModeController(
      recorder: SleepRecorder(mic: FakeMicSource(const []), now: () => clock),
      sleep: sleep,
      nightService: FakeNightService(),
      sessionQueue: queue,
      now: () => clock,
    );
    await settle();

    expect(await queue.pending(), 0); // açılışta boşaldı
    expect(sleep.uploaded.length, 1);
    expect(sleep.uploaded.first.movementEvents, 5);
  });

  test('kuyruk YOKSA eski davranış (kayıt başarısız → yalnızca hata, çökme yok)', () async {
    sleep.fail = true;
    final c = SleepModeController(
      recorder: SleepRecorder(mic: FakeMicSource(const []), now: () => clock),
      sleep: sleep,
      nightService: FakeNightService(),
      // sessionQueue verilmedi
      now: () => clock,
    );
    await night(c);
    expect(c.state.error, isNotNull); // hata gösterildi, akış bozulmadı
  });
}
