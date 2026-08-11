import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nocta/core/audio_engine/dsp/generative_chain.dart';
import 'package:nocta/core/audio_engine/dsp/mix_render.dart';

/// **F2 — sonsuz jeneratif uzatma.** Ürünün asıl iddiası burada ölçülüyor:
/// ses TEKRAR ETMİYOR ve tekrar etmemesinin bedeli bir tık/çukur DEĞİL.
///
/// Kulakla doğrulama ayrı bir iş (gerçek cihaz + kulaklık, CLAUDE.md §1.1) —
/// bu testler onun yerine geçmez, ama sessizce bozulmayı imkânsız kılar.
void main() {
  const sampleRate = 8000; // test hızı; oran-bağımsız büyüklükler ölçülüyor
  const seconds = 2;

  LayerSegmentChain chain(LayerSource type, {int seed = 11}) =>
      LayerSegmentChain(
        type: type,
        seed: seed,
        segmentSeconds: seconds,
        sampleRate: sampleRate,
      );

  double mean(List<double> xs) {
    if (xs.isEmpty) return 0;
    var sum = 0.0;
    for (final v in xs) {
      sum += v;
    }
    return sum / xs.length;
  }

  double rms(List<double> xs) {
    if (xs.isEmpty) return 0;
    var sum = 0.0;
    for (final v in xs) {
      sum += v * v;
    }
    return math.sqrt(sum / xs.length);
  }

  /// Ardışık örnek farklarının p99'u — sinyalin "normal" sıçrama ölçeği.
  double p99Delta(Float32List b) {
    final deltas = <double>[
      for (var i = 1; i < b.length; i++) (b[i] - b[i - 1]).abs(),
    ]..sort();
    return deltas[(deltas.length * 0.99).floor()];
  }

  group('tekrar YOK', () {
    test('ÇEKİRDEK: ardışık segmentler birbirinin kopyası değil', () {
      for (final type in LayerSource.values) {
        final c = chain(type);
        final a = c.next();
        final b = c.next();

        var identical = true;
        for (var i = 0; i < a.length; i++) {
          if (a[i] != b[i]) {
            identical = false;
            break;
          }
        }
        expect(
          identical,
          isFalse,
          reason: '$type: ikinci segment birincinin kopyası — bu DÖNGÜ, zincir değil',
        );
      }
    });

    test('ÇEKİRDEK: gövdeler İLİŞKİSİZ — pad dahil (ölçülen bir hataydı)', () {
      // Harman bölgesinin DIŞINDA korelasyon ~0 olmalı. Pad'de bu test önce
      // 1.000 ölçtü: tonal yatak tohumdan bağımsızdı, yani pad HER SEGMENTTE
      // birebir aynı çalıyordu ve "tekrar etmeyen ses" iddiası pad katmanında
      // yanlıştı. Akor havuzu (padVariantRatios) tam olarak bunu düzeltiyor.
      for (final type in LayerSource.values) {
        final c = chain(type);
        final a = c.next();
        final b = c.next();
        final start = sampleRate; // dikişten 1 sn sonra
        // Ortalama ÇIKARILIR: pembe/kahverengi gürültüde sıfır olmayan bir DC
        // bileşeni korelasyonu yapay olarak yukarı çeker.
        final ma = mean(a.sublist(start));
        final mb = mean(b.sublist(start));
        var dot = 0.0;
        for (var i = start; i < a.length; i++) {
          dot += (a[i] - ma) * (b[i] - mb);
        }
        final corr = dot /
            (a.length - start) /
            (rms(<double>[for (var i = start; i < a.length; i++) a[i] - ma]) *
                rms(<double>[for (var i = start; i < b.length; i++) b[i] - mb]));
        expect(
          corr.abs(),
          lessThan(0.5),
          reason: '$type: gövdeler korelasyonlu (${corr.toStringAsFixed(3)}) — '
              'segment bir öncekini tekrar ediyor',
        );
      }
    });

    test('aynı tohum aynı akışı verir (teşhis edilebilirlik)', () {
      final a = chain(LayerSource.brown, seed: 5);
      final b = chain(LayerSource.brown, seed: 5);
      a.next();
      b.next();
      final a2 = a.next();
      final b2 = b.next();
      expect(a2, orderedEquals(b2));
    });

    test('farklı tohum farklı akış (iki kullanıcı aynı geceyi duymaz)', () {
      final a = chain(LayerSource.rain, seed: 5).next();
      final b = chain(LayerSource.rain, seed: 6).next();
      expect(a, isNot(orderedEquals(b)));
    });
  });

  group('dikiş', () {
    test('ÇEKİRDEK: segment sınırında TIK yok (sıçrama sinyalin ölçeğinde)', () {
      for (final type in LayerSource.values) {
        final c = chain(type);
        final a = c.next();
        final b = c.next();

        final seamJump = (b[0] - a[a.length - 1]).abs();
        // İçerideki tipik sıçramanın birkaç katını aşmamalı. Beyaz gürültüde
        // "tipik sıçrama" zaten büyüktür; kahverengide çok küçüktür — bu yüzden
        // sabit bir eşik değil, SİNYALİN KENDİ ölçeği kullanılıyor.
        final scale = math.max(p99Delta(a), 1e-6);
        expect(
          seamJump,
          lessThan(scale * 3),
          reason: '$type: dikişte $seamJump sıçrama, iç ölçek $scale — tık duyulur',
        );
      }
    });

    test('harman ne çukur ne kabarma açıyor (eşit-güç)', () {
      // Ölçüt: harman bölgesi ile hemen ARDINDAN gelen eşit uzunlukta gövde.
      // (Ham render'la kıyaslamak yanıltıcıydı — pembe gürültünün kendi açılışı
      // sessiz başlıyor, harman ise önceki segmentin tam seviyeli kuyruğunu
      // taşıyor; tüm segmentle kıyaslamak da yanıltıcı — dalga zarfı yüzünden.)
      for (final type in LayerSource.values) {
        final c = chain(type);
        c.next();
        final b = c.next();

        final x = (seamCrossfadeFor(type).inMicroseconds * sampleRate / 1e6)
            .round()
            .clamp(1, b.length ~/ 2);
        final blended = rms(b.sublist(0, x));
        // Kıyas penceresi hemen ARDINDAKİ eşit uzunlukta bölge: kaynağın kendi
        // yavaş zarfı (dalganın kabarması) tüm segmentle kıyaslamayı anlamsız
        // kılar — dalgada segment başı zaten çukurdadır (ölçülen -14 dB).
        final body = rms(b.sublist(x, math.min(b.length, x * 4)));
        if (body == 0 || blended == 0) continue;

        final ratioDb = 20 * math.log(blended / body) / math.ln10;
        expect(
          ratioDb.abs(),
          lessThan(6.0),
          reason: '$type: harman ${ratioDb.toStringAsFixed(1)} dB kayiyor',
        );
      }
    });

    test('ÇEKİRDEK: segmentler AYNI seviyede (periyodik basamak yok)', () {
      // Ölçülen hata: tepe-normalize edilen pembe/kahverengi gürültüde segment
      // RMS'i 0.220–0.303 arasında geziyordu → her segmentte duyulur bir
      // seviye basamağı. Seviye eşitleme bunu kapatıyor.
      for (final type in LayerSource.values) {
        final c = chain(type);
        final levels = <double>[for (var i = 0; i < 6; i++) rms(c.next())];
        final lo = levels.reduce(math.min);
        final hi = levels.reduce(math.max);
        if (lo <= 0) continue;
        final spreadDb = 20 * math.log(hi / lo) / math.ln10;
        expect(
          spreadDb,
          lessThan(1.0),
          reason: '$type: segmentler arası ${spreadDb.toStringAsFixed(2)} dB '
              'seviye farkı — kullanıcı basamağı duyar',
        );
      }
    });
  });

  test('uzun akış: 20 segment boyunca hiçbir ikili birebir eşleşmiyor', () {
    final c = chain(LayerSource.waves);
    final fingerprints = <String>{};
    for (var i = 0; i < 20; i++) {
      final seg = c.next();
      // Parmak izi: birkaç noktadan örnek — tam karşılaştırma pahalı, bu yeterli.
      final fp = <double>[
        for (var k = 0; k < 8; k++) seg[seg.length * k ~/ 8],
      ].join(',');
      expect(fingerprints.add(fp), isTrue, reason: '$i. segment daha önce geçti');
    }
    expect(c.producedCount, 20);
  });
}
