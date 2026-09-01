/// **Malzeme sesleri** — ceramic (seramik) + chimes (rüzgar çanı).
///
/// Neden ayrı modül (meditative.dart değil): bu kaynaklar gürültü tabanlı değil,
/// **modal rezonans** tabanlıdır. Her biri bir fiziksel nesnenin titreşim modları
/// ile sentezlenir → noise yatağı yoktur, spektral imzası keskin ve ayırt edicidir.
///
/// SAĞLIK İDDİASI YOK (§1.1): frekans oranları fizik (küre/çubuk) ve estetik seçimdir.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'lcg.dart';
import 'meditative.dart' show loopLockedHz, loopLockedPeriod;

// ─────────────────────────── ortak yardımcı ───────────────────────────

double _osc(double phase) => math.sin(phase);

// ─────────────────────────── ceramic ───────────────────────────

/// Küresel kabuk mod oranları (seramik top → içi boş küreyakın). İlk mod = 1.0.
const List<double> _ceramicRatios = [1.0, 1.59, 2.14, 2.84, 3.47];

/// Taban frekans: D3 (~146.8 Hz). Seramik yuvarlanma için ne çok pes ne tiz.
const double _ceramicF0 = 146.83;

/// Roll süresi (hedef). Döngüye kilitlenir.
const double _ceramicRollSeconds = 6.0;

/// Sürtünme tınısı için dar bant gürültü süresi.
const double _ceramicScrubSeconds = 0.55;

/// |çıkış| ≤ 0.62 . Kanıt: 5 mod ×0.18 ağırlık toplam 0.9, zarf ≤1, sin ≤1 → 0.9×0.62≈0.56 + scrub 0.06
const double ceramicPeakBound = 0.62;

Float32List ceramicSource(
  int samples, {
  required int seed,
  required int sampleRate,
  required int loopSamples,
}) {
  final loopSeconds = loopSamples / sampleRate;
  final rollPeriod = loopLockedPeriod(_ceramicRollSeconds, loopSeconds);

  // Mod frekansları döngüye kilitli → periyodik.
  final freqs = _ceramicRatios.map((r) => loopLockedHz(_ceramicF0 * r, loopSeconds)).toList();
  // Mod ağırlıkları: ilk mod baskın, üst modlar sönük (seramik tok ses).
  const weights = [0.38, 0.22, 0.18, 0.12, 0.10];

  final out = Float32List(samples);
  final twoPi = 2 * math.pi;

  // 1. Roll: yavaş genlik + hafif frekans wobble (yuvarlanma pürüzü)
  for (var i = 0; i < samples; i++) {
    final t = i / sampleRate;
    final rollEnv = 0.65 + 0.35 * (0.5 - 0.5 * math.cos(twoPi * t / rollPeriod));
    // Topun dönüş hızındaki mikro değişim → faz modülasyonu (≤ 0.08 rad)
    final wobble = 0.08 * math.sin(twoPi * 0.37 * t);
    var v = 0.0;
    for (var k = 0; k < freqs.length; k++) {
      final ph = twoPi * freqs[k] * t + wobble * (k + 1);
      v += weights[k] * _osc(ph);
    }
    // Roll zarfı ve genel seviye
    out[i] = 0.58 * rollEnv * v;
  }

  // 2. Scrub transientleri: kısa sürtünme pırıltıları (üst modlarda).
  final rng = Lcg(seed ^ 0xC3A11);
  final tail = _ceramicScrubSeconds;
  var t = 0.7;
  while (t + tail <= loopSeconds) {
    if (t * sampleRate >= samples) break;
    final start = (t * sampleRate).round();
    final amp = 0.18 + rng.nextRange(0, 0.22);
    final modeIdx = 2 + (rng.nextRange(0, 1) * 3).floor() % 3; // üst modlar
    final f = freqs[modeIdx];
    final end = math.min(samples, start + (tail * sampleRate).round());
    for (var i = start; i < end; i++) {
      final u = (i - start) / sampleRate;
      final env = math.exp(-u / 0.18) * (1 - math.exp(-u / 0.012));
      out[i] += amp * 0.14 * env * math.sin(twoPi * f * (i - start) / sampleRate);
    }
    t += 1.8 + rng.nextRange(0, 2.4);
  }

  return out;
}

// ─────────────────────────── chimes ───────────────────────────

/// Çubuk/ boru mod oranları (bambu/metal rüzgar çanı). İlk mod = 1.0.
const List<double> _chimeRatios = [1.0, 2.76, 5.40, 8.93, 13.34];

/// Taban: G3 (~196 Hz). Rüzgar çanı parlak ama kulak tırmalamaz.
const double _chimeF0 = 196.0;

const double _chimeDecay = 1.45;
const double _chimeTail = 4 * _chimeDecay;

const double chimesPeakBound = 0.58;

Float32List chimesSource(
  int samples, {
  required int seed,
  required int sampleRate,
  required int loopSamples,
}) {
  final loopSeconds = loopSamples / sampleRate;
  // Her çan vuruşu kendi mod seti ile söner — üst üste binmeme için ioi ≥ tail.
  final rng = Lcg(seed ^ 0xC117E5);
  final out = Float32List(samples);
  final twoPi = 2 * math.pi;

  // Zamanlama: seyrek, düzensiz rüzgar tetiklemesi (2.5–6.5 sn aralık, guard'lı)
  var t = 1.2;
  final tailSec = _chimeTail;
  while (t + tailSec <= loopSeconds) {
    if (t * sampleRate >= samples) break;
    final start = (t * sampleRate).round();
    final amp = 0.42 + rng.nextRange(0, 0.38);
    // Rastgele transpozisyon: ±7 yarım ses (doğal rüzgar çeşitliliği, disonans yok çünkü tek çan)
    final detuneSemi = (rng.nextRange(-1, 1) * 7).round();
    final semiRatio = math.pow(2, detuneSemi / 12).toDouble();
    final freqs = _chimeRatios.map((r) => loopLockedHz(_chimeF0 * semiRatio * r, loopSeconds)).toList();
    const weights = [0.46, 0.24, 0.14, 0.10, 0.06];
    final end = math.min(samples, start + (tailSec * sampleRate).round());
    for (var i = start; i < end; i++) {
      final u = (i - start) / sampleRate;
      final env = math.exp(-u / _chimeDecay);
      var v = 0.0;
      for (var k = 0; k < freqs.length; k++) {
        v += weights[k] * math.sin(twoPi * freqs[k] * (i - start) / sampleRate);
      }
      out[i] += amp * 0.52 * env * v;
    }
    t += 2.8 + rng.nextRange(0, 3.2);
  }

  return out;
}

