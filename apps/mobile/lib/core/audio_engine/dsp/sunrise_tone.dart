/// Akıllı alarmın sesi — **cihazda üretilir, asset yok** (docs/04 §86 "sunrise rampası").
///
/// **Neden üretiliyor, neden ses dosyası değil:** CLAUDE.md §1.1 varsayılanı
/// "on-device / free tier". Bir mp3 eklemek APK'yı şişirir, lisans sorusu doğurur ve
/// zaten elimizde çalışan bir DSP zinciri var. ~40 satır, bayt seviyesinde test
/// edilebilir.
///
/// **Neden çan, neden bip değil:** bu bir uyku uygulaması. Sert bir bip kullanıcıyı
/// panikle uyandırır; ürünün tüm vaadi "ritüel". Çan = temel + beşli, üstel sönüm.
///
/// **Neden rampa:** ses sıfırdan başlar ve [rampSeconds] boyunca yükselir. Alarm ilk
/// saniyede tam sesle patlarsa "akıllı" kısmın hiçbir anlamı kalmaz — hafif uykuda
/// yakalayıp yine de şoklamak olurdu.
///
/// **DÜRÜSTLÜK — rampa bir SÖZ DEĞİL:** rampa uyandırmayı geciktirmez, yalnızca
/// yumuşatır; kullanıcı ilk çanda da uyanabilir. "Nazikçe uyandırır" bir tasarım
/// tercihidir, kanıtlanmış bir etki değil (CLAUDE.md §1.1: sağlık iddiası yok).
library;

import 'dart:math' as math;
import 'dart:typed_data';

/// Çanlar arası süre. 2 sn: ısrarcı ama telaşsız.
const Duration chimeInterval = Duration(seconds: 2);

/// Çanın temel frekansı (Hz) — **C5, eşit tampere** (A440 sistemi).
///
/// **Neden 528'den çekildi (uyum kararı, ses kararı değil):** 528 Hz duyulabilirlik
/// açısından iyiydi ama aynı zamanda "şifa frekansı / mucize tonu" pazarlamasının
/// İMZA SAYISIDIR ve doğrudan rakibimiz orada konumlanıyor ("science-backed",
/// "tinnitus relief"). O sayıyı kullanmak, hiçbir iddiada bulunmasak bile bizi o
/// söylemin yanına koyar — CLAUDE.md §1.1'in kapatmak istediği yüzey tam bu.
///
/// 523.25 kulakla ayırt edilemeyecek kadar yakın (~15 cent) ama gerekçesi
/// tamamen müzikal: C5, ve açılış imzasının (`nocta_signature.dart`, f0=130.81 C3)
/// tam 4. harmoniği → alarm ile marka sesi aynı armonik ailede.
const double chimeFundamentalHz = 523.25;

/// [seconds] saniyelik alarm sesi (Float32, [-1, 1], mono).
///
/// Ses [rampSeconds] boyunca 0'dan tam seviyeye çıkar, sonra sabit kalır.
Float32List sunriseTone({
  required int seconds,
  int sampleRate = 48000,
  int rampSeconds = 30,
}) {
  assert(seconds > 0);
  assert(sampleRate > 0);
  assert(rampSeconds >= 0);

  final total = seconds * sampleRate;
  final out = Float32List(total);
  final chimeSamples = chimeInterval.inMicroseconds * sampleRate ~/ 1000000;
  final rampSamples = rampSeconds * sampleRate;

  for (var i = 0; i < total; i++) {
    // Rampa: 0 → 1. rampSeconds 0 ise ilk örnekten tam seviye.
    final ramp = rampSamples == 0 ? 1.0 : math.min(1.0, i / rampSamples);

    // Çan içindeki konum → üstel sönüm (gerçek bir çan gibi: vur, sön).
    final n = i % chimeSamples;
    final t = n / sampleRate;
    final decay = math.exp(-3.0 * t);

    final phase = 2 * math.pi * chimeFundamentalHz * t;
    // Temel + beşli (3/2). Beşli yarı genlikte: çanı tizleştirmeden zenginleştirir.
    final tone = math.sin(phase) + 0.5 * math.sin(phase * 1.5);

    // 0.4: temel+beşli tepe 1.5'e ulaşabilir; 0.4 ile çarpım 0.6 tepe verir →
    // kırpma YOK ve alarm için yeterince yüksek (cihaz sesi zaten kullanıcıda).
    out[i] = (0.4 * ramp * decay * tone).clamp(-1.0, 1.0);
  }
  return out;
}
