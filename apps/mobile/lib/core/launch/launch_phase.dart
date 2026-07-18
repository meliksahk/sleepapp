/// **Açılış anının faz saati** — ayın sesle aynı matematikten beslendiği yer.
///
/// ## Neden burası önemli
///
/// Açılışta zaten bir ses çalıyor: `dsp/nocta_signature.dart` (aura). O sesin
/// zarfı kapalı formda biliniyor. Ayın canlanması bu zarfı KOPYALAMADAN import
/// eder — `ambient_phase.dart` ile birebir aynı desen. Sabit kopyalasaydık iki
/// taraf ileride sessizce ayrışırdı: ses güncellenir, animasyon eski eğride kalır
/// ve kimse fark etmez (iki test de "geçer" ama artık aynı şeyi ölçmezler).
///
/// Somut kazanç: ses yükselirken ay canlanır, ses sönerken ay dinginleşir —
/// ve yıldızlar TAM OLARAK sesin parıldadığı anlarda parlar (`signatureGrains`).
///
/// ## ⚠️ DÜRÜST SINIR: faz kilidi "eğri"dedir, "playhead"de DEĞİL
///
/// Buradaki t, widget'ın kendi saatinden gelir; `SignaturePlayer`'ın gerçek çalma
/// pozisyonundan DEĞİL. Eğri ve süreler birebir aynıdır, ama t=0 anları arasında
/// SABİT bir ofset kalır: ses `compute()` ile ayrı isolate'te üretilip player'a
/// yüklendikten sonra başlar (ölçülmedi; onlarca–yüzlerce ms mertebesinde
/// beklenir). Kayma değil, sabit gecikme — ikisi de aynı hızda ilerler. Zarfın
/// ilk 100 ms'i zaten neredeyse sessiz olduğu için bu ofset tolere edilebilir
/// kabul edildi; playhead'e bağlama YAPILMADI (bkz. rapor).
library;

import 'dart:math' as math;

import '../audio_engine/dsp/nocta_signature.dart';

/// Açılış anının **üst sınırı** (sn).
///
/// **Neden bir üst sınır var:** aura 3.6 sn. Kullanıcıyı uygulamaya girmek için
/// 3.6 sn bekletmek bir açılış anı değil, bir vergidir — hele her açılışta.
/// Ses kesilmez (arka planda çalmaya devam eder), yalnızca GÖRSEL kapı kalkar.
///
/// **Neden 2.2:** zarfın tepe noktası (attack 0.60 sn) çoktan geçilmiş, ilk 3–4
/// parıltı (0.70 sn'den itibaren) görülmüş, ve sönüş başlamıştır. Yani markanın
/// jesti TAMAMLANMIŞ olur. 2.4'ün üstü "yavaş uygulama" hissi verir, 2.0'ın altı
/// parıltıların yarısını kesip deseni tanınmaz kılar.
const double launchCapSeconds = 2.2;

/// Açılış anının **alt sınırı** (sn) — içerik hazırsa bile bu kadar durulur.
///
/// **Neden bir alt sınır var:** oturum önbellekten gelirse bootstrap ~50 ms'de
/// biter. Alt sınır olmasaydı kullanıcı ayı HİÇ görmezdi; geriye bir kare
/// titreme kalırdı — sıfır splash'tan daha kötü.
///
/// **Neden 1.1:** zarfın yükselişi (0.60) + ilk parıltı (0.70) + o parıltının
/// görülecek kadar sönmesi. Yani "ay doğdu ve bir yıldız parladı" cümlesinin
/// tamamlandığı en erken an.
///
/// Kullanıcı yine de beklemek ZORUNDA değil: dokunuş bu sınırı atlar.
const double launchHoldSeconds = 1.1;

/// Splash → ana ekran mikroanimasyonunun süresi.
///
/// 320 ms: mikro aralığın (250–400) ortası. Altında geçiş "sert kesme" gibi
/// okunur, üstünde kullanıcı beklediğini fark etmeye başlar.
const Duration launchExitDuration = Duration(milliseconds: 320);

/// Görsel parıltının yükseliş sabiti (sn).
///
/// **Sesteki 15 ms BİLEREK kullanılmadı:** 60 fps'te bir kare 16.7 ms — 15 ms'lik
/// bir yükseliş tek karede biter, yani "yükseliş" diye bir şey görünmez, yıldız
/// tak diye açılır. Sönüm ([signatureGrainDecay]) sesle BİREBİR aynı; yalnızca
/// göz için görünmez olan yükseliş kısmı uzatıldı.
const double launchSparkleAttack = 0.08;

/// Bir andaki açılış fazı.
class LaunchPhase {
  const LaunchPhase({
    required this.t,
    required this.glow,
    required this.open,
    required this.sparkles,
  });

  /// Açılış başından geçen süre (sn).
  final double t;

  /// Aura zarfı [0,1] — `signatureEnvelopeAt` ile BİREBİR aynı değer.
  final double glow;

  /// Tilt [0.35,1] — `signatureTiltAt` ile birebir aynı ("gökyüzü açılıyor").
  final double open;

  /// Yıldız başına anlık parlaklık [0,1]. Uzunluk = `signatureGrains().length`
  /// (bu seed'de 4–6); sırası da aynı.
  final List<double> sparkles;

  /// Açılış başlamadan önceki durağan kare — hiçbir şey görünmez.
  static const LaunchPhase zero =
      LaunchPhase(t: 0, glow: 0, open: 0.35, sparkles: <double>[]);
}

/// Parıltı zamanlaması bir kez hesaplanır: `signatureGrains` Lcg çevirir ve
/// kare başına çağrılması boşuna iştir (sonuç seed'e göre sabittir).
final List<SignatureGrain> _grains = signatureGrains();

/// Test/görsel için parıltı listesi (sesle aynı kaynak).
List<SignatureGrain> get launchGrains => List<SignatureGrain>.unmodifiable(_grains);

/// [elapsed] anındaki faz.
LaunchPhase launchPhaseAt(Duration elapsed) {
  final t = elapsed.inMicroseconds / Duration.microsecondsPerSecond;
  final sparkles = <double>[];
  for (final g in _grains) {
    final u = t - g.onset;
    if (u < 0 || u > 4 * signatureGrainDecay) {
      sparkles.add(0);
      continue;
    }
    // Sesteki tane zarfının aynısı (yalnız yükseliş sabiti göz için uzatıldı),
    // sesteki `sqrt(8/m)` kazanç yasasıyla ölçeklenmiş: pes parıltı büyük ve
    // parlak, tiz parıltı küçük ve soluk — duyulanla görülen aynı ağırlıkta.
    final e = (1 - math.exp(-u / launchSparkleAttack)) *
        math.exp(-u / signatureGrainDecay);
    sparkles.add((e * g.amp * math.sqrt(8 / g.multiple)).clamp(0.0, 1.0));
  }
  return LaunchPhase(
    t: t,
    glow: signatureEnvelopeAt(t),
    open: signatureTiltAt(t),
    sparkles: sparkles,
  );
}
