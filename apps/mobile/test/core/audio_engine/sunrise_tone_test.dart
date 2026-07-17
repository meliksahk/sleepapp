import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:nocta/core/audio_engine/dsp/sunrise_tone.dart';

/// Alarm sesi (docs/04 §86 "sunrise rampası").
///
/// **DÜRÜSTLÜK SINIRI:** burada kanıtlanan şey sesin GÜZEL olduğu değil — o insan
/// yargısı (CLAUDE.md §1.1, kulaklıkla). Kanıtlanan: sinyal kırpılmıyor, rampa
/// gerçekten yükseliyor ve ses gerçekten VAR (sessiz bir alarm en kötü hata olurdu).
void main() {
  double peakIn(List<double> s) =>
      s.fold(0.0, (m, v) => math.max(m, v.abs()));

  group('sinyal sağlığı', () {
    test('ÇEKİRDEK: ses VAR — alarm sessiz değil', () {
      final t = sunriseTone(seconds: 60, sampleRate: 8000);
      // Sessiz bir alarm, çalmayan bir alarmdır.
      expect(peakIn(t), greaterThan(0.1));
    });

    test('ÇEKİRDEK: kırpma YOK ([-1,1] içinde)', () {
      final t = sunriseTone(seconds: 60, sampleRate: 8000);
      expect(peakIn(t), lessThanOrEqualTo(1.0));
      // Kırpma sert bir distorsiyon üretirdi — "nazik uyandırma"nın tam tersi.
      expect(peakIn(t), lessThan(0.95));
    });

    test('NaN/sonsuz üretmez', () {
      final t = sunriseTone(seconds: 5, sampleRate: 8000);
      expect(t.every((v) => v.isFinite), isTrue);
    });

    test('uzunluk = saniye × sampleRate', () {
      expect(sunriseTone(seconds: 3, sampleRate: 8000).length, 24000);
    });
  });

  group('rampa', () {
    test('ÇEKİRDEK: başta KISIK, sonra yüksek', () {
      final t = sunriseTone(seconds: 60, sampleRate: 8000, rampSeconds: 30);
      final first = peakIn(t.sublist(0, 8000)); // 0–1 sn
      final late = peakIn(t.sublist(8000 * 40, 8000 * 41)); // 40–41 sn

      // Alarm ilk saniyede tam sesle patlarsa "akıllı" kısım anlamsızlaşır.
      expect(first, lessThan(late * 0.2));
    });

    test('rampa bitince seviye SABİT kalır — döngü başa sarınca kısılmaz', () {
      final t = sunriseTone(seconds: 60, sampleRate: 8000, rampSeconds: 30);
      // İki ölçüm de ÇAN BAŞLANGICINA hizalı (çan aralığı 2 sn → çift saniyeler).
      // Hizalamazsak çanın sönmüş kuyruğunu vuruşuyla kıyaslarız ve test, rampa
      // kusursuz olsa bile kırmızı yanar — ilk hâli tam bunu yapıyordu.
      final at40 = peakIn(t.sublist(8000 * 40, 8000 * 40 + 400));
      final at56 = peakIn(t.sublist(8000 * 56, 8000 * 56 + 400));
      // Rampa yeniden başlasaydı alarm her dakika kısılır ve uyandırmayı bırakırdı.
      expect(at56, closeTo(at40, 0.02));
    });

    test('rampSeconds: 0 → ilk örnekten tam seviye (sıfıra bölme yok)', () {
      final t = sunriseTone(seconds: 5, sampleRate: 8000, rampSeconds: 0);
      expect(peakIn(t.sublist(0, 800)), greaterThan(0.1));
    });
  });

  test('çan tekrar eder — tek bir tık değil, ısrarcı', () {
    final t = sunriseTone(seconds: 10, sampleRate: 8000, rampSeconds: 0);
    // Çan aralığı 2 sn: her aralığın başında yeni bir vuruş olmalı.
    final firstHit = peakIn(t.sublist(0, 400));
    final secondHit = peakIn(t.sublist(8000 * 2, 8000 * 2 + 400));
    expect(secondHit, closeTo(firstHit, 0.05));

    // ...ve vuruşlar arasında sönmeli (sürekli uğultu değil).
    final between = peakIn(t.sublist(8000 * 1 + 4000, 8000 * 2 - 400));
    expect(between, lessThan(firstHit * 0.2));
  });
}
