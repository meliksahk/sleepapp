/// **Ambiyans faz saati** — animasyonun sesle aynı matematikten beslendiği yer.
///
/// ## Neden FFT YOK
///
/// Sesi biz üretiyoruz (`dsp/meditative.dart`). Dolayısıyla modülasyonun fazı
/// zaten elimizde: dalganın kabarma zarfı kapalı formda `0.5 − 0.5·cos(2πt/T)` ve
/// T döngüye kilitli (`loopLockedPeriod`). Çıkışı FFT ile analiz etmek, bildiğimiz
/// bir sayıyı gecikmeli ve pahalı biçimde YENİDEN keşfetmek olurdu:
/// - FFT penceresi kadar gecikme (görsel sesin arkasından gelir),
/// - kare başına O(N log N) CPU (gece boyu açık kalacak bir ekranda pil),
/// - mikrofon/çıkış tap'i gerektirir (PII yüzeyi, izin, platform riski).
///
/// Bu dosya bunun yerine **aynı sabitleri ve aynı fonksiyonu** kullanır. Görsel
/// kabarma ile duyulan kabarma böylece tanım gereği aynı fazdadır — bedava.
///
/// ## ⚠️ DÜRÜST SINIR: faz kilidi "periyot"tadır, "playhead"de DEĞİL
///
/// Buradaki t, çağıranın verdiği bir saatten gelir; `MixPlayer`'ın gerçek çalma
/// pozisyonundan DEĞİL. Yani periyot ve dalga biçimi birebir aynıdır, ama başlangıç
/// noktası (t=0) çağıranın sorumluluğudur. Ses, animasyondan önce/sonra başlarsa
/// aralarında SABİT bir ofset kalır (kayma değil — ikisi de aynı hızda ilerler).
/// Bunu sıfırlamak için `AmbientBackdrop`'a sesin başladığı anı geçirmek gerekir;
/// player pozisyonuna bağlama işi bu dosyada YAPILMADI (bkz. rapor).
library;

import 'dart:math' as math;

import '../audio_engine/dsp/meditative.dart';
import '../audio_engine/mix_player.dart';

/// Animasyonun döngü uzunluğu — **sesle aynı sabit**, kopyalanmadı.
const double ambientLoopSeconds = MixPlayer.defaultLoopSeconds * 1.0;

/// Dalga kabarma periyodu (sn) — `wavesSource` ile BİREBİR aynı hesap.
/// 30 sn'lik döngüde 10.0 sn (döngüde tam 3 çevrim).
double ambientSwellPeriod([double loopSeconds = ambientLoopSeconds]) =>
    loopLockedPeriod(wavesSwellSeconds, loopSeconds);

/// Pad nefes periyodu (sn) — `padSource` ile BİREBİR aynı hesap. 30 sn'de 15.0.
double ambientBreathPeriod([double loopSeconds = ambientLoopSeconds]) =>
    loopLockedPeriod(padBreathSeconds, loopSeconds);

/// Bir andaki görsel faz. Üç büyüklüğün de **döngü başında ve sonunda aynı**
/// olması zorunludur (yoksa animasyon 30 saniyede bir görünür şekilde sıçrar) —
/// üç periyot da döngüyü tam böldüğü için bu sağlanır.
class AmbientPhase {
  const AmbientPhase({
    required this.loop,
    required this.swell,
    required this.breath,
  });

  /// Döngüdeki konum [0,1).
  final double loop;

  /// Dalga kabarması [0,1] — `wavesSource`'un genlik zarfıyla aynı faz.
  final double swell;

  /// Pad nefesi [0,1] — `padSource`'un nefes zarfıyla aynı faz.
  final double breath;

  /// Sıfır anı — animasyon başlamadan önceki durağan kare.
  static const AmbientPhase zero =
      AmbientPhase(loop: 0, swell: 0, breath: 0);

  @override
  bool operator ==(Object other) =>
      other is AmbientPhase &&
      other.loop == loop &&
      other.swell == swell &&
      other.breath == breath;

  @override
  int get hashCode => Object.hash(loop, swell, breath);
}

