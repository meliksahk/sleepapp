/// **Meditatif kaynaklar** — dalga, ateş, yağmur ve melodik pad.
///
/// Bunlar `noise.dart`'taki beyaz/pembe/kahverengi üreteçlerin YANINA gelir ve
/// mikserde onlarla aynı düzlemde toplanır (`mix_render.dart`). Kaynak örneği,
/// kayıt veya stream **YOKTUR**: hepsi sentezdir. Bu bir maliyet kararı olduğu
/// kadar bir hukuk kararıdır da — telifli/örneklenmiş malzeme mağaza riskidir.
///
/// ## SAĞLIK İDDİASI YOK (CLAUDE.md §1.1)
/// Buradaki hiçbir frekans, periyot veya zarf "tedavi", "beyin dalgası" ya da
/// "bilimsel olarak kanıtlanmış" bir gerekçeyle seçilmedi. Seçimler ESTETİK ve
/// SİNYAL İŞLEME gerekçelidir ve her biri yorumda yazılıdır.
///
/// ## ⚠️ EN KRİTİK KISIT: DÖNGÜ FAZ SÜREKLİLİĞİ
///
/// `MixPlayer` 30 saniyelik bir buffer'ı `LoopMode.one` ile döngüler.
/// `renderSeamlessLoop`'un 50 ms'lik eşit-güç crossfade'i **korelasyonsuz
/// gürültü** için dikiş tıkını çözer — ama YAVAŞ BİR MODÜLASYON için çözmez.
/// Dalganın kabarma periyodu döngü uzunluğunu tam bölmezse, dikişte zarfın FAZI
/// sıçrar: kullanıcı her 30 saniyede bir dalganın "yeniden başladığını" duyar.
/// 50 ms crossfade genliği harmanlar, zarf sıçramasını GİZLEMEZ.
///
/// Bu yüzden buradaki her periyodik büyüklük döngüye **kilitlenir**:
/// - her modülasyon periyodu döngü uzunluğunu TAM BÖLER ([loopLockedPeriod]),
/// - pad'in her frekansı döngüde TAM SAYIDA periyot tamamlar ([loopLockedHz]),
/// - her transient (çıtırtı/damla) döngü sonundan önce TAMAMEN söner
///   (`_scheduleTransients` guard'ı) → dikişte yarım kalmış transient yok.
///
/// ## KIRPMA YAPISAL OLARAK İMKÂNSIZ
///
/// Her kaynağın |çıkış| üst sınırı kapalı formda hesaplanmıştır (aşağıdaki
/// `*PeakBound` sabitleri) ve testle doğrulanır. Kullanılan iki yapı taşı:
/// - `whiteNoise`/`pinkNoise`/`brownNoise` çıkışı tepe-normalize → |x| ≤ 1;
/// - tek kutuplu alçak geçiren `y += a·(x − y)`, a ∈ (0,1]: y, x ile bir önceki
///   y'nin dışbükey birleşimidir → |y| ≤ max(|x|, |y₋₁|) ≤ 1 (a zamanla
///   değişse bile geçerli).
/// Bu yüzden hiçbir kaynakta `clamp` YOKTUR: clamp gerekseydi sınır yanlış olurdu.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'lcg.dart';
import 'noise.dart';

// ─────────────────────────── döngü kilidi ───────────────────────────

/// [desiredSeconds]'a en yakın, [loopSeconds]'ı **tam bölen** periyodu döndürür.
///
/// Örn. 30 sn'lik döngüde 10 sn istenirse 10.0 (3 çevrim); 7 sn istenirse 7.5
/// (4 çevrim). Sonuç her zaman `loopSeconds / tamsayı` olduğu için
/// `cos(2π·t/T)` döngü dikişinde aynı değeri VE aynı türevi verir.
double loopLockedPeriod(double desiredSeconds, double loopSeconds) {
  assert(desiredSeconds > 0 && loopSeconds > 0);
  var cycles = (loopSeconds / desiredSeconds).round();
  if (cycles < 1) cycles = 1; // döngü istenen periyottan kısa → tek çevrim
  return loopSeconds / cycles;
}

