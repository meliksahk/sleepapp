import 'package:flutter_test/flutter_test.dart';
import 'package:nocta/core/audio_engine/dsp/nocta_signature.dart';
import 'package:nocta/core/launch/launch_phase.dart';

/// Açılış animasyonunun **sesle aynı matematikten** beslendiğini kanıtlar.
///
/// Bu dosyanın varlık nedeni tek bir regresyon: birinin zarfı animasyon tarafına
/// KOPYALAMASI. Kopya olduğu gün ses değişir, görsel eski eğride kalır ve iki
/// taraf da kendi testini geçmeye devam eder — kimse fark etmez. Aşağıdaki
/// testler değeri değil, KAYNAK BİRLİĞİNİ ölçer.
void main() {
  Duration secs(double s) => Duration(microseconds: (s * 1e6).round());

  test('ÇEKİRDEK: parlaklık, sesin zarfıyla BİREBİR aynı (kopya değil)', () {
    for (final t in <double>[0.0, 0.1, 0.3, 0.6, 1.0, 2.2, 3.0, 3.59, 3.6]) {
      expect(
        launchPhaseAt(secs(t)).glow,
        signatureEnvelopeAt(t),
        reason: 't=$t için görsel ve ses zarfı ayrışmış',
      );
    }
  });

  test('ÇEKİRDEK: açılma eğrisi de sesin tiltiyle aynı', () {
    for (final t in <double>[0.0, 0.4, 0.8, 1.6, 2.4]) {
      expect(launchPhaseAt(secs(t)).open, signatureTiltAt(t));
    }
  });

  test('zarf yönü doğru: sessizde ölü, attack sonunda tepe, sonda sönmüş', () {
    expect(launchPhaseAt(Duration.zero).glow, 0.0);
    // Attack (0.60 sn) sonunda tam parlaklık.
    expect(launchPhaseAt(secs(signatureAttackSeconds)).glow, closeTo(1.0, 1e-9));
    // Sesin bittiği anda görsel de dinginleşmiş olmalı.
    expect(launchPhaseAt(secs(signatureSeconds)).glow, 0.0);
    // Yükseliş monoton.
    expect(launchPhaseAt(secs(0.2)).glow, lessThan(launchPhaseAt(secs(0.4)).glow));
  });

  test('ÇEKİRDEK: yıldızlar sesin parıltı TANELERİYLE aynı anda parlar', () {
    final grains = launchGrains;
    expect(grains, isNotEmpty, reason: 'imza parıltısız kalmış olamaz');
    expect(grains.length, launchPhaseAt(Duration.zero).sparkles.length);

    for (var i = 0; i < grains.length; i++) {
      final onset = grains[i].onset;
      // Tanenin doğuşundan HEMEN ÖNCE karanlık.
      expect(launchPhaseAt(secs(onset - 0.02)).sparkles[i], 0.0);
      // Görsel yükseliş sabiti (0.08 sn) sonrasında belirgin parlaklık.
      final peak = launchPhaseAt(secs(onset + launchSparkleAttack)).sparkles[i];
      expect(peak, greaterThan(0.15), reason: '$i. yıldız hiç parlamıyor');
      // Ve sesle aynı zaman sabitiyle söner.
      final later = launchPhaseAt(secs(onset + 4 * signatureGrainDecay + 0.01)).sparkles[i];
      expect(later, 0.0);
      expect(
        launchPhaseAt(secs(onset + 1.2 * signatureGrainDecay)).sparkles[i],
        lessThan(peak),
      );
    }
  });

  test('yıldız parlaklığı sesteki sqrt(8/m) kazanç yasasını izler', () {
    // Aynı anda değil ama aynı KURALLA: pes tane (küçük m) daha parlak.
    final grains = launchGrains;
    final byMultiple = <int, double>{};
    for (var i = 0; i < grains.length; i++) {
      final v = launchPhaseAt(secs(grains[i].onset + launchSparkleAttack)).sparkles[i];
      byMultiple[grains[i].multiple] = v / grains[i].amp;
    }
    final keys = byMultiple.keys.toList()..sort();
    for (var i = 1; i < keys.length; i++) {
      expect(
        byMultiple[keys[i]]!,
        lessThanOrEqualTo(byMultiple[keys[i - 1]]! + 1e-9),
        reason: 'tiz tane pesten parlak çıkmış (kazanç yasası bozuk)',
      );
    }
  });

  test('süre sözleşmesi: alt sınır < üst sınır < sesin kendisi', () {
    expect(launchHoldSeconds, lessThan(launchCapSeconds));
    // Üst sınır sesin uzunluğunu AŞMAMALI: aşsaydı kullanıcı, biten bir sesin
    // sessizliğinde ekrana bakıyor olurdu.
    expect(launchCapSeconds, lessThan(signatureSeconds));
    // Alt sınır, zarfın tepesini ve ilk parıltıyı kapsamalı.
    expect(launchHoldSeconds, greaterThan(signatureAttackSeconds));
    expect(launchHoldSeconds, greaterThan(launchGrains.first.onset));
    // Mikroanimasyon gerçekten "mikro" (250–400 ms).
    expect(launchExitDuration.inMilliseconds, inInclusiveRange(250, 400));
  });
}
