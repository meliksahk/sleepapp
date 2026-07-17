import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nocta/core/sleep_tracking/event_detector.dart';
import 'package:nocta/core/sleep_tracking/mic_source.dart';
import 'package:nocta/core/sleep_tracking/sleep_recorder.dart';

/// Mikrofon → gece raporu hattı.
///
/// #128–#132'de bu hattın parçaları tek tek yazılıp test edildi ama **hiçbiri
/// birbirine bağlanmadı** — `recordSession`'ın üretimde çağıranı yoktu. Bu dosya
/// hattın gerçekten uçtan uca çalıştığını kanıtlıyor.
void main() {
  /// [-1,1] aralığında, verilen genlikte sabit bir çerçeve.
  Float32List frame(double amplitude, {int n = 256}) {
    final f = Float32List(n);
    for (var i = 0; i < n; i++) {
      // Kare dalga: RMS = genlik → dB hesabı öngörülebilir olsun.
      f[i] = i.isEven ? amplitude : -amplitude;
    }
    return f;
  }

  /// Sessiz taban + ortasında yüksek bir olay.
  List<Float32List> nightWith({required int events}) {
    final frames = <Float32List>[];
    void quiet(int n) => frames.addAll(List.generate(n, (_) => frame(0.0001)));
    void loud(int n) => frames.addAll(List.generate(n, (_) => frame(0.5)));

    quiet(30); // taban otursun
    for (var i = 0; i < events; i++) {
      loud(5);
      quiet(30); // refractory + taban
    }
    return frames;
  }

  var fakeNow = DateTime.utc(2026, 7, 17, 23, 0);
  DateTime nowFn() => fakeNow;

  setUp(() => fakeNow = DateTime.utc(2026, 7, 17, 23, 0));

  test('izin yoksa start() FALSE döner (çökmez, kullanıcının kararı)', () async {
    final rec = SleepRecorder(
      mic: FakeMicSource([], permission: false),
      now: nowFn,
    );

    expect(await rec.start(), isFalse);
    expect(rec.isRecording, isFalse);
  });

  test('izin varsa kayıt başlar', () async {
    final rec = SleepRecorder(mic: FakeMicSource(nightWith(events: 0)), now: nowFn);
    expect(await rec.start(), isTrue);
    expect(rec.isRecording, isTrue);
  });

  test('ÇEKİRDEK: mikrofon → dB → dedektör → taslak (uçtan uca)', () async {
    final rec = SleepRecorder(mic: FakeMicSource(nightWith(events: 3)), now: nowFn);

    await rec.start();
    await Future<void>.delayed(Duration.zero); // akış aksın
    fakeNow = fakeNow.add(const Duration(hours: 7));
    final draft = await rec.stop();

    expect(draft, isNotNull);
    // Beş iterasyonluk ölü kod artık gerçek bir sayı üretiyor.
    expect(draft!.soundEvents, greaterThan(0));
    expect(draft.duration, const Duration(hours: 7));
  });

  test('ÇEKİRDEK: sessiz gece → SIFIR olay (HAYALET OLAY YOK)', () async {
    // Bu test bir hatayı yakaladı: dedektörün tabanı -100 dB'den (mutlak sessizlik)
    // başlıyordu, gerçek oda ~-60 dB → her gecenin BAŞINDA uydurma bir olay sayılırdı.
    // Isınma (ilk 16 çerçeve yalnızca tabanı ölçer) bunu kapattı.
    final rec = SleepRecorder(
      mic: FakeMicSource(List.generate(100, (_) => frame(0.0001))),
      now: nowFn,
    );

    await rec.start();
    await Future<void>.delayed(Duration.zero);
    final draft = await rec.stop();

    expect(draft!.soundEvents, 0);
  });

  test('ÇEKİRDEK: movementEvents SIFIR — ölçmediğimiz şeyi uydurmuyoruz', () async {
    // "Hareket" ile "ses" ayrımı gerçek gece kayıtlarıyla doğrulanmadı (docs/04 §120
    // fixture'ları yok). Ayrımı uydurup kullanıcıya güvenilir gibi sunmak, ölçmediğimiz
    // bir şeyi ölçmüş gibi göstermek olurdu (DECISIONS D-10).
    final rec = SleepRecorder(mic: FakeMicSource(nightWith(events: 5)), now: nowFn);

    await rec.start();
    await Future<void>.delayed(Duration.zero);
    final draft = await rec.stop();

    expect(draft!.movementEvents, 0);
    expect(draft.soundEvents, greaterThan(0));
  });

  test('hiç başlamadan stop() → null (çökmez)', () async {
    final rec = SleepRecorder(mic: FakeMicSource([]), now: nowFn);
    expect(await rec.stop(), isNull);
  });

  test('stop() mikrofonu GERÇEKTEN kapatır (gece boyu pil yemesin)', () async {
    final mic = FakeMicSource(nightWith(events: 1));
    final rec = SleepRecorder(mic: mic, now: nowFn);

    await rec.start();
    await Future<void>.delayed(Duration.zero);
    await rec.stop();

    expect(mic.stopped, isTrue);
  });

  test('canlı sayaç UI için güncellenir', () async {
    final rec = SleepRecorder(mic: FakeMicSource(nightWith(events: 2)), now: nowFn);
    var progressCalls = 0;
    rec.onProgress = () => progressCalls++;

    await rec.start();
    await Future<void>.delayed(Duration.zero);

    expect(progressCalls, greaterThan(0));
    expect(rec.eventCount, greaterThanOrEqualTo(0));
    await rec.stop();
  });

  test('ÇEKİRDEK: açık kalan son olay KAYBOLMAZ (finish çağrılır)', () async {
    // Kayıt tam bir ses sırasında bitti: dedektör olayı kapatmazsa o olay sessizce
    // kaybolurdu — ve kullanıcı sabah eksik bir rapor görürdü.
    final frames = <Float32List>[
      ...List.generate(30, (_) => frame(0.0001)),
      ...List.generate(5, (_) => frame(0.5)), // ses HÂLÂ sürerken akış bitiyor
    ];
    final rec = SleepRecorder(mic: FakeMicSource(frames), now: nowFn);

    await rec.start();
    await Future<void>.delayed(Duration.zero);
    final draft = await rec.stop();

    expect(draft!.soundEvents, 1);
  });

  test('zaman UTC (CLAUDE.md §4 — gece gruplaması kaymasın)', () async {
    final rec = SleepRecorder(mic: FakeMicSource(nightWith(events: 1)), now: nowFn);
    await rec.start();
    await Future<void>.delayed(Duration.zero);
    final draft = await rec.stop();

    expect(draft!.startedAt.isUtc, isTrue);
    expect(draft.toJson()['startedAt'], contains('Z'));
  });

  test('dedektör enjekte edilebilir (eşikler ayarlanınca kod değişmesin)', () async {
    // Eşikler gerçek gece kayıtlarıyla AYARLANMADI (docs/04 §120 fixture'ları yok);
    // ayarlandığında BURASI değişmemeli — fabrika o yüzden var.
    //
    // Sinyal tabanın ~74 dB üstünde (sessiz -80, yüksek -6 dBFS). 90 dB eşik hiçbir
    // şeyin sayılmamasını sağlar → fabrikanın gerçekten etkili olduğunu kanıtlar.
    final rec = SleepRecorder(
      mic: FakeMicSource(nightWith(events: 3)),
      detectorFactory: (floor) =>
          AcousticEventDetector(thresholdDb: 90.0, initialFloorDb: floor),
      now: nowFn,
    );

    await rec.start();
    await Future<void>.delayed(Duration.zero);
    final draft = await rec.stop();

    expect(draft!.soundEvents, 0);
  });

  test('isınma bitmeden biten kayıt SIFIR döner (uydurma yok)', () async {
    // 5 çerçevelik bir "gece"de ölçecek bir şey yok; dedektör hiç kurulmaz.
    final rec = SleepRecorder(
      mic: FakeMicSource(List.generate(5, (_) => frame(0.5))),
      now: nowFn,
    );

    await rec.start();
    await Future<void>.delayed(Duration.zero);
    final draft = await rec.stop();

    expect(draft!.soundEvents, 0);
  });

  test('taban MEDYANLA ölçülür (ısınmada kapı çarpması tabanı bozmasın)', () async {
    // Isınmanın ortasında tek bir gürültü patlaması olsa bile taban sessizliği
    // yansıtmalı; ortalama alsaydık patlama tabanı yükseltir ve gecenin geri kalanı
    // sağırlaşırdı.
    final frames = <Float32List>[
      ...List.generate(8, (_) => frame(0.0001)),
      frame(0.9), // ısınma sırasında kapı çarptı
      ...List.generate(7, (_) => frame(0.0001)),
      ...List.generate(30, (_) => frame(0.0001)),
      ...List.generate(5, (_) => frame(0.5)), // gerçek olay
      ...List.generate(30, (_) => frame(0.0001)),
    ];
    final rec = SleepRecorder(mic: FakeMicSource(frames), now: nowFn);

    await rec.start();
    await Future<void>.delayed(Duration.zero);
    final draft = await rec.stop();

    // Taban sessizlikte kaldıysa gerçek olay sayılır.
    expect(draft!.soundEvents, greaterThan(0));
  });
}