// ─────────────────────────── topSpin ───────────────────────────

/// Topaç — dönen konik kütlenin vızıltısı + presesyon yalpası.
/// Taban ~320 Hz, harmonics 1.0/1.48/2.04/2.91 (ahşap topaç pürüzlü, inharmonik değil).
const double _topF0 = 318.0;
const double _topSpinSeconds = 7.5;
const double topSpinPeakBound = 0.55;

Float32List topSpinSource(
  int samples, {
  required int seed,
  required int sampleRate,
  required int loopSamples,
}) {
  final loopSeconds = loopSamples / sampleRate;
  final period = loopLockedPeriod(_topSpinSeconds, loopSeconds);
  final freqs = [1.0, 1.48, 2.04, 2.91].map((r) => loopLockedHz(_topF0 * r, loopSeconds)).toList();
  const weights = [0.42, 0.24, 0.18, 0.16];
  final out = Float32List(samples);
  final twoPi = 2 * math.pi;
  for (var i = 0; i < samples; i++) {
    final t = i / sampleRate;
    // Dönüş yavaşlama zarfı: 1.0 → 0.65, periyodik (topaç düşer, sonra tekrar fırlatılır gibi döngüsel)
    final spinEnv = 0.65 + 0.35 * (0.5 + 0.5 * math.cos(twoPi * t / period));
    // Presesyon yalpası: 0.6 Hz, faz modülasyonu 0.12 rad (masa üstünde yalpalama)
    final wobble = 0.12 * math.sin(twoPi * 0.62 * t);
    // Sürtünme hışırtısı: çok hafif, yüksek frekansın genliğini modüle eder
    final hiss = 0.04 * math.sin(twoPi * 11.3 * t);
    var v = 0.0;
    for (var k = 0; k < freqs.length; k++) {
      v += weights[k] * math.sin(twoPi * freqs[k] * t + wobble * (k + 1));
    }
    out[i] = (0.52 * spinEnv + hiss) * v;
  }
  return out;
}

// ─────────────────────────── friction ───────────────────────────

/// Seramik sürtme — iki topun yavaş, ritmik birbirine sürtmesi.
/// Taban: kahverengi gürültünün 180–520 Hz bandı + 0.22 Hz el hareketi + grit transient.
const double _frictionBandLoA = 0.011; // ~85 Hz high-pass
const double _frictionBandHiA = 0.065; // ~500 Hz low-pass
const double frictionPeakBound = 0.60;

Float32List frictionSource(
  int samples, {
  required int seed,
  required int sampleRate,
  required int loopSamples,
}) {
  final loopSeconds = loopSamples / sampleRate;
  // Ham brown yatak
  final raw = Float32List(samples);
  var brown = 0.0;
  final rngRaw = Lcg(seed ^ 0xF71C710);
  for (var i = 0; i < samples; i++) {
    final w = rngRaw.nextRange(-1, 1);
    brown += 0.018 * (w - brown);
    raw[i] = brown;
  }
  // Band-pass: hi - lo
  final out = Float32List(samples);
  var lo = 0.0, hi = 0.0;
  final twoPi = 2 * math.pi;
  for (var i = 0; i < samples; i++) {
    final x = raw[i];
    hi += _frictionBandHiA * (x - hi);
    lo += _frictionBandLoA * (x - lo);
    final band = 0.5 * (hi - lo); // |band| ≤ 1
    final t = i / sampleRate;
    // El hareketi: 0.22 Hz, 0.45–1.0 arası (avuç içi daire çiziyor)
    final hand = 0.45 + 0.55 * (0.5 + 0.5 * math.sin(twoPi * 0.22 * t + 0.7));
    // Grit: el hızının tepe yaptığı yerde hafif pürüz
    final gritEnv = math.pow(hand, 3).toDouble();
    out[i] = 0.58 * hand * band + 0.08 * gritEnv * band;
  }
  // Arada 1.2–2.8 sn’de bir 18 ms’lik grit tıklaması (pürüzlü nokta)
  final rng = Lcg(seed ^ 0xF71C);
  var t = 1.1;
  while (t + 0.018 <= loopSeconds) {
    final start = (t * sampleRate).round();
    final amp = 0.10 + rng.nextRange(0, 0.12);
    final end = math.min(samples, start + (0.018 * sampleRate).round());
    for (var i = start; i < end; i++) {
      final u = (i - start) / sampleRate;
      final env = math.exp(-u / 0.006) * (1 - math.exp(-u / 0.001));
      // Grit taşıyıcısı: 520 Hz civarı kısa sinüs, band ile karışır
      final f = loopLockedHz(520 + (rng.nextRange(-1, 1) * 80), loopSeconds);
      out[i] += amp * env * math.sin(twoPi * f * u);
    }
    t += 1.4 + rng.nextRange(0, 1.4);
  }
  return out;
}
