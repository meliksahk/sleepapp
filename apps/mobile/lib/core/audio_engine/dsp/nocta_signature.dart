/// NOCTA'nın **sonik imzası** — açılışta bir kez çalan atmosfer (marka aurası).
///
/// **Neden ezgi değil, neden sadece pad de değil:** bir jingle (Netflix "ta-dum")
/// gece 23:00'te yatakta yanlış; düz bir pad ise güzel ama jeneriktir — her uyku
/// uygulamasının pad'i aynıdır, kullanıcı hatırlamaz. Bu tasarım ikisinin arası:
/// **sabit bir doku + üstünde seyrek parıltılar.** Ezgi yok ama desen tanınabilir.
/// Görsel kimliğin (hilal ay + yıldızlar, gece gradyanı) sonik karşılığı: alttaki
/// pad ufuk, üstteki parıltılar yıldız.
///
/// **SAĞLIK İDDİASI YOK (CLAUDE.md §1.1).** Frekanslar ESTETİK gerekçeyle seçildi:
/// `f0 = 130.81 Hz` (C3, eşit tampere) ve katları. "Şifa frekansı", "beyin dalgası"
/// gibi bir çerçeve BİLİNÇLİ OLARAK kullanılmadı — rakip tam orada konumlanıyor ve
/// o iddia hem yanlış hem mağaza riski. Bu ses güzel olmak için var, tedavi için değil.
///
/// **Parıltı perdeleri pad'in harmonik serisinden** (`m·f0`, m ∈ {8,12,16,20,24}):
/// seed ne olursa olsun disonans imkânsız — rastgelelik yalnız ZAMANLAMADA.
///
/// **Kırpma yapısal olarak imkânsız:** |out| ≤ 0.351 (pad) + 0.2625 (shimmer) +
/// 0.035 (hava) = 0.6485. Sondaki `clamp` bir emniyet değil; tetiklenirse bug'dır.
///
/// ⚠️ **Bu kod sesin DOĞRU olduğunu kanıtlar, GÜZEL olduğunu kanıtlamaz.** Kalite
/// yargısı kulaklıkla insana aittir (§1.1) — ışıklar kapalı, hoparlörde ve kulaklıkta
/// ayrı ayrı dinlenmeden "çalışıyor" denemez.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'dc_blocker.dart';
import 'lcg.dart';
import 'noise.dart';

/// Örnekleme hızı (Hz).
const int signatureSampleRate = 48000;

/// Toplam süre (sn). Splash'ı aşabilir: bu bir splash sesi değil, açılış atmosferi.
const double signatureSeconds = 3.6;

/// Temel frekans (Hz) — C3, eşit tampere. Estetik seçim (bkz. sınıf notu).
const double signatureF0 = 130.81;

/// Zarfın yükseliş süresi (sn). **PUBLIC ÇÜNKÜ GÖRSEL DE BUNU KULLANIYOR:**
/// açılış animasyonu (`core/launch/`) bu sabitleri KOPYALAMADAN import eder —
/// kopyalasaydık ses ve görsel ileride sessizce ayrışırdı (`ambient_phase.dart`
/// ile aynı gerekçe).
const double signatureAttackSeconds = 0.60;

/// Zarfın sönüş süresi (sn).
const double signatureReleaseSeconds = 1.40;

/// Tilt (gökyüzünün açılması) süresi (sn).
const double signatureTiltSeconds = 1.60;

/// Parıltı tanesinin sönüm zaman sabiti (sn) — görsel parıltı da bunu kullanır.
const double signatureGrainDecay = 0.55;

const double _grainAttack = 0.015;

/// Master zarf: **yükseltilmiş kosinüs** → uçlarda hem değer hem türev sıfır,
/// tık imkânsız. `t` saniye; [0,1] döner ve aralık dışında 0'a sabitlenir.
///
/// Ses üretim döngüsü ile açılış animasyonu bu TEK fonksiyonu paylaşır.
double signatureEnvelopeAt(double t) {
  if (t <= 0 || t >= signatureSeconds) return 0;
  if (t < signatureAttackSeconds) {
    return 0.5 - 0.5 * math.cos(math.pi * t / signatureAttackSeconds);
  }
  if (t <= signatureSeconds - signatureReleaseSeconds) return 1;
  return 0.5 +
      0.5 *
          math.cos(
            math.pi *
                (t - (signatureSeconds - signatureReleaseSeconds)) /
                signatureReleaseSeconds,
          );
}

/// Tilt eğrisi: gökyüzü yavaşça açılır (smoothstep). 0.35 → 1.00.
double signatureTiltAt(double t) {
  final x = (t / signatureTiltSeconds).clamp(0.0, 1.0);
  return 0.35 + 0.65 * (x * x * (3 - 2 * x));
}

/// Tek bir parıltı tanesi: ne zaman, hangi perdede, ne kadar parlak.
class SignatureGrain {
  const SignatureGrain({
    required this.onset,
    required this.multiple,
    required this.amp,
  });

  /// Başlangıç anı (sn, buffer başından).
  final double onset;

  /// f0'ın kaçıncı katı (yalnız tam katlar → disonans imkânsız).
  final int multiple;

  /// Genlik çarpanı [0.55, 1.00].
  final double amp;
}

