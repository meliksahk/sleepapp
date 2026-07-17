import 'package:flutter_test/flutter_test.dart';
import 'package:nocta/core/sleep_tracking/envelope_log.dart';

/// Gece dB zarfı — eşik ayarı fixture'ı (docs/04 §120).
///
/// **Bu dosyanın varlık sebebi:** `AcousticEventDetector`'ın eşikleri gerçek gece
/// kayıtlarıyla ayarlanmadı ve ayarlanamıyordu, çünkü kayıt bittiğinde geriye
/// yalnızca bir SAYI kalıyordu ("12 olay"). O sayı, eşiğin doğru olup olmadığını
/// söylemez. Zarf, ayarlamayı mümkün kılan veridir.
void main() {
  EnvelopeLog log({int sampleRate = 1000, int frameSamples = 100}) =>
      EnvelopeLog(sampleRate: sampleRate, frameSamples: frameSamples);

  test('saniyede kaç çerçeve — 16 kHz / 256 örnek ≈ 62.5', () {
    final l = EnvelopeLog(sampleRate: 16000, frameSamples: 256);
    expect(l.framesPerSecond, closeTo(62.5, 0.01));
  });

  test('ÇEKİRDEK: çerçeveler SANİYELİK kovalara toplanır', () {
    // 10 çerçeve/sn → ilk 10 çerçeve saniye 0, sonraki 10 saniye 1.
    final l = log();
    for (var i = 0; i < 20; i++) {
      l.addFrame(-60);
    }
    l.finish();

    expect(l.seconds.length, 2);
    expect(l.seconds[0].second, 0);
    expect(l.seconds[1].second, 1);
    expect(l.seconds[0].frames, 10);
  });

  test('ÇEKİRDEK: min/ortalama/maks AYRI — olay ortalamada kaybolmasın', () {
    // Sessiz taban + tek bir yüksek olay. Yalnızca ortalama tutsaydık olay
    // görünmez olurdu ve eşik ayarı imkânsızlaşırdı.
    final l = log();
    for (var i = 0; i < 9; i++) {
      l.addFrame(-60);
    }
    l.addFrame(-10); // olay
    l.finish();

    final s = l.seconds.single;
    expect(s.minDb, -60, reason: 'taban görünmeli');
    expect(s.maxDb, -10, reason: 'olay görünmeli');
    expect(s.meanDb, closeTo(-55, 0.1), reason: 'ortalama ikisinin arası');
  });

  test('yarım kalan saniye finish() ile KAPATILIR (veri kaybolmasın)', () {
    final l = log();
    for (var i = 0; i < 5; i++) {
      l.addFrame(-50); // saniyenin yarısı
    }
    expect(l.seconds, isEmpty, reason: 'kova henüz kapanmadı');

    l.finish();
    expect(l.seconds.length, 1);
    expect(l.seconds.single.frames, 5);
  });

  test('hiç çerçeve gelmezse finish() çökmez', () {
    final l = log();
    l.finish();
    expect(l.seconds, isEmpty);
  });

  group('CSV', () {
    test('başlık + veri satırları', () {
      final l = log();
      for (var i = 0; i < 10; i++) {
        l.addFrame(-42.5);
      }
      l.finish();

      final csv = l.toCsv();
      expect(csv, contains('second,minDb,meanDb,maxDb,frames'));
      expect(csv, contains('0,-42.50,-42.50,-42.50,10'));
    });

    test('ÇEKİRDEK: CSV başlığı ham ses OLMADIĞINI açıkça yazar', () {
      // Fixture paylaşılacak bir dosya; ne olduğu dosyanın İÇİNDE yazmalı.
      final csv = log().toCsv();
      expect(csv, contains('HAM SES DEĞİL'));
      expect(csv, contains('konuşma geri getirilemez'));
    });

    test('örnekleme bilgisi CSV\'de (fixture tek başına anlamlı olsun)', () {
      final csv = EnvelopeLog(sampleRate: 16000, frameSamples: 256).toCsv();
      expect(csv, contains('sampleRate=16000'));
      expect(csv, contains('frameSamples=256'));
    });
  });

  group('bellek tavanı', () {
    test('ÇEKİRDEK: tavan aşılırsa SESSİZCE kırpılmaz, CSV\'de UYARI çıkar', () {
      // Sessiz kırpma = eksik fixture = yanlış eşik. Bu proje sessiz sınırları
      // #101/#102'de bir kez kapattı; aynı hatayı burada yapmıyoruz.
      final l = log();
      for (var i = 0; i < (EnvelopeLog.maxSeconds + 5) * 10; i++) {
        l.addFrame(-60);
      }
      l.finish();

      expect(l.truncated, isTrue);
      expect(l.toCsv(), contains('UYARI'));
      expect(l.seconds.length, EnvelopeLog.maxSeconds);
    });

    test('normal gece tavana YAKLAŞMAZ (8 saat < 10 saat tavanı)', () {
      // 8 saat = 28.800 sn; tavan 36.000. Uyuyakalan kullanıcı bile güvende.
      expect(EnvelopeLog.maxSeconds, greaterThan(8 * 3600));
    });
  });
}
