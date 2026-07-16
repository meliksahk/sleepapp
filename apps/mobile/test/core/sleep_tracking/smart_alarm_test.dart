import 'package:flutter_test/flutter_test.dart';
import 'package:nocta/core/sleep_tracking/smart_alarm.dart';

/// Akıllı alarm penceresi (docs/04 §86, §120: "alarm penceresi mantığı unit+integration
/// testli").
///
/// Bu dosyadaki en önemli testler SON TARİH testleridir: "akıllı" kısım bir
/// optimizasyondur, alarmın kendisi bir SÖZDÜR. Sinyal beklerken sessiz kalmak
/// kullanıcının işe geç kalması demektir.
void main() {
  // 06:30–07:00 penceresi (docs/04 §86'daki örnek).
  final start = DateTime(2026, 7, 16, 6, 30);
  final end = DateTime(2026, 7, 16, 7, 0);

  SmartAlarm alarm() => SmartAlarm(windowStart: start, windowEnd: end);

  group('pencere ÖNCESİ', () {
    test('aktivite olsa BİLE çalmaz (sözden erken uyandırmak)', () {
      final a = alarm();
      final d = a.evaluate(now: DateTime(2026, 7, 16, 5, 0), hasRecentActivity: true);
      expect(d.shouldFire, isFalse);
      expect(a.hasFired, isFalse);
    });

    test('pencere başlangıcının 1 dakika öncesi hâlâ erken', () {
      final d = alarm().evaluate(now: DateTime(2026, 7, 16, 6, 29), hasRecentActivity: true);
      expect(d.shouldFire, isFalse);
    });
  });

  group('pencere İÇİ', () {
    test('aktivite yoksa bekler (hafif uyku aranıyor)', () {
      final d = alarm().evaluate(now: DateTime(2026, 7, 16, 6, 40), hasRecentActivity: false);
      expect(d.shouldFire, isFalse);
    });

    test('aktivite varsa ÇALAR (lightSleep)', () {
      final d = alarm().evaluate(now: DateTime(2026, 7, 16, 6, 40), hasRecentActivity: true);
      expect(d.shouldFire, isTrue);
      expect(d.trigger, AlarmTrigger.lightSleep);
    });

    test('pencere başlangıcı DAHİLDİR (sınır)', () {
      final d = alarm().evaluate(now: start, hasRecentActivity: true);
      expect(d.shouldFire, isTrue);
      expect(d.trigger, AlarmTrigger.lightSleep);
    });
  });

  group('SON TARİH — pazarlıksız', () {
    test('ÇEKİRDEK: hafif uyku HİÇ görülmese de pencere sonunda ÇALAR', () {
      // Bu sınıftaki tek gerçekten tehlikeli hata: sinyal beklerken sessiz kalmak.
      // Kullanıcı işe geç kalır ve uygulamaya bir daha güvenmez.
      final a = alarm();
      for (var m = 30; m < 60; m++) {
        final d = a.evaluate(now: DateTime(2026, 7, 16, 6, m), hasRecentActivity: false);
        expect(d.shouldFire, isFalse, reason: '06:$m henüz son tarih değil');
      }
      final d = a.evaluate(now: end, hasRecentActivity: false);
      expect(d.shouldFire, isTrue);
      expect(d.trigger, AlarmTrigger.deadline);
    });

    test('pencere sonu DAHİLDİR (07:00 son tarihtir, 07:01 değil)', () {
      final d = alarm().evaluate(now: end, hasRecentActivity: false);
      expect(d.shouldFire, isTrue);
    });

    test('son tarih GEÇTİYSE de çalar (tick kaçtıysa sessiz kalmaz)', () {
      // Uygulama askıya alınıp 07:00 tick'i kaçarsa alarm KAYBOLMAMALI.
      final d = alarm().evaluate(now: DateTime(2026, 7, 16, 7, 15), hasRecentActivity: false);
      expect(d.shouldFire, isTrue);
      expect(d.trigger, AlarmTrigger.deadline);
    });

    test('sıfır uzunlukta pencere → anında son tarih (kilitlenmez)', () {
      final a = SmartAlarm(windowStart: start, windowEnd: start);
      final d = a.evaluate(now: start, hasRecentActivity: false);
      expect(d.shouldFire, isTrue);
      expect(d.trigger, AlarmTrigger.deadline);
    });
  });

  group('BİR KEZ çalar', () {
    test('lightSleep sonrası tekrar çalmaz', () {
      // Aksi halde çağıran her tick'te yeniden bildirim gönderirdi.
      final a = alarm();
      expect(
        a.evaluate(now: DateTime(2026, 7, 16, 6, 40), hasRecentActivity: true).shouldFire,
        isTrue,
      );
      expect(
        a.evaluate(now: DateTime(2026, 7, 16, 6, 41), hasRecentActivity: true).shouldFire,
        isFalse,
      );
      expect(a.hasFired, isTrue);
    });

    test('lightSleep ile çaldıysa SON TARİHTE tekrar çalmaz', () {
      final a = alarm();
      a.evaluate(now: DateTime(2026, 7, 16, 6, 35), hasRecentActivity: true);
      final d = a.evaluate(now: DateTime(2026, 7, 16, 7, 30), hasRecentActivity: false);
      expect(d.shouldFire, isFalse);
    });

    test('son tarihte çaldıysa tekrar çalmaz', () {
      final a = alarm();
      a.evaluate(now: end, hasRecentActivity: false);
      expect(a.evaluate(now: end, hasRecentActivity: true).shouldFire, isFalse);
    });
  });

  test('gerçekçi gece: 23:00 uyku → 06:45 hareket → alarm 06:45', () {
    final a = alarm();
    // Gece boyunca sessizlik (aktivite yok, pencere de kapalı).
    for (final h in [23, 0, 2, 4, 6]) {
      final now = DateTime(2026, 7, h >= 23 ? 15 : 16, h, 0);
      expect(a.evaluate(now: now, hasRecentActivity: false).shouldFire, isFalse);
    }
    // Pencere açıldı, hâlâ derin uyku.
    expect(
      a.evaluate(now: DateTime(2026, 7, 16, 6, 35), hasRecentActivity: false).shouldFire,
      isFalse,
    );
    // 06:45'te dönüp duruyor → hafif uyku → uyandır.
    final d = a.evaluate(now: DateTime(2026, 7, 16, 6, 45), hasRecentActivity: true);
    expect(d.shouldFire, isTrue);
    expect(d.trigger, AlarmTrigger.lightSleep);
  });

  test('pencere sonu başlangıçtan önce olamaz (assert)', () {
    expect(
      () => SmartAlarm(windowStart: end, windowEnd: start),
      throwsA(isA<AssertionError>()),
    );
  });
}
