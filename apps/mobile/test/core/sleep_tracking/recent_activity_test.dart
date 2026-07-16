import 'package:flutter_test/flutter_test.dart';
import 'package:nocta/core/sleep_tracking/event_detector.dart';
import 'package:nocta/core/sleep_tracking/recent_activity.dart';
import 'package:nocta/core/sleep_tracking/smart_alarm.dart';

/// Dedektör (çerçeve birimi) → alarm (duvar saati) köprüsü.
void main() {
  AcousticEvent event({required int start, int duration = 5}) =>
      AcousticEvent(startFrame: start, durationFrames: duration, peakDb: -20, floorDb: -60);

  const frame = Duration(milliseconds: 50); // ~50 ms/çerçeve (dedektör varsayımı)
  const lookback = Duration(minutes: 5); // 6000 çerçeve

  bool recent(List<AcousticEvent> events, int currentFrame) => hasRecentActivity(
        events: events,
        currentFrame: currentFrame,
        lookback: lookback,
        frameDuration: frame,
      );

  test('olay yoksa aktivite yok', () {
    expect(recent([], 10000), isFalse);
  });

  test('pencere İÇİNDEKİ olay → aktivite var', () {
    expect(recent([event(start: 9000)], 10000), isTrue);
  });

  test('ESKİ olay → aktivite YOK (5 dk önce dönmüş olması şimdi uyandırmaz)', () {
    // 10000 - 6000 = 4000 eşiği; 1000'de biten olay çok eski.
    expect(recent([event(start: 1000)], 10000), isFalse);
  });

  test('SÜREGELEN uzun olay sayılır (geçmişte başlamış olabilir)', () {
    // Horlama 5 dk önce başladı ve HÂLÂ sürüyor: yalnızca başlangıcına baksaydık
    // "şu an ses var" durumunu kaçırırdık.
    expect(recent([event(start: 1000, duration: 9000)], 10000), isTrue);
  });

  test('sınır: tam eşikte biten olay sayılır', () {
    expect(recent([event(start: 3995, duration: 5)], 10000), isTrue);
  });

  test('çok küçük lookback bile en az 1 çerçeve bakar (sessizce hep-false olmaz)', () {
    expect(
      hasRecentActivity(
        events: [event(start: 9999, duration: 1)],
        currentFrame: 10000,
        lookback: Duration.zero,
        frameDuration: frame,
      ),
      isTrue,
    );
  });

  test('UÇTAN UCA: sessiz gece → alarm SON TARİHTE çalar', () {
    // Hiç olay yok: "akıllı" kısım hiç tetiklenmez ama alarm sözünü tutar.
    final start = DateTime(2026, 7, 16, 6, 30);
    final end = DateTime(2026, 7, 16, 7, 0);
    final alarm = SmartAlarm(windowStart: start, windowEnd: end);

    final d1 = alarm.evaluate(
      now: DateTime(2026, 7, 16, 6, 45),
      hasRecentActivity: recent([], 10000),
    );
    expect(d1.shouldFire, isFalse);

    final d2 = alarm.evaluate(now: end, hasRecentActivity: recent([], 12000));
    expect(d2.shouldFire, isTrue);
    expect(d2.trigger, AlarmTrigger.deadline);
  });

  test('UÇTAN UCA: pencere içinde hareket → alarm lightSleep ile çalar', () {
    final alarm = SmartAlarm(
      windowStart: DateTime(2026, 7, 16, 6, 30),
      windowEnd: DateTime(2026, 7, 16, 7, 0),
    );

    final d = alarm.evaluate(
      now: DateTime(2026, 7, 16, 6, 45),
      hasRecentActivity: recent([event(start: 9500)], 10000),
    );
    expect(d.shouldFire, isTrue);
    expect(d.trigger, AlarmTrigger.lightSleep);
  });
}