/// [desiredHz]'e en yakın, döngüde **tam sayıda periyot** tamamlayan frekans.
///
/// Izgara adımı `1/loopSeconds` Hz (30 sn → 0.0333 Hz). Kilit olmadan pad'in
/// fazı dikişte sıçrardı — tonal bir katmanda bu, gürültüdekinin aksine
/// doğrudan duyulan bir "tık"tır.
double loopLockedHz(double desiredHz, double loopSeconds) {
  assert(desiredHz > 0 && loopSeconds > 0);
  var cycles = (desiredHz * loopSeconds).round();
  if (cycles < 1) cycles = 1; // ızgaradan küçük istek → en düşük geçerli frekans
  return cycles / loopSeconds;
}

// ─────────────────────────── transient zamanlama ───────────────────────────

/// Zamanlanmış tek bir transient (çıtırtı/damla/parıltı).
class _Transient {
  const _Transient(this.start, this.amp, this.variant);

  /// Başlangıç örneği.
  final int start;

  /// Genlik çarpanı [0,1].
  final double amp;

  /// Kaynağa özgü seçim (pad'de parıltı perdesi indeksi; diğerlerinde 0).
  final int variant;
}

/// Transientleri **üst üste binmeyecek** ve **döngü sonundan önce tamamen
/// sönecek** biçimde zamanlar.
///
/// İki kural da pazarlıksız:
/// - **Üst üste binmeme** ([minIoi] ≥ [tailSeconds]): sınır ispatını mümkün
///   kılar. Binmeye izin verseydik anlık toplam N transientin toplamı olurdu ve
///   "kırpma imkânsız" iddiası çökerdi (N rastgele olduğu için sınır da olmazdı).
/// - **Guard** (`start + tail ≤ loopSamples`): döngü sonunda yarıda kesilen bir
///   transient, dikişte tam da kaçınmaya çalıştığımız süreksizliği üretirdi.
///   Kuyruk (extraSamples) bölgesinde bilerek transient YOKTUR: orası crossfade
///   ile sönerek başa harmanlanır, oraya transient koymak onları yarım duyurmak olurdu.
List<_Transient> _scheduleTransients(
  Lcg rng, {
  required int loopSamples,
  required int sampleRate,
  required double minIoi,
  required double maxIoi,
  required double tailSeconds,
  required double minAmp,
  required double maxAmp,
  int variants = 1,
}) {
  assert(minIoi >= tailSeconds, 'binme yasak: minIoi ≥ tail olmalı');
  final loopSeconds = loopSamples / sampleRate;
  final out = <_Transient>[];
  var t = minIoi; // sıfırdan başlama: buffer başında da zarf sıfırdan doğsun
  while (t + tailSeconds <= loopSeconds) {
    // Çekim SIRASI kilitli (golden/determinizm): amp → variant → ioi.
    final amp = rng.nextRange(minAmp, maxAmp);
    var v = 0;
    if (variants > 1) {
      v = (((rng.nextBipolar() + 1) / 2) * variants).floor();
      if (v >= variants) v = variants - 1;
    }
    out.add(_Transient((t * sampleRate).round(), amp, v));
    t += rng.nextRange(minIoi, maxIoi);
  }
  return out;
}

/// Transient zarfı: hızlı doğuş, üstel sönüm. Tepe değeri **kesinlikle ≤ 1**
/// (çünkü `1 − e^-x ≤ 1` ve `e^-y ≤ 1`), sınır ispatının dayanağı budur.
double _grainEnv(double u, double attack, double decay) =>
    (1 - math.exp(-u / attack)) * math.exp(-u / decay);

// ─────────────────────────── waves (dalga) ───────────────────────────