/// [elapsed] anındaki fazı verir.
///
/// Zarf formülü `wavesSource`/`padSource` içindekiyle aynı: `0.5 − 0.5·cos(2πt/T)`.
AmbientPhase ambientPhaseAt(
  Duration elapsed, {
  double loopSeconds = ambientLoopSeconds,
}) {
  final t = elapsed.inMicroseconds / Duration.microsecondsPerSecond;
  const twoPi = 2 * math.pi;
  final swellPeriod = ambientSwellPeriod(loopSeconds);
  final breathPeriod = ambientBreathPeriod(loopSeconds);
  // `%` negatif t için negatif dönebilir; geriye giden bir saat beklenmiyor ama
  // sessizce bozulmasın diye normalize ediliyor.
  final loop = ((t % loopSeconds) + loopSeconds) % loopSeconds;
  return AmbientPhase(
    loop: loop / loopSeconds,
    swell: 0.5 - 0.5 * math.cos(twoPi * t / swellPeriod),
    breath: 0.5 - 0.5 * math.cos(twoPi * t / breathPeriod),
  );
}

// ─────────────────────────── mikser → görsel ───────────────────────────

/// Mikser katman id'leri — `defaultMixSpec()` ile aynı isimler.
const String _idWaves = 'waves';
const String _idPad = 'pad';
const String _idRain = 'rain';
const String _idFire = 'fire';

/// Kazançların görsele çevrilmiş hâli: kullanıcının mikserde kurduğu denge,
/// arka planın karakterini de belirler.
///
/// **Neden PAY (share), mutlak kazanç değil:** kullanıcı ana ses seviyesini
/// düşürdüğünde tüm kazançlar birlikte düşer; mutlak değer kullansaydık görsel
/// söner ve "ses kısıldı" ile "dalga katmanı kapatıldı" ayırt edilemezdi. Pay,
/// mikserin gerçek semantiği olan DENGEYİ okur.
///
/// `sqrt` eğrisi: paylar küçük sayılardır (varsayılanda dalga 0.22). Doğrusal
/// kullanırsak görsel fark neredeyse görünmez; karekök küçük payları açar ve
/// monotonluğu bozmaz (test bunu doğruluyor).
class AmbientDrive {
  const AmbientDrive({
    required this.motion,
    required this.glow,
    required this.texture,
  });

  /// Dalga katmanının payı → hareketin belirginliği [0,1].
  final double motion;

  /// Pad katmanının payı → parlaklık/sıcaklık [0,1].
  final double glow;

  /// Yağmur + ateşin payı → doku bandının yoğunluğu [0,1].
  final double texture;

  /// Hiçbir katman açık değilken (veya kazanç bilgisi yokken) kullanılan durgun
  /// sürüş. Sıfır değil: arka plan yine de yaşamalı, yalnızca sakin olmalı.
  static const AmbientDrive calm =
      AmbientDrive(motion: 0.35, glow: 0.35, texture: 0.2);

  /// `MixerState.gains` → görsel parametreler.
  factory AmbientDrive.fromGains(Map<String, double> gains) {
    if (gains.isEmpty) return calm;
    var total = 0.0;
    for (final g in gains.values) {
      if (g > 0) total += g;
    }
    // Tüm katmanlar kapalı: sesin olmadığı yerde "ses var" izlenimi vermeyelim,
    // ama ekran da ölmesin → sakin varsayılan.
    if (total <= 0) return calm;

    double share(String id) {
      final g = gains[id] ?? 0;
      if (g <= 0) return 0;
      return math.sqrt(g / total).clamp(0.0, 1.0);
    }

    final rain = gains[_idRain] ?? 0;
    final fire = gains[_idFire] ?? 0;
    final tex = math.max(0.0, rain) + math.max(0.0, fire);

    return AmbientDrive(
      motion: share(_idWaves),
      glow: share(_idPad),
      texture: math.sqrt(tex / total).clamp(0.0, 1.0),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AmbientDrive &&
      other.motion == motion &&
      other.glow == glow &&
      other.texture == texture;

  @override
  int get hashCode => Object.hash(motion, glow, texture);
}
