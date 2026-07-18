import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nocta/core/audio_engine/dsp/meditative.dart';
import 'package:nocta/core/audio_engine/dsp/mix_loop.dart';
import 'package:nocta/core/audio_engine/dsp/mix_render.dart';
import 'package:nocta/core/audio_engine/dsp/noise.dart';

/// Meditatif kaynaklar (#213): dalga, ateş, yağmur, pad.
///
/// **Bu testler sesin DOĞRU olduğunu kanıtlar, GÜZEL olduğunu kanıtlamaz**
/// (CLAUDE.md §1.1). Buradaki her iddia ÖLÇÜLMÜŞ bir sayıdır; "doğal duyuluyor"
/// gibi bir cümle bu dosyada geçmez ve geçmemelidir.
///
/// Eşikler uydurulmadı: `tool/measure_meditative.dart` çıktısından alındı ve
/// yorumlarda ölçülen değerle birlikte yazıldı.
void main() {
  const sr = 48000;
  const loopSec = 30;
  const n = sr * loopSec;

  final meditative = <LayerSource>[
    LayerSource.waves,
    LayerSource.fire,
    LayerSource.rain,
    LayerSource.pad,
  ];

  final bounds = <LayerSource, double>{
    LayerSource.waves: wavesPeakBound,
    LayerSource.fire: firePeakBound,
    LayerSource.rain: rainPeakBound,
    LayerSource.pad: padPeakBound,
  };

  Float32List gen(LayerSource t, {int seed = 1234, int samples = n, int? loop}) =>
      renderSource(t, samples, seed: seed, sampleRate: sr, loopSamples: loop ?? n);

  double peak(Float32List b) {
    var m = 0.0;
    for (final v in b) {
      if (v.abs() > m) m = v.abs();
    }
    return m;
  }

  /// |x|'in alçak geçirenden geçmiş hâli — zarf vekili (Hilbert'e gerek yok:
  /// ilgilendiğimiz modülasyon 0.1 Hz mertebesinde, çok altında bir kesim yeter).
  Float32List envelope(Float32List b, {double a = 0.0008}) {
    final e = Float32List(b.length);
    var y = 0.0;
    for (var i = 0; i < b.length; i++) {
      y += a * (b[i].abs() - y);
      e[i] = y;
    }
    return e;
  }

  /// Zarfın [periodSeconds] periyodundaki modülasyon derinliği (ortalamaya
  /// normalize tek-frekans genliği). Tam FFT'ye gerek yok: hipotez zaten TEK bir
  /// periyot hakkında ve o periyodu biz seçtik.
  double modDepth(Float32List env, double periodSeconds) {
    final w = 2 * math.pi / (periodSeconds * sr);
    var re = 0.0, im = 0.0, mean = 0.0;
    for (var i = 0; i < env.length; i++) {
      re += env[i] * math.cos(w * i);
      im += env[i] * math.sin(w * i);
      mean += env[i];
    }
    mean /= env.length;
    return (2 * math.sqrt(re * re + im * im) / env.length) / mean;
  }

  /// Normalize otokorelasyon — tonalliğin doğrudan kanıtı.
  double autocorr(Float32List b, int lag, {int take = sr * 2}) {
    final m = math.min(take, b.length - lag);
    var num = 0.0, d0 = 0.0, d1 = 0.0;
    for (var i = 0; i < m; i++) {
      num += b[i] * b[i + lag];
      d0 += b[i] * b[i];
      d1 += b[i + lag] * b[i + lag];
    }
    return num / math.sqrt(d0 * d1);
  }

  /// İki kademeli tek kutuplu yüksek geçiren (`y = x − lp(x)`, iki kez).
  Float32List highPass(Float32List b, double a) {
    var cur = Float32List.fromList(b);
    for (var pass = 0; pass < 2; pass++) {
      var lp = 0.0;
      final t = Float32List(cur.length);
      for (var i = 0; i < cur.length; i++) {
        lp += a * (cur[i] - lp);
        t[i] = cur[i] - lp;
      }
      cur = t;
    }
    return cur;
  }

  /// 20 ms'lik blok RMS dizisi — zarfın gecikmesiz, durumsuz kestirimi.
  ///
  /// **Neden alçak geçirenli zarf DEĞİL:** ilk sürümde `envelope()` + örnek
  /// başına türev kullanılıyordu ve NEGATİF KONTROL onu ELEDİ — alçak geçiren,
  /// zarfın SEVİYE sıçramasını ~26 ms'ye yayar, dolayısıyla örnek başına türev
  /// küçük kalır: metrik tam da yakalaması gereken hatayı göremiyordu. Blok RMS'in
  /// gecikmesi yok, sıçrama komşu iki blok arasında olduğu gibi görünür.
  List<double> blockRms(Float32List b, {int block = 960}) {
    final out = <double>[];
    for (var s = 0; s + block <= b.length; s += block) {
      var sum = 0.0;
      for (var i = s; i < s + block; i++) {
        sum += b[i] * b[i];
      }
      out.add(math.sqrt(sum / block));
    }
    return out;
  }

  /// Döngü dikişindeki blok-RMS sıçraması / ortalama blok RMS.
  ///
  /// Buffer kendine eklenir ve dikişin İKİ YANINDAKİ komşu bloklar karşılaştırılır:
  /// kullanıcının 30 saniyede bir gerçekten geçtiği yer burasıdır.
  /// Ortalamaya bölmek, kaynakların farklı seviyelerini karşılaştırılabilir kılar.
  double seamStepRatio(Float32List b, {int block = 960}) {
    final twice = Float32List(b.length * 2)
      ..setRange(0, b.length, b)
      ..setRange(b.length, b.length * 2, b);
    final br = blockRms(twice, block: block);
    final k = b.length ~/ block;
    final mean = br.reduce((a, c) => a + c) / br.length;
    return (br[k] - br[k - 1]).abs() / mean;
  }

  /// Dikiş sıçraması ile buffer İÇİNDEKİ tipik (%99.9) blok-blok sıçraması.
  ({double seam, double p999}) seamVsInterior(Float32List b, {int block = 960}) {
    final twice = Float32List(b.length * 2)
      ..setRange(0, b.length, b)
      ..setRange(b.length, b.length * 2, b);
    final br = blockRms(twice, block: block);
    final k = b.length ~/ block;
    final inner = <double>[];
    for (var i = 1; i < k; i++) {
      inner.add((br[i] - br[i - 1]).abs());
    }
    inner.sort();
    return (seam: (br[k] - br[k - 1]).abs(), p999: inner[(inner.length * 0.999).toInt()]);
  }

  // ───────────────────────── güvenlik ─────────────────────────

  group('GÜVENLİK: kırpma yapısal olarak imkânsız', () {
    test('ÇEKİRDEK: her kaynağın sınırı 1\'in ALTINDA (sınırın kendisi ispat)', () {
      // Sınır kapalı formda hesaplandı (meditative.dart yorumları). 1'e eşit bile
      // olamaz: eşitlik, kayan nokta yuvarlamasıyla kırpmaya dokunmak demektir.
      for (final t in meditative) {
        expect(bounds[t]!, lessThan(1.0), reason: '$t sınırı 1\'in altında olmalı');
      }
    });

    test('ÇEKİRDEK: ölçülen tepe, yazılı sınırı AŞMIYOR (çok seed, çok döngü boyu)', () {
      // ölçülen (seed 1234, 30 sn): waves 0.5555/0.96, fire 0.4952/0.80,
      //                             rain 0.4436/0.64, pad 0.3024/0.491
      for (final t in meditative) {
        for (final seed in [0, 7, 1234, 99991]) {
          for (final loopSeconds in [2, 15, 30]) {
            final len = sr * loopSeconds;
            final b = gen(t, seed: seed, samples: len, loop: len);
            expect(peak(b), lessThanOrEqualTo(bounds[t]!),
                reason: '$t seed=$seed loop=${loopSeconds}s sınırı aştı');
          }
        }
      }
    });

    test('kuyruk (extraSamples) bölgesi de sınır içinde', () {
      // renderSeamlessLoop döngü uzunluğunun ÖTESİNİ ister; guard/kilit mantığı
      // orada da bozulmamalı.
      for (final t in meditative) {
        final b = gen(t, samples: n + 4800, loop: n);
        expect(peak(b), lessThanOrEqualTo(bounds[t]!));
      }
    });

    test('ÇEKİRDEK: zincir çıkışı (renderMix) [-1,1] içinde ve kırpma SAYACI sıfır', () {
      // Yedi katman birden — mikserin clamp sayacı 0 dönmeli: yani clamp'e HİÇ
      // dokunulmadı, "clamp kurtardı" değil "gerek olmadı".
      var clipped = -1;
      final out = renderMix(
        MixSpec([
          for (final t in LayerSource.values)
            MixLayer(id: t.name, type: t, gain: 1.0 / LayerSource.values.length),
        ]),
        seconds: 5,
        sampleRate: sr,
        seed: 3,
        onClipReport: (c) => clipped = c,
      );
      expect(clipped, 0);
      expect(peak(out), lessThan(1.0));
    });

    test('ÇEKİRDEK: transientler yatağın tepesini AŞMIYOR (uyuyanı sıçratmama)', () {
      // Kontrollü karşılaştırma: aynı seed'li yatak, transientsiz.
      // ölçülen: fire en büyük transient katkısı 0.1584 (yatak tepesi 0.4800),
      //          rain 0.1700 (yatak tepesi 0.3554).
      final brown = brownNoise(n, seed: 1234);
      final fireBed = Float32List(n);
      for (var i = 0; i < n; i++) {
        fireBed[i] = 0.48 * brown[i];
      }
      final fire = gen(LayerSource.fire);
      var maxDiff = 0.0;
      for (var i = 0; i < n; i++) {
        final d = (fire[i] - fireBed[i]).abs();
        if (d > maxDiff) maxDiff = d;
      }
      expect(maxDiff, lessThan(peak(fireBed)),
          reason: 'tek bir çıtırtı, yatağın tepesinden yüksek olmamalı');
      expect(maxDiff, lessThan(0.25), reason: 'mutlak tavan (ölçülen 0.158)');
    });

    test('crest faktörü SINIRLI — ani devasa tepe yok', () {
      // ölçülen: waves 6.37, fire 4.63, rain 4.11, pad 3.71.
      // Üst sınır 8: bunun üstü, ortalamanın çok üstünde tekil bir olay demektir.
      for (final t in meditative) {
        final b = gen(t);
        final crest = peak(b) / rms(b);
        expect(crest, lessThan(8.0), reason: '$t crest=$crest fazla tepeli');
      }
    });
  });

  group('DC ve determinizm', () {
    test('DC ihmal edilebilir (ham kaynak)', () {
      // ölçülen: waves -0.006462, fire 0.000265, rain 0.000057, pad 0.000000.
      // waves'inki en büyüğü: zarf hep POZİTİF olduğu için yatağın kalıntı
      // DC'sini modüle eder. Zincirdeki DcBlocker onu siler (aşağıdaki test).
      for (final t in meditative) {
        expect(dcOffset(gen(t)).abs(), lessThan(0.01), reason: '$t');
      }
    });

    test('ÇEKİRDEK: zincir sonunda DC temizleniyor', () {
      for (final t in meditative) {
        final out = renderMix(
          MixSpec([MixLayer(id: 'a', type: t, gain: 1.0)]),
          seconds: 10,
          sampleRate: sr,
          seed: 1234,
        );
        expect(dcOffset(out).abs(), lessThan(0.001), reason: '$t');
      }
    });

    test('ÇEKİRDEK: aynı seed → birebir aynı buffer', () {
      for (final t in meditative) {
        expect(gen(t, seed: 42, samples: sr * 3, loop: sr * 3),
            equals(gen(t, seed: 42, samples: sr * 3, loop: sr * 3)));
      }
    });

    test('farklı seed → farklı buffer (pad dahil: parıltı zamanlaması seed\'e bağlı)', () {
      for (final t in meditative) {
        expect(gen(t, seed: 1, samples: sr * 5, loop: sr * 5),
            isNot(equals(gen(t, seed: 2, samples: sr * 5, loop: sr * 5))));
      }
    });
  });

  // ───────────────────────── karakter (ölçülerek) ─────────────────────────

  group('KARAKTER: dalga — beklenen periyotta zarf modülasyonu VAR', () {
    test('ÇEKİRDEK: 10 sn periyodunda derin modülasyon, komşu periyotlarda YOK', () {
      final env = envelope(gen(LayerSource.waves));
      final at10 = modDepth(env, 10.0); // ölçülen 0.7493
      expect(at10, greaterThan(0.5), reason: 'kabarma zarfı ölçülemedi: $at10');

      // Kontrol: 30'u bölen BAŞKA periyotlarda derinlik yok → modülasyon
      // gerçekten 10 sn'de, "her yerde biraz dalgalanma" değil.
      for (final p in [7.5, 6.0, 3.0]) {
        final other = modDepth(env, p); // ölçülen ≤ 0.013
        expect(other, lessThan(at10 / 10),
            reason: '$p sn\'de de modülasyon var ($other) — periyot iddiası çürük');
      }
    });

    test('ÇEKİRDEK: diğer kaynaklarda 10 sn modülasyonu YOK (negatif kontrol)', () {
      // ölçülen: brown 0.0041, pink 0.0054, white 0.0002, rain 0.0014,
      //          fire 0.0041, pad 0.0096
      for (final t in LayerSource.values) {
        if (t == LayerSource.waves) continue;
        expect(modDepth(envelope(gen(t)), 10.0), lessThan(0.05), reason: '$t');
      }
    });

    test('kabarma periyodu döngüyü TAM BÖLER (her döngü boyunda)', () {
      for (final loopSeconds in [30.0, 15.0, 10.0, 7.5]) {
        final p = loopLockedPeriod(wavesSwellSeconds, loopSeconds);
        final cycles = loopSeconds / p;
        expect((cycles - cycles.round()).abs(), lessThan(1e-9),
            reason: 'loop=$loopSeconds periyot=$p tam bölmüyor');
      }
    });
  });

  group('KARAKTER: ateş/yağmur — transient VAR ama sınırlı', () {
    test('ÇEKİRDEK: crest, DÜZ beyaz gürültüden belirgin yüksek', () {
      // ölçülen: white 1.73, fire 4.63, rain 4.11 → ≥2.3×.
      final whiteCrest = () {
        final w = whiteNoise(n, seed: 1234);
        return peak(w) / rms(w);
      }();
      for (final t in [LayerSource.fire, LayerSource.rain]) {
        final b = gen(t);
        expect(peak(b) / rms(b), greaterThan(whiteCrest * 2.0), reason: '$t');
      }
    });

    test('ÇEKİRDEK: transient bandında (>900 Hz) crest, TRANSIENTSİZ yataktan yüksek', () {
      // NEDEN BANT: ateşin yatağı kahverengi gürültü ve o da tepe-normalize
      // olduğu için GENİŞ BANT crest'i zaten 4.51 — çıtırtılar geniş bantta
      // ölçülemez (ölçüldü: fire 4.63 vs yatak 4.51, ayırt edilemez).
      // Çıtırtılar yatağın olmadığı bantta yaşar; kanıt oradadır.
      // ölçülen (HP a=0.12 ≈ 917 Hz): fire 5.96 vs yatak 4.21 (+42%),
      //                               rain 4.79 vs yatak 3.55 (+35%).
      double bandCrest(Float32List b) {
        final h = highPass(b, 0.12);
        return peak(h) / rms(h);
      }

      final brown = brownNoise(n, seed: 1234);
      final fireBed = Float32List(n);
      for (var i = 0; i < n; i++) {
        fireBed[i] = 0.48 * brown[i];
      }
      expect(bandCrest(gen(LayerSource.fire)), greaterThan(bandCrest(fireBed) * 1.2));

      final rawWhite = whiteNoise(n, seed: 1234);
      final rainBed = Float32List(n);
      var y = 0.0;
      for (var i = 0; i < n; i++) {
        y += 0.35 * (rawWhite[i] - y);
        rainBed[i] = 0.40 * y;
      }
      expect(bandCrest(gen(LayerSource.rain)), greaterThan(bandCrest(rainBed) * 1.2));
    });

    test('ÇEKİRDEK: yağmur ateşten daha TİZ ve daha SIK (ardışık örnek farkı)', () {
      // meanAbsDelta = spektral eğim vekili (noise.dart). ölçülen:
      // rain 0.07717, fire 0.01889 → ~4×.
      expect(meanAbsDelta(gen(LayerSource.rain)),
          greaterThan(meanAbsDelta(gen(LayerSource.fire)) * 2));
    });
  });

  group('KARAKTER: pad — tonal', () {
    test('ÇEKİRDEK: f0 periyodunda otokorelasyon yüksek; hiçbir gürültü kaynağı yaklaşamıyor', () {
      // ölçülen (lag=367 ≈ 130.8 Hz): pad 0.7115; en yakın rakip pink 0.4464,
      // sonra waves 0.0933, brown 0.0191, fire 0.0182, rain -0.0021, white -0.0007.
      final lag = (sr / loopLockedHz(padF0, loopSec.toDouble())).round();
      final padAc = autocorr(gen(LayerSource.pad), lag);
      expect(padAc, greaterThan(0.6), reason: 'pad tonal değil: ac=$padAc');

      for (final t in LayerSource.values) {
        if (t == LayerSource.pad) continue;
        expect(autocorr(gen(t), lag), lessThan(0.55), reason: '$t');
      }
    });

    test('pad frekansları döngüde TAM SAYIDA periyot tamamlıyor', () {
      for (final loopSeconds in [30.0, 15.0, 2.0]) {
        for (final ratio in [1.0, 1.5, 2.0, 3.0, 4.0]) {
          final f = loopLockedHz(padF0 * ratio, loopSeconds);
          final cycles = f * loopSeconds;
          expect((cycles - cycles.round()).abs(), lessThan(1e-9),
              reason: 'loop=$loopSeconds f=$f tam periyot değil');
        }
      }
    });

    test('pad içinde gürültü YOK — döngü kilidi bunu gerektiriyor', () {
      // Kanıt: aynı seed ile üretilen iki ARDIŞIK döngü periyodu birebir aynı
      // olmalı (parıltı guard'ı dışında). Gürültü olsaydı olamazdı.
      final b = gen(LayerSource.pad, samples: n * 2, loop: n);
      // İkinci döngünün ilk 5 saniyesi, birincinin ilk 5 saniyesiyle aynı fazda:
      // tonal kısım periyodik. (Parıltılar seed dizisinden geldiği için ayrı;
      // bu yüzden ilk 0.5 sn'ye bakıyoruz — orada parıltı yok.)
      final half = (0.5 * sr).round();
      var maxDelta = 0.0;
      for (var i = 0; i < half; i++) {
        final d = (b[i] - b[n + i]).abs();
        if (d > maxDelta) maxDelta = d;
      }
      expect(maxDelta, lessThan(1e-6),
          reason: 'pad döngü periyoduna kilitli değil (fark $maxDelta)');
    });
  });

  // ───────────────────────── döngü faz sürekliliği ─────────────────────────

  group('DÖNGÜ FAZ SÜREKLİLİĞİ (bu görevin en kritik şartı)', () {
    test('ÖRNEK DÜZEYİ dikiş: tek örneklik tık BLOK-RMS metriğine görünmez, bu yüzden ayrı ölçülür', () {
      // DENETİMDE KANITLANDI: `seamStepRatio` 20 ms (960 örnek) blok RMS'i kullanıyor;
      // tek örneklik bir süreksizliği ortalamaya gömüyor. Denetçi dikişe tam ölçeğin
      // %20'si kadar bir pop enjekte etti ve "dikiş SIFIR" testi YİNE geçti.
      // Bu yüzden dikişi ÖRNEK DÜZEYİNDE de ölçüyoruz: son örnekten ilk örneğe
      // geçişteki sıçrama, buffer içindeki tipik ardışık sıçramanın çok üstünde
      // olmamalı — çünkü kullanıcı bunu tık olarak duyar.
      for (final t in LayerSource.values) {
        final b = renderSeamlessLoop(
          MixSpec([MixLayer(id: 'l', type: t, gain: 1.0)]),
          loopSeconds: 10,
          seed: 1234,
        );
        final seamJump = (b[0] - b[b.length - 1]).abs();

        // Buffer içindeki ardışık farkların %99.9'u.
        final deltas = <double>[];
        for (var i = 1; i < b.length; i++) {
          deltas.add((b[i] - b[i - 1]).abs());
        }
        deltas.sort();
        final p999 = deltas[(deltas.length * 0.999).floor()];

        expect(
          seamJump,
          lessThanOrEqualTo(math.max(p999 * 1.5, 1e-6)),
          reason: '$t dikiş sıçraması=$seamJump iç %99.9=$p999 — '
              'dikiş buffer içindeki normal sıçramanın dışına çıkmamalı',
        );
      }
    });

    test('NEGATİF KONTROL: enjekte edilen tık ÖRNEK DÜZEYİ testinde yakalanır', () {
      // Yukarıdaki testin gerçekten ayrım yaptığını kanıtlar; yoksa "hep geçen"
      // bir test olurdu (denetimin blok-RMS metriğinde bulduğu tam da buydu).
      final b = renderSeamlessLoop(
        MixSpec([MixLayer(id: 'l', type: LayerSource.pad, gain: 1.0)]),
        loopSeconds: 10,
        seed: 1234,
      );
      final deltas = <double>[];
      for (var i = 1; i < b.length; i++) {
        deltas.add((b[i] - b[i - 1]).abs());
      }
      deltas.sort();
      final p999 = deltas[(deltas.length * 0.999).floor()];

      // Temizken geçiyor...
      expect((b[0] - b[b.length - 1]).abs(), lessThanOrEqualTo(math.max(p999 * 1.5, 1e-6)));

      // ...pop enjekte edilince KIRILIYOR.
      final tampered = Float32List.fromList(b);
      tampered[0] = tampered[0] + 0.2;
      expect(
        (tampered[0] - tampered[tampered.length - 1]).abs(),
        greaterThan(p999 * 1.5),
        reason: 'örnek düzeyi metrik %20 genlikli tıkı GÖRMELİ',
      );
    });

    test('ÇEKİRDEK: dikiş sıçraması, buffer içindeki tipik sıçramanın ALTINDA', () {
      // Her kaynak, kendi doğal değişkenliğiyle karşılaştırılır: dikiş "anormal"
      // bir olay olmamalı. ölçülen seam/p999 oranı: waves 0.004–0.161,
      // pad 0.000, rain 0.037–0.218, fire 0.273–0.418
      // (mevcut gürültüler aynı testte: white 0.35–0.40, brown 0.27–0.42).
      for (final t in LayerSource.values) {
        for (final seed in [7, 4242]) {
          final b = renderSeamlessLoop(
            MixSpec([MixLayer(id: 'a', type: t, gain: 1.0)]),
            loopSeconds: loopSec,
            sampleRate: sr,
            seed: seed,
          );
          final s = seamVsInterior(b);
          expect(s.seam, lessThan(s.p999),
              reason: '$t seed=$seed dikiş=${s.seam} iç %99.9=${s.p999}');
        }
      }
    });

    test('ÇEKİRDEK: normalize dikiş sıçraması, gürültü kaynaklarınınkini AŞMIYOR', () {
      // ölçülen seam/ortalama (5 seed): waves ≤0.255, pad 0.000, rain ≤0.050,
      // fire ≤0.311 — mevcut brown ≤0.312, pink ≤0.325.
      // Yani meditatif kaynaklar döngüye, mevcut gürültülerden DAHA KÖTÜ oturmuyor.
      for (final t in meditative) {
        for (final seed in [0, 7, 99, 4242, 31337]) {
          final b = renderSeamlessLoop(
            MixSpec([MixLayer(id: 'a', type: t, gain: 1.0)]),
            loopSeconds: loopSec,
            sampleRate: sr,
            seed: seed,
          );
          expect(seamStepRatio(b), lessThan(0.35), reason: '$t seed=$seed');
        }
      }
    });

    test('ÇEKİRDEK: pad dikişi SIFIR — kilit tam (bit düzeyinde periyodik)', () {
      // ölçülen: 5 seed'in hepsinde 0.000. Pad tamamen tonal ve her frekansı
      // döngüde tam periyot tamamladığı için sıçrama MATEMATİKSEL olarak yok.
      for (final seed in [0, 7, 99, 4242, 31337]) {
        final b = renderSeamlessLoop(
          const MixSpec([MixLayer(id: 'a', type: LayerSource.pad, gain: 1.0)]),
          loopSeconds: loopSec,
          sampleRate: sr,
          seed: seed,
        );
        expect(seamStepRatio(b), lessThan(0.01), reason: 'seed=$seed');
      }
    });

    test('ÇEKİRDEK (NEGATİF KONTROL): kilit bozulunca dikiş GERÇEKTEN patlıyor', () {
      // Testin dişi olduğunu kanıtlar — bu olmadan yukarıdaki üç test "her şey
      // sakin" diyen ama hiçbir şey ölçmeyen testler olabilirdi.
      //
      // Kurgu: dalga 30 sn'ye kilitli üretilir ama 13/23 sn'de KESİLİR. 10 sn'lik
      // kabarma bu boyları bölmez → dikişte zarfın FAZI sıçrar. Bu, kilit
      // olmasaydı kullanıcının her döngüde duyacağı şeyin ta kendisidir.
      //
      // ⚠️ Karşılaştırma AYNI SEED üzerinden: kahverengi yatağın kendi gezinmesi
      // her iki tarafta da var, aradaki fark YALNIZCA zarf fazıdır.
      for (final cut in [13, 23]) {
        for (final seed in [0, 7, 99, 4242, 31337]) {
          final locked = renderSeamlessLoop(
            const MixSpec([MixLayer(id: 'a', type: LayerSource.waves, gain: 1.0)]),
            loopSeconds: loopSec,
            sampleRate: sr,
            seed: seed,
          );
          final unlocked = renderSource(LayerSource.waves, sr * cut,
              seed: seed, sampleRate: sr, loopSamples: n);
          final lockedRatio = seamStepRatio(locked);
          final unlockedRatio = seamStepRatio(unlocked);
          // ölçülen: kilitli ≤0.255, kilitsiz 0.475–1.497.
          expect(unlockedRatio, greaterThan(lockedRatio * 2),
              reason: 'kesim=${cut}sn seed=$seed: kilitli=$lockedRatio '
                  'kilitsiz=$unlockedRatio — test ayrım yapamıyor');
          expect(unlockedRatio, greaterThan(0.4));
        }
      }
    });

    test('ÇEKİRDEK: pad katmanına crossfade UYGULANMIYOR (+3 dB kabarma yok)', () {
      // Eşit-güç crossfade korelasyonSUZ sinyal içindir; pad kendisiyle birebir
      // aynı olduğu için harman θ=π/4'te √2 kazanç verirdi → her döngü başında
      // 50 ms boyunca +3 dB. Kanıt: harman bölgesinin RMS'i, hemen sonrasıyla
      // aynı olmalı.
      final b = renderSeamlessLoop(
        const MixSpec([MixLayer(id: 'a', type: LayerSource.pad, gain: 1.0)]),
        loopSeconds: loopSec,
        sampleRate: sr,
        seed: 7,
      );
      final x = (0.050 * sr).round();
      double windowRms(Float32List v, int from, int to) {
        var s = 0.0;
        for (var i = from; i < to; i++) {
          s += v[i] * v[i];
        }
        return math.sqrt(s / (to - from));
      }

      final blend = windowRms(b, 0, x);
      final after = windowRms(b, x, 2 * x);
      // √2 kabarma olsaydı bu oran ~1.2+ olurdu (harman boyunca ortalaması).
      expect(blend / after, lessThan(1.15),
          reason: 'pad harman bölgesi kabarmış: ${blend / after}');
    });
  });

  // ───────────────────────── mikser entegrasyonu ─────────────────────────

  group('mikser ile karışabilirlik', () {
    test('ÇEKİRDEK: gürültü + meditatif KARIŞIK mix render oluyor, kırpmıyor', () {
      var clipped = -1;
      final out = renderMix(
        const MixSpec([
          MixLayer(id: 'brown', type: LayerSource.brown, gain: 0.30),
          MixLayer(id: 'waves', type: LayerSource.waves, gain: 0.30),
          MixLayer(id: 'fire', type: LayerSource.fire, gain: 0.20),
          MixLayer(id: 'pad', type: LayerSource.pad, gain: 0.20),
        ]),
        seconds: 5,
        sampleRate: sr,
        seed: 11,
        onClipReport: (c) => clipped = c,
      );
      expect(clipped, 0);
      expect(peak(out), lessThan(1.0));
      expect(rms(out), greaterThan(0.01), reason: 'mix sessiz çıkmamalı');
    });

    test('ÇEKİRDEK: karışık spec döngüsünde pad ham, gürültü crossfade\'li', () {
      // Karışık spec `_renderPerLayerLoop` yoluna girer; sonuç yine [-1,1] ve
      // uzunluk tam döngü olmalı.
      final b = renderSeamlessLoop(
        const MixSpec([
          MixLayer(id: 'brown', type: LayerSource.brown, gain: 0.5),
          MixLayer(id: 'pad', type: LayerSource.pad, gain: 0.4),
        ]),
        loopSeconds: 5,
        sampleRate: sr,
        seed: 3,
      );
      expect(b.length, sr * 5);
      expect(peak(b), lessThanOrEqualTo(1.0));
    });

    test('katman dekorelasyonu yeni tiplerde de geçerli', () {
      // Aynı tip iki katman aynı sesi üretirse toplama zenginleştirmez, sadece
      // yükseltir (mix_render.dart\'taki asal çarpan bunun içindi).
      final a = gen(LayerSource.waves, seed: layerSeed(42, 0), samples: sr, loop: sr);
      final b = gen(LayerSource.waves, seed: layerSeed(42, 1), samples: sr, loop: sr);
      var same = 0;
      for (var i = 0; i < a.length; i++) {
        if (a[i] == b[i]) same++;
      }
      expect(same / a.length, lessThan(0.01));
    });
  });
}