/// Parıltıların zamanlamasını üretir — **sesin kendisini üretmeden**.
///
/// `noctaSignature` bunu kullanır; açılış animasyonu da aynı listeyi ister ve
/// yıldızlarını TAM OLARAK sesin parıldadığı anlarda parlatır. Lcg çekim SIRASI
/// burada kilitli: değiştirilirse ses de değişir.
List<SignatureGrain> signatureGrains({int seed = 1308}) {
  final rng = Lcg(seed);
  final grains = <SignatureGrain>[];
  final onsets = <double>[];
  final mults = <int>[];
  final amps = <double>[];
  var onset = 0.70;
  var previous = -1;
  while (onset <= signatureSeconds - 0.50) {
    var idx = (((rng.nextBipolar() + 1) / 2) * _shimmerMultiples.length).floor();
    if (idx >= _shimmerMultiples.length) idx = _shimmerMultiples.length - 1;
    var m = _shimmerMultiples[idx];
    // Aynı perde arka arkaya gelmesin (desen "takılmış" duyulur).
    if (m == previous) m = _shimmerMultiples[(idx + 1) % _shimmerMultiples.length];
    previous = m;

    final u = rng.nextRange(0.55, 1.00);
    final ioi = rng.nextRange(0.36, 0.88);

    onsets.add(onset);
    mults.add(m);
    amps.add(u);
    onset += ioi;
  }
  // Örüntüyü SON adımda kır: eşit aralıklı parıltı metronom gibi duyulur; son
  // parıltının geç ve tam parlak gelmesi deseni akılda kalıcı yapan tek jesttir.
  if (onsets.isNotEmpty) {
    final last = onsets.length - 1;
    if (onsets[last] + 0.12 <= signatureSeconds - 0.38) {
      onsets[last] += 0.12;
      amps[last] = 1.0;
    }
  }
  for (var i = 0; i < onsets.length; i++) {
    grains.add(SignatureGrain(onset: onsets[i], multiple: mults[i], amp: amps[i]));
  }
  return grains;
}

/// Pad kısmi tonları: (oran, ağırlık, detune Hz).
/// Ağırlık toplamı **tam 1.00** — kırpma ispatı buna dayanır, değiştirilemez.
/// Detune'lar sabit **Hz** (cent değil: cent'te vuru hızı frekansla ölçeklenir ve
/// üst partial'da vibrato gibi duyulur) ve birbirinin katı DEĞİL (17,23,29,37,41)
/// → ortak periyot 3.6 sn'ye sığmaz, ses kendini tekrar etmez.
const List<List<double>> _padPartials = <List<double>>[
  <double>[1.0, 0.30, 0.17], // gövde (kulaklıkta; hoparlörde duyulmaz — kasıtlı)
  <double>[1.5, 0.18, 0.23], // beşli
  <double>[2.0, 0.24, 0.29], // hoparlörün duymaya başladığı ilk bant
  <double>[3.0, 0.16, 0.37], // parlaklık
  <double>[4.0, 0.12, 0.41], // üst renk
];

const double _padAmp = 0.26;
const double _detuneGain = 0.35;

/// Parıltı perdeleri: yalnız f0'ın tam katları → disonans imkânsız.
const List<int> _shimmerMultiples = <int>[8, 12, 16, 20, 24];
const double _shimmerAmp = 0.14;

const double _airAmp = 0.03;

/// Üretilen parıltı sayısı (test #16 bunu bekler: 4–6).
int lastSignatureGrainCount = 0;

/// Açılış imzası — Float32, [-1,1], mono.
///
/// **Ağır iş:** ~2.3M `sin()`. UI isolate'inde çağrılırsa açılışta görünür donma
/// olur — çağıran `compute()` ile ayrı isolate'e almalıdır.
Float32List noctaSignature({
  int sampleRate = signatureSampleRate,
  int seed = 1308,
}) {
  final int n = (signatureSeconds * sampleRate).round();
  final out = Float32List(n);

  // ── Parıltı zamanlaması: Lcg çekim SIRASI kilitli (golden'ın belkemiği) ──
  // Tek kaynak `signatureGrains` — görsel açılış da AYNI listeyi okur.
  final grains = signatureGrains(seed: seed);
  lastSignatureGrainCount = grains.length;

  // ── Hava katmanı: mevcut pinkNoise + mevcut DcBlocker (yeni HP YAZMA) ──
  final air = pinkNoise(n, seed: seed ^ 0x5EED);
  DcBlocker().process(air);

  final twoPi = 2 * math.pi;
  for (var i = 0; i < n; i++) {
    final t = i / sampleRate;

    // Master zarf ve tilt: görselle PAYLAŞILAN fonksiyonlar (bkz. dosya başı).
    final env = signatureEnvelopeAt(t);
    final tilt = signatureTiltAt(t);

    var pad = 0.0;
    for (var k = 0; k < _padPartials.length; k++) {
      final f = signatureF0 * _padPartials[k][0];
      final w = _padPartials[k][1] * (k >= 3 ? tilt : 1.0);
      final d = _padPartials[k][2];
      pad += w * (math.sin(twoPi * f * t) + _detuneGain * math.sin(twoPi * (f + d) * t));
    }
    pad *= _padAmp;

    var shimmer = 0.0;
    for (var j = 0; j < grains.length; j++) {
      final g = grains[j];
      final u = t - g.onset;
      if (u < 0 || u > 4 * signatureGrainDecay) continue;
      final e = (1 - math.exp(-u / _grainAttack)) * math.exp(-u / signatureGrainDecay);
      final gain = _shimmerAmp * g.amp * math.sqrt(8 / g.multiple);
      shimmer += gain * e * math.sin(twoPi * g.multiple * signatureF0 * u);
    }

    // clamp bir EMNİYET değil: yapısal sınır 0.6485, tetiklenirse bug'dır.
    out[i] = (env * (pad + shimmer + _airAmp * air[i])).clamp(-1.0, 1.0);
  }
  return out;
}
