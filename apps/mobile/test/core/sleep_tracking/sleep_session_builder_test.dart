import 'package:flutter_test/flutter_test.dart';
import 'package:nocta/core/sleep_tracking/event_detector.dart';
import 'package:nocta/core/sleep_tracking/sleep_session_builder.dart';

/// Dedektör çıktısı → API oturum taslağı.
///
/// **BU TESTLER DAVRANIŞI SABİTLER, DOĞRULUĞU DEĞİL.** Süre-tabanlı hareket/ses
/// ayrımı gerçek gece kayıtlarıyla ayarlanmadı (docs/04 §120 fixture'ları yok).
/// "20 çerçeve = hareket" bir ÖLÇÜM değil, bir varsayımdır — testler yalnızca
/// kodun o varsayımı tutarlı uyguladığını gösterir.
void main() {
  AcousticEvent event({int duration = 5, int start = 0}) =>
      AcousticEvent(startFrame: start, durationFrames: duration, peakDb: -20, floorDb: -60);

  final start = DateTime.utc(2026, 7, 16, 23, 0);
  final end = DateTime.utc(2026, 7, 17, 6, 42);

  group('sınıflandırma (süre tabanlı — DOĞRULANMADI)', () {
    test('KISA olay → hareket (dönme/hışırtı)', () {
      expect(classifyEvent(event(duration: 5)), AcousticEventKind.movement);
    });

    test('UZUN olay → ses (horlama/köpek/trafik)', () {
      expect(classifyEvent(event(duration: 200)), AcousticEventKind.sound);
    });

    test('sınır dahildir: tam eşik hareket sayılır', () {
      expect(classifyEvent(event(duration: 20)), AcousticEventKind.movement);
      expect(classifyEvent(event(duration: 21)), AcousticEventKind.sound);
    });

    test('eşik ayarlanabilir (fixture geldiğinde değişecek olan tek şey)', () {
      expect(
        classifyEvent(event(duration: 30), maxMovementFrames: 40),
        AcousticEventKind.movement,
      );
    });
  });

  group('buildSleepSession', () {
    test('olayları iki kovaya ayırır', () {
      final draft = buildSleepSession(
        events: [
          event(duration: 3), // hareket
          event(duration: 8), // hareket
          event(duration: 150), // ses
        ],
        startedAt: start,
        endedAt: end,
      );
      expect(draft.movementEvents, 2);
      expect(draft.soundEvents, 1);
    });

    test('olay yoksa sıfırlar (sessiz gece geçerli bir gecedir)', () {
      final draft = buildSleepSession(events: [], startedAt: start, endedAt: end);
      expect(draft.movementEvents, 0);
      expect(draft.soundEvents, 0);
    });

    test('süre hesaplanır', () {
      final draft = buildSleepSession(events: [], startedAt: start, endedAt: end);
      expect(draft.duration, const Duration(hours: 7, minutes: 42));
    });

    test('sıfır uzunlukta oturum kabul (kullanıcı hemen vazgeçti)', () {
      final draft = buildSleepSession(events: [], startedAt: start, endedAt: start);
      expect(draft.duration, Duration.zero);
    });

    test('bitiş başlangıçtan önce olamaz (assert)', () {
      expect(
        () => buildSleepSession(events: [], startedAt: end, endedAt: start),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('toJson — API sözleşmesi', () {
    test('alanlar RecordSleepSessionDto ile birebir', () {
      final json = buildSleepSession(
        events: [event(duration: 3), event(duration: 150)],
        startedAt: start,
        endedAt: end,
      ).toJson();

      expect(json.keys.toSet(), {'startedAt', 'endedAt', 'movementEvents', 'soundEvents'});
      expect(json['movementEvents'], 1);
      expect(json['soundEvents'], 1);
    });

    test('ÇEKİRDEK: zaman UTC + ISO 8601 gider (CLAUDE.md §4)', () {
      // Yerel saatle göndermek, sunucudaki "gece" gruplamasını (06:00 sınırı)
      // SESSİZCE kaydırırdı: kullanıcı gecesini yanlış günde görürdü.
      final local = DateTime.utc(2026, 7, 17, 5, 30).toLocal();
      final json = buildSleepSession(
        events: [],
        startedAt: local,
        endedAt: local.add(const Duration(hours: 1)),
      ).toJson();

      expect(json['startedAt'], '2026-07-17T05:30:00.000Z');
      expect(json['startedAt'] as String, endsWith('Z'));
      expect(json['endedAt'] as String, endsWith('Z'));
    });

    test('HAM VERİ SIZMAZ: gövdede yalnızca sayı ve zaman var (CLAUDE.md §6)', () {
      // Gizlilik iddiamızın somut hâli: zarf, olay detayı, dB — hiçbiri gitmez.
      final json = buildSleepSession(
        events: [event(duration: 3)],
        startedAt: start,
        endedAt: end,
      ).toJson();

      final serialized = json.toString();
      expect(serialized, isNot(contains('peakDb')));
      expect(serialized, isNot(contains('floorDb')));
      expect(serialized, isNot(contains('startFrame')));
      expect(json.length, 4);
    });
  });

  test('gerçekçi gece: 8 kısa dönme + 2 horlama → 8 hareket / 2 ses', () {
    final draft = buildSleepSession(
      events: [
        ...List.generate(8, (i) => event(duration: 4, start: i * 1000)),
        event(duration: 90, start: 9000),
        event(duration: 120, start: 12000),
      ],
      startedAt: start,
      endedAt: end,
    );
    expect(draft.movementEvents, 8);
    expect(draft.soundEvents, 2);
  });
}
