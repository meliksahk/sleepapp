import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nocta/core/sleep_tracking/db_envelope.dart';
import 'package:nocta/core/sleep_tracking/event_detector.dart';

/// Uyku takibi: dB zarfı + olay tespiti.
///
/// docs/04 §120 çıkış kriteri: "kayıtlı/SİMÜLE mikrofon beslemeleriyle mantıklı
/// rapor üretimi testle kanıtlı". Gerçek gece doğrulaması docs/10'da (insan-kapılı);
/// burada sentetik beslemeyle MANTIK kanıtlanıyor.
void main() {
  /// Bu dosyadaki testler çerçeve SAYISI üzerinden yazıldı ve yorumları
  /// "~50 ms/çerçeve" varsayıyor. 50 ms verildiğinde varsayılan süreler tam olarak
  /// eski çerçeve sabitlerine denk geliyor (100 ms/50 = 2, 5 sn/50 ms = 100,
  /// 500 ms/50 ms = 10, 50/2500 = 0.02) — yani bu sabit, testlerin anlamını
  /// korumakla kalmıyor, süre→çerçeve çevriminin doğruluğunu da kanıtlıyor.
  const testFrame = Duration(milliseconds: 50);

  /// Verilen dB dizisini dedektörden geçirir.
  List<AcousticEvent> run(List<double> dbFrames, {AcousticEventDetector? det}) {
    final d = det ??
        AcousticEventDetector(frameDuration: testFrame, initialFloorDb: -60);
    for (final db in dbFrames) {
      d.addFrame(db);
    }
    d.finish();
    return d.events;
  }

  /// n çerçeve sabit seviye.
  List<double> level(double db, int n) => List.filled(n, db);

  group('frameDbfs', () {
    test('tam sessizlik → taban (−inf değil: aritmetiği zehirlerdi)', () {
      expect(frameDbfs(Float32List.fromList([0, 0, 0, 0])), silenceDbfs);
      expect(frameDbfs(Float32List(0)), silenceDbfs);
    });

    test('tam ölçek RMS → 0 dBFS', () {
      expect(frameDbfs(Float32List.fromList([1, -1, 1, -1])), closeTo(0, 0.001));
    });

    test('yarım genlik → ≈ −6 dBFS (logaritmik ölçek doğru)', () {
      expect(frameDbfs(Float32List.fromList([0.5, -0.5, 0.5, -0.5])), closeTo(-6.02, 0.05));
    });

    test('daha yüksek sinyal daha yüksek dB verir (monotonluk)', () {
      final quiet = frameDbfs(Float32List.fromList([0.01, -0.01]));
      final loud = frameDbfs(Float32List.fromList([0.1, -0.1]));
      expect(loud, greaterThan(quiet));
    });

    test('çok küçük ama sıfır olmayan sinyal tabanın altına DÜŞMEZ', () {
      expect(frameDbfs(Float32List.fromList([1e-12, -1e-12])), silenceDbfs);
    });
  });

  group('olay tespiti', () {
    test('sessiz gece → 0 olay', () {
      expect(run(level(-60, 500)), isEmpty);
    });

    test('tek patlama → 1 olay', () {
      final events = run([...level(-60, 50), ...level(-30, 5), ...level(-60, 50)]);
      expect(events, hasLength(1));
      expect(events.single.peakDb, closeTo(-30, 0.001));
    });

    test('UZUN patlama TEK olaydır (N olaya bölünmez)', () {
      // Taban olay boyunca dondurulmasaydı horlama kendi tabanını yukarı çeker ve
      // "bitmiş" görünürdü → tek horlama 40 küçük olay olurdu.
      // 60 çerçeve ≈ 3 sn (~50 ms/çerçeve): gerçekçi bir horlama.
      final events = run([...level(-60, 30), ...level(-25, 60), ...level(-60, 30)]);
      expect(events, hasLength(1));
      expect(events.single.durationFrames, 60);
    });

    test('SEVİYE KAYMASI olay değildir: sürekli ses maxEventFrames sınırında kesilir', () {
      // İlk yazımda taban olay boyunca SONSUZA KADAR donduruluyordu → fan bitmeyen
      // tek olay oluyor ve taban bir daha hiç uyum sağlamıyordu (test yakaladı).
      // Ayrım: kısa aşım OLAY, sürekli aşım SEVİYE KAYMASI.
      final d = AcousticEventDetector(
        frameDuration: testFrame,
        initialFloorDb: -60,
        maxEventDuration: const Duration(seconds: 5), // 50 ms'de = 100 çerçeve
      );
      run([...level(-60, 30), ...level(-25, 500)], det: d);

      expect(d.events, hasLength(1));
      expect(d.events.single.durationFrames, 100); // olay kesildi
      expect(d.floorDb, closeTo(-25, 1)); // taban yeni seviyeye SIÇRADI
    });

    test('iki ayrı patlama → 2 olay (refrakter aşıldıysa)', () {
      final events = run([
        ...level(-60, 30),
        ...level(-30, 5),
        ...level(-60, 40), // refrakter (10) çoktan geçti
        ...level(-30, 5),
        ...level(-60, 30),
      ]);
      expect(events, hasLength(2));
    });

    test('REFRAKTER: hemen ardışık salınım TEK olay sayılır', () {
      // Tek bir dönme-hareketi genlikte birkaç kez salınır; refrakter olmadan
      // tek hareket 3-4 kez sayılırdı.
      final events = run([
        ...level(-60, 30),
        ...level(-30, 3),
        ...level(-60, 2), // refrakter içinde
        ...level(-30, 3),
        ...level(-60, 2),
        ...level(-30, 3),
        ...level(-60, 40),
      ]);
      expect(events, hasLength(1));
    });

    test('ÇOK KISA aşım olay DEĞİL (tek örneklik tıklama/parazit)', () {
      final events = run([...level(-60, 50), -20, ...level(-60, 50)]);
      expect(events, isEmpty);
    });

    test('ÇEKİRDEK: FAN AÇILINCA sonsuz olay ÜRETMEZ (uyarlanabilir taban)', () {
      // Sabit eşikli bir dedektör burada YÜZLERCE olay üretirdi ve rapor
      // "312 hareket" derdi — kullanıcı da haklı olarak uygulamayı silerdi.
      final events = run([
        ...level(-60, 100), // sessiz oda
        ...level(-35, 1000), // fan açıldı: taban kalıcı olarak yükseldi
      ]);
      // Fanın AÇILMA ANI bir olaydır (gerçekten bir şey oldu); ama süregelen
      // uğultu değil.
      expect(events.length, lessThanOrEqualTo(1));
    });

    test('taban yükseldikten SONRA aynı mutlak seviye artık olay değil', () {
      final d = AcousticEventDetector(frameDuration: testFrame, initialFloorDb: -60);
      run([...level(-60, 50), ...level(-35, 1000)], det: d);
      final afterFan = d.events.length;

      // Fan uğultusu seviyesinde bir ses artık "normal" — olay eklenmemeli.
      for (final db in level(-35, 200)) {
        d.addFrame(db);
      }
      d.finish();
      expect(d.events.length, afterFan);
      expect(d.floorDb, greaterThan(-45)); // taban gerçekten uyum sağladı
    });

    test('taban yükselse bile DAHA YÜKSEK ses hâlâ olaydır (duyarlılık kaybolmaz)', () {
      // Uyarlanabilir taban "artık hiçbir şey duymuyorum" demek olmamalı.
      final d = AcousticEventDetector(frameDuration: testFrame, initialFloorDb: -60);
      run([...level(-60, 50), ...level(-35, 1000)], det: d);
      final before = d.events.length;

      for (final db in [...level(-10, 5), ...level(-35, 30)]) {
        d.addFrame(db);
      }
      d.finish();
      expect(d.events.length, before + 1);
    });

    test('AKIŞ SONUNDA süren olay kaybolmaz (gecenin son sesi)', () {
      // finish() olmasaydı çalar saatle uyanma raporda hiç görünmezdi.
      final events = run([...level(-60, 50), ...level(-25, 20)]);
      expect(events, hasLength(1));
      expect(events.single.durationFrames, 20);
    });

    test('olay tabanına GÖRE kaydedilir (prominence anlamlı)', () {
      final events = run([...level(-60, 50), ...level(-30, 5), ...level(-60, 20)]);
      expect(events.single.floorDb, closeTo(-60, 1));
      expect(events.single.prominenceDb, closeTo(30, 1));
    });

    test('gerçekçi zincir: PCM → dB → olay (uçtan uca)', () {
      // Ayrıştırılmış zincirin birleştiği yer: sentetik PCM'den olay sayısı.
      Float32List tone(double amp, int n) {
        final f = Float32List(n);
        for (var i = 0; i < n; i++) {
          f[i] = amp * math.sin(2 * math.pi * i / 16);
        }
        return f;
      }

      final d = AcousticEventDetector(frameDuration: testFrame, initialFloorDb: -60);
      for (var i = 0; i < 60; i++) {
        d.addFrame(frameDbfs(tone(0.001, 64))); // sessiz oda
      }
      for (var i = 0; i < 8; i++) {
        d.addFrame(frameDbfs(tone(0.3, 64))); // horlama benzeri
      }
      for (var i = 0; i < 30; i++) {
        d.addFrame(frameDbfs(tone(0.001, 64)));
      }
      d.finish();

      expect(d.events, hasLength(1));
      expect(d.events.single.prominenceDb, greaterThan(12));
    });
  });

  group('GERÇEK boru hattı hızı (16 kHz / 256 örnek = 16 ms/çerçeve)', () {
    // Üretimdeki gerçek çerçeve süresi. Ayarlar çerçeve SAYISI olduğu sürece bu
    // değer sessizce yanlış davranış üretiyordu (2026-08-03 zarf kaydı ortaya
    // çıkardı): tüm süreler 3.1× kısaydı.
    const realFrame = Duration(microseconds: 16000);

    test('süreler çerçeveye DOĞRU çevrilir (eski sabitler 3.1× kısaydı)', () {
      final d = AcousticEventDetector(frameDuration: realFrame, initialFloorDb: -60);
      // 5 sn / 16 ms = 312.5 → 313. Eski kod burada 100 kullanıyordu (= 1.6 sn).
      expect(d.maxEventFrames, 313);
      expect(d.refractoryFrames, 31); // 500 ms, eskiden 10 (= 160 ms)
      expect(d.minDurationFrames, 6); // 100 ms, eskiden 2 (= 32 ms)
      expect(d.floorAttack, closeTo(0.0064, 0.0001)); // τ=2.5 sn, eskiden 0.02 (τ=0.8 sn)
    });

    test('REGRESYON: 3 saniyelik horlama SEVİYE KAYMASI sayılmaz', () {
      // HATA: maxEventFrames=100 çerçeve sabiti 16 ms'de 1.6 sn eder. Horlama
      // 2-3 sn sürdüğü için tavanı aşıyor, "seviye kayması" sayılıyor ve taban
      // horlamanın seviyesine SIÇRIYORDU — yani dedektör horlamayı odanın yeni
      // normali ilan ediyordu. Sınıf yorumunun önlemek için yazıldığı davranışın
      // ta kendisi.
      final d = AcousticEventDetector(frameDuration: realFrame, initialFloorDb: -60);
      // 3 sn horlama = 3000/16 ≈ 188 çerçeve.
      for (final db in [...level(-60, 100), ...level(-25, 188), ...level(-60, 100)]) {
        d.addFrame(db);
      }
      d.finish();

      expect(d.events, hasLength(1));
      expect(d.events.single.durationFrames, 188); // kesilmedi
      // Asıl kanıt: taban horlamaya YAPIŞMADI, oda tabanında kaldı.
      expect(d.floorDb, lessThan(-50));
    });
  });
}