/// Kabarma periyodu (hedef, sn). Döngüye kilitlenir: 30 sn'de tam 10.0 sn olur.
/// **Neden 10 sn:** 30'u bölen değerler arasında, dalganın "gelip çekilmesi"
/// olarak algılanacak kadar yavaş ama kullanıcının başlangıcı beklemesine yol
/// açmayacak kadar sık olan aralık. Estetik seçim, iddiasız.
const double wavesSwellSeconds = 10.0;

const double _wavesDeepAmp = 0.76;
const double _wavesFoamAmp = 0.20;

/// **|çıkış| ≤ 0.96.** Kanıt: derin kat = 0.76·(zarf ≤ 1)·(alçak geçiren ≤ 1),
/// köpük katı = 0.20·(zarf ≤ 1)·(pembe ≤ 1). Toplam 0.76 + 0.20 = 0.96 < 1.
const double wavesPeakBound = _wavesDeepAmp + _wavesFoamAmp;

/// Dalga: kahverengi yatak + yavaş genlik zarfı + zarfla değişen alçak geçiren.
///
/// Karakter DEĞİŞİMİ tek bir zarftan sürülür (`e`): kabarırken hem yükselir hem
/// AÇILIR (kesim frekansı artar, köpük katmanı girer), çekilirken kısılır ve
/// koyulaşır. Tek zarftan sürmek, dikişte tek bir büyüklüğün sürekli olmasının
/// yetmesi demektir — üç bağımsız modülasyon üç ayrı sıçrama riski olurdu.
Float32List wavesSource(
  int samples, {
  required int seed,
  required int sampleRate,
  required int loopSamples,
}) {
  final loopSeconds = loopSamples / sampleRate;
  final period = loopLockedPeriod(wavesSwellSeconds, loopSeconds);

  // Yatak KORELASYONSUZ gürültüdür → döngü kuyruğu ile başı farklıdır ve
  // eşit-güç crossfade'i tam da bunun için doğru araçtır. Kilitlenen şey yalnız ZARF.
  final bed = brownNoise(samples, seed: seed);
  final foam = pinkNoise(samples, seed: seed ^ 0x3F0A);

  final out = Float32List(samples);
  final twoPi = 2 * math.pi;
  var lp = 0.0;
  for (var i = 0; i < samples; i++) {
    final t = i / sampleRate;
    // e ∈ [0,1], periyodu döngüyü tam böler → e(loopSeconds) = e(0), türev dahil.
    final e = 0.5 - 0.5 * math.cos(twoPi * t / period);

    // Kesim: a=0.004 ≈ 31 Hz (çekilme, koyu) → a=0.030 ≈ 229 Hz (kabarma, açık).
    final a = 0.004 + 0.026 * e;
    lp += a * (bed[i] - lp); // |lp| ≤ 1 (dışbükey birleşim)

    // Taban 0.30: dalga çukurda SUSMAZ. Tam sıfıra inen bir zarf, 30 sn'de bir
    // sessizlik demek olurdu ve sessizlik uyandırır (maskeleme kesilir).
    final deep = 0.30 + 0.70 * e;

    // Köpük yalnız tepede: e³ eşik gibi davranır (e=0.5'te 0.125, e=1'de 1).
    final foamEnv = e * e * e;

    out[i] = _wavesDeepAmp * deep * lp + _wavesFoamAmp * foamEnv * foam[i];
  }
  return out;
}

// ─────────────────────────── fire (ateş) ───────────────────────────

const double _fireBedAmp = 0.48;
const double _fireCrackleAmp = 0.32;

/// Çıtırtı sönüm sabiti (sn) ve zarf kuyruğu.
const double _fireDecay = 0.018;
const double _fireAttack = 0.0015;
const double _fireTail = 4 * _fireDecay; // 72 ms'de −34 dB: pratik olarak bitmiş

/// **|çıkış| ≤ 0.80.** Kanıt: yatak 0.48·(kahverengi ≤ 1); çıtırtılar üst üste
/// BİNMEZ (bkz. `_scheduleTransients`) → anlık en çok bir tane, 0.32·(zarf ≤ 1)·
/// (taşıyıcı ≤ 1). Toplam 0.48 + 0.32 = 0.80 < 1.
const double firePeakBound = _fireBedAmp + _fireCrackleAmp;

/// Ateş: kahverengi yatak (uğultu) + kısa çıtırtı transientleri.
///
/// **Uyandırmama kısıtı (uyku uygulaması):** çıtırtı genliği yatağın yarısı
/// mertebesindedir (0.22 vs 0.55) ve taşıyıcısı alçak geçirenden geçirilmiş
/// beyazdır — yani ani, parlak bir "klik" değil, yumuşatılmış bir patlama.
/// Bunun ÖLÇÜLEBİLİR karşılığı crest faktörüdür ve testte raporlanır.
/// ⚠️ Bu ölçüm sesin ürkütücü OLMADIĞINI kanıtlamaz; onu ancak kulak söyler (§1.1).
Float32List fireSource(
  int samples, {
  required int seed,
  required int sampleRate,
  required int loopSamples,
}) {
  final bed = brownNoise(samples, seed: seed);

  // Çıtırtı taşıyıcısı: alçak geçirenden geçmiş beyaz → "odun", "cam" değil.
  final rawCarrier = whiteNoise(samples, seed: seed ^ 0x1CE7);
  final carrier = Float32List(samples);
  var c = 0.0;
  for (var i = 0; i < samples; i++) {
    c += 0.25 * (rawCarrier[i] - c); // |c| ≤ 1
    carrier[i] = c;
  }

  final rng = Lcg(seed ^ 0x5A17);
  final grains = _scheduleTransients(
    rng,
    loopSamples: loopSamples,
    sampleRate: sampleRate,
    // ~5.5 çıtırtı/sn: ateşin "canlı ama telaşsız" olduğu aralık (estetik seçim).
    minIoi: 0.080, // ≥ _fireTail (0.072) → binme yok
    maxIoi: 0.280,
    tailSeconds: _fireTail,
    minAmp: 0.25,
    maxAmp: 1.00,
  );

  final out = Float32List(samples);
  for (var i = 0; i < samples; i++) {
    out[i] = _fireBedAmp * bed[i];
  }
  final tailSamples = (_fireTail * sampleRate).round();
  for (final g in grains) {
    final end = math.min(samples, g.start + tailSamples);
    for (var i = g.start; i < end; i++) {
      final u = (i - g.start) / sampleRate;
      out[i] += _fireCrackleAmp * g.amp * _grainEnv(u, _fireAttack, _fireDecay) * carrier[i];
    }
  }
  return out;
}

// ─────────────────────────── rain (yağmur) ───────────────────────────

const double _rainBedAmp = 0.40;
const double _rainDropAmp = 0.24;

const double _rainDecay = 0.0040;
const double _rainAttack = 0.0004;
const double _rainTail = 4 * _rainDecay; // 16 ms

/// **|çıkış| ≤ 0.64.** Kanıt: yatak 0.40·(alçak geçiren ≤ 1); damlalar binmez →
/// 0.24·(zarf ≤ 1)·(beyaz ≤ 1). Toplam 0.40 + 0.24 = 0.64 < 1.
const double rainPeakBound = _rainBedAmp + _rainDropAmp;

/// Yağmur: filtrelenmiş beyaz yatak + sık, kısa damla transientleri.
///
/// Ateşten farkı ÖLÇÜLEBİLİR: damla sönümü 4.5× daha hızlı (4 ms vs 18 ms) ve
/// taşıyıcı ham beyaz (ateşinki alçak geçirenden geçmiş) → ardışık örnek farkı
/// (`meanAbsDelta`, spektral eğim vekili) belirgin biçimde büyüktür. Sıklık da
/// ~5× fazladır (~27/sn vs ~5.5/sn).
Float32List rainSource(
  int samples, {
  required int seed,
  required int sampleRate,
  required int loopSamples,
}) {
  // Yatak: beyazın en tiz ucu alınmış hâli (a=0.35 ≈ 2.7 kHz) — ham beyaz
  // "parazit" gibi duyulur, yağmur gibi değil.
  final rawBed = whiteNoise(samples, seed: seed);
  final bed = Float32List(samples);
  var b = 0.0;
  for (var i = 0; i < samples; i++) {
    b += 0.35 * (rawBed[i] - b); // |b| ≤ 1
    bed[i] = b;
  }

  final carrier = whiteNoise(samples, seed: seed ^ 0x2D40); // ham: damla parlak

  final rng = Lcg(seed ^ 0x7A11);
  final grains = _scheduleTransients(
    rng,
    loopSamples: loopSamples,
    sampleRate: sampleRate,
    minIoi: 0.018, // ≥ _rainTail (0.016) → binme yok
    maxIoi: 0.055,
    tailSeconds: _rainTail,
    minAmp: 0.20,
    maxAmp: 1.00,
  );

  final out = Float32List(samples);
  for (var i = 0; i < samples; i++) {
    out[i] = _rainBedAmp * bed[i];
  }
  final tailSamples = (_rainTail * sampleRate).round();
  for (final g in grains) {
    final end = math.min(samples, g.start + tailSamples);
    for (var i = g.start; i < end; i++) {
      final u = (i - g.start) / sampleRate;
      out[i] += _rainDropAmp * g.amp * _grainEnv(u, _rainAttack, _rainDecay) * carrier[i];
    }
  }
  return out;
}

// ─────────────────────────── pad (melodik) ───────────────────────────

/// Temel frekans (Hz) — C3, eşit tampere. `nocta_signature.dart` ile AYNI seçim
/// ve aynı gerekçe: estetik, iddiasız. Döngüye kilitlenirken en yakın ızgara
/// değerine oturur (30 sn'de 130.8 Hz).
const double padF0 = 130.81;

/// Kısmi tonlar: (oran, ağırlık, detune Hz). Ağırlık toplamı **tam 1.00** —
/// sınır ispatı buna dayanır, değiştirilemez. Desen `nocta_signature.dart`'tan
/// alındı (orada kulakla ayarlandı); buradaki TEK fark her frekansın döngü
/// ızgarasına oturtulmasıdır.
const List<List<double>> _padPartials = <List<double>>[
  <double>[1.0, 0.30, 0.17],
  <double>[1.5, 0.18, 0.23],
  <double>[2.0, 0.24, 0.29],
  <double>[3.0, 0.16, 0.37],
  <double>[4.0, 0.12, 0.41],
];

const double _padAmp = 0.26;
const double _padDetuneGain = 0.35;

/// Parıltı perdeleri: yalnız f0'ın tam katları → seed ne olursa olsun disonans
/// imkânsız (rastgelelik yalnız ZAMANLAMADA). `nocta_signature.dart` ile aynı.
const List<int> _padShimmerMultiples = <int>[8, 12, 16, 20, 24];
const double _padShimmerAmp = 0.14;
const double _padShimmerAttack = 0.015;
const double _padShimmerDecay = 0.55;
const double _padShimmerTail = 4 * _padShimmerDecay; // 2.2 sn

/// Nefes alma periyodu (hedef, sn) — 30 sn'lik döngüde tam 15.0 olur.
const double padBreathSeconds = 15.0;

/// **|çıkış| ≤ 0.491.** Kanıt:
/// - pad = nefes(≤1)·0.26·Σwₖ·(|sin| + 0.35·|sin|) ≤ 0.26·1.00·1.35 = 0.351
/// - parıltı: üst üste BİNMEZ → anlık en çok bir tane,
///   0.14·(genlik ≤ 1)·√(8/m ≤ 1)·(zarf ≤ 1) ≤ 0.14
/// Toplam 0.351 + 0.14 = 0.491 < 1.
const double padPeakBound = 0.351 + _padShimmerAmp;

/// Melodik/atmosferik pad — **tek DÖNGÜ-PERİYODİK kaynak**.
///
/// Tamamen tonaldir: içinde gürültü YOKTUR. Bu bilinçli bir kısıttır. Gürültü
/// katsaydık kaynak artık döngü periyoduna kilitlenemezdi (gürültünün sarma
/// noktasında süreksizlik olur) ve `renderSeamlessLoop`'un pad için crossfade'i
/// ATLAYABİLMESİ mümkün olmazdı. "Hava" isteyen kullanıcı mikserde pembe
/// katmanı açar — mikserin var oluş sebebi tam olarak budur.
///
/// **Neden crossfade atlanmalı:** eşit-güç crossfade korelasyonSUZ sinyaller
/// içindir. Pad döngü-periyodik olduğu için kuyruk ile baş BİREBİR AYNIdır ve
/// eşit-güç harmanı onları sin(θ)+cos(θ) ≤ √2 ile toplar → her döngü başında
/// 50 ms boyunca +3 dB'lik bir kabarma. Periyodik kaynakta crossfade'e GEREK
/// YOKTUR: s[n] = s[0] zaten sağlanır (bkz. `mix_loop.dart`).
Float32List padSource(
  int samples, {
  required int seed,
  required int sampleRate,
  required int loopSamples,
}) {
  final loopSeconds = loopSamples / sampleRate;
  final breath = loopLockedPeriod(padBreathSeconds, loopSeconds);

  // Her frekans ızgaraya oturtulur → döngüde tam sayıda periyot.
  final freqs = <double>[];
  final detuned = <double>[];
  final weights = <double>[];
  for (final p in _padPartials) {
    final f = loopLockedHz(padF0 * p[0], loopSeconds);
    // Detune de ızgaraya oturur; en az BİR ızgara adımı olmalı, yoksa vuru
    // kaybolur (kısa döngüde ızgara kabalaşır ve 0.17 Hz sıfıra yuvarlanırdı).
    var dCycles = (p[2] * loopSeconds).round();
    if (dCycles < 1) dCycles = 1;
    freqs.add(f);
    detuned.add(f + dCycles / loopSeconds);
    weights.add(p[1]);
  }

  final rng = Lcg(seed ^ 0x9A0D);
  final grains = _scheduleTransients(
    rng,
    loopSamples: loopSamples,
    sampleRate: sampleRate,
    // Parıltılar SEYREK: binme yasağı zaten ioi ≥ 2.2 sn dayatıyor.
    minIoi: _padShimmerTail + 0.20,
    maxIoi: 4.00,
    tailSeconds: _padShimmerTail,
    minAmp: 0.55,
    maxAmp: 1.00,
    variants: _padShimmerMultiples.length,
  );

  final out = Float32List(samples);
  final twoPi = 2 * math.pi;
  for (var i = 0; i < samples; i++) {
    final t = i / sampleRate;
    // Nefes ∈ [0.75, 1.0]: pad hiç susmaz, yalnız "soluk alır".
    final b = 0.75 + 0.25 * (0.5 - 0.5 * math.cos(twoPi * t / breath));
    var v = 0.0;
    for (var k = 0; k < freqs.length; k++) {
      v += weights[k] *
          (math.sin(twoPi * freqs[k] * t) + _padDetuneGain * math.sin(twoPi * detuned[k] * t));
    }
    out[i] = b * _padAmp * v;
  }

  final tailSamples = (_padShimmerTail * sampleRate).round();
  for (final g in grains) {
    final m = _padShimmerMultiples[g.variant];
    // Parıltı perdesi de ızgarada: kendi içinde tam periyot tamamlamasa da
    // zarfı sıfırdan doğup sıfıra söndüğü için dikişe hiç değmez.
    final fm = loopLockedHz(padF0 * m, loopSeconds);
    final gain = _padShimmerAmp * g.amp * math.sqrt(8 / m);
    final end = math.min(samples, g.start + tailSamples);
    for (var i = g.start; i < end; i++) {
      final u = (i - g.start) / sampleRate;
      out[i] += gain * _grainEnv(u, _padShimmerAttack, _padShimmerDecay) * math.sin(twoPi * fm * u);
    }
  }
  return out;
}
