/// **Akor progresyonu + arpej** — uyku ritüeli için melodik jeneratif kaynak.
///
/// İki yeni sentez kaynağı:
/// - `chords`: yavaş akor progresyonu (Am→F→C→G), pad benzeri sıcak dokular
/// - `arpeggio`: pentatonik ölçekte yukarı-aşağı gezinen yumuşak arpej
///
/// ## SAĞLIK İDDİASI YOK (CLAUDE.md §1.1)
/// Akor seçimi MÜZİKALDİR: A minör doğal tonalite, uyku müziğinin klasik
/// harmonik dilidir. Hiçbir akorun "rahatlatıcı" veya "şifalı" iddiası yoktur.
///
/// ## DÖNGÜ KİLİDİ — pazarlıksız kural
/// Her akor süresi ve her arpej adımı döngü ızgarasına oturtulur. Pad ile aynı
/// mekanizma (`loopLockedHz`, `loopLockedPeriod`).
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'lcg.dart';
import 'meditative.dart' show loopLockedHz, loopLockedPeriod;

// ─────────────────────────── ortak müzikal sabitler ───────────────────────────

/// A2 = 110 Hz (referans). Tüm akor/arpej frekansları bunun katlarıdır.
const double _a2Hz = 110.0;

/// Yarı ses katsayısı: eşit tampere'de bir yarım ses yukarı = ×2^(1/12).
/// (const DEĞİL: math.pow const-eval desteklemez; değer 1.0594630943592953)
final double _semitone = math.pow(2, 1 / 12).toDouble();

/// Notaların A2'den yarım-ses uzaklığı:
/// A2=0, B2=2, C3=3, D3=5, E3=7, F3=8, G3=10, A3=12 ...
double _freq(int semi) => _a2Hz * math.pow(_semitone, semi);

// ─────────────────────────── chords ───────────────────────────

/// Am→F→C→G progresyonundaki akorlar (yarım-ses dizileri).
/// Her akor 3-4 notadan oluşur; kök + ters çevirme kullanılır ki geçişler yumuşak olsun.
const List<List<int>> _chordProgression = <List<int>>[
  <int>[0, 3, 7],       // Am: A C E
  <int>[8, 12, 15],     // F:  F A C  (F3=8, A3=12, C4=15)
  <int>[3, 7, 10],      // C:  C E G  (C3=3, E3=7, G3=10)
  <int>[10, 14, 17],    // G:  G B D  (G3=10, B3=14, D4=17)
];

/// Her akor kaç saniye sürer (hedef). Döngüye kilitlenir.
const double _chordDurationSec = 7.5; // 30 sn / 4 akor = 7.5 sn tam bölüyor

/// Akor zarfı: geçiş sırasında çakışma olmasın diye eski akor söner, yenisi büyür.
const double _chordFadeRatio = 0.15; // akor süresinin %15'i crossfade

const double _chordsPeakAmp = 0.22;

/// Akor progresyonu — **döngü-periyodik kaynak**.
///
/// Her akor döngüde TAM SAYIDA periyot tamamlar; akor geçişleri zarfla
/// yapılır (eski söner, yenisi büyür — aynı anda iki akor duyulur ama
/// toplam genlik ≤ [chordsPeakBound]).
Float32List chordsSource(
  int samples, {
  required int sampleRate,
  required int loopSamples,
}) {
  final loopSeconds = loopSamples / sampleRate;
  // Akor süresini ızgaraya oturt (30 sn / 4 akor = tam 7.5 sn).
  final chordDur = loopLockedPeriod(_chordDurationSec, loopSeconds);
  final chordSamples = (chordDur * sampleRate).round();
  final numChords = _chordProgression.length;
  // Toplam akor süresi döngüyü tam bölmeli.
  final totalChordSamples = chordSamples * numChords;
  if (totalChordSamples > samples) {
    // Döngü kısa → daha az akor göster (yalnızca ilk N akor).
    return _renderChordSubset(samples, sampleRate, loopSamples);
  }

  final out = Float32List(samples);
  final fadeSamples = (chordDur * _chordFadeRatio * sampleRate).round();

  for (var ci = 0; ci < numChords; ci++) {
    final start = ci * chordSamples;
    if (start >= samples) break;
    final end = math.min(start + chordSamples, samples);
    final notes = _chordProgression[ci];

    for (final note in notes) {
      final f = loopLockedHz(_freq(note), loopSeconds);
      final omega = 2 * math.pi * f / sampleRate;

      for (var i = start; i < end; i++) {
        // Zarf: akor başı/sonunda crossfade (sin² eğrisi — yumuşak).
        final local = i - start;
        var env = 1.0;
        if (local < fadeSamples) {
          env = math.sin(math.pi / 2 * local / fadeSamples);
        } else if (local > chordSamples - fadeSamples) {
          final tail = chordSamples - local;
          env = math.sin(math.pi / 2 * tail / fadeSamples);
        }
        // Bir üst harmoni ekle: temel + 2×(0.3) → daha zengin timbre.
        final v = env *
            _chordsPeakAmp /
            notes.length *
            (math.sin(omega * i) + 0.30 * math.sin(2 * omega * i));
        out[i] += v;
      }
    }
  }

  // Döngü sonu: kalan alanı sessizlik değil, baştan harmanla (periyodiklik).
  if (totalChordSamples < samples) {
    final remainingStart = totalChordSamples;
    for (var i = remainingStart; i < samples; i++) {
      out[i] = out[i - totalChordSamples];
    }
  }

  return out;
}

/// Kısa döngü için alt küme render (tek akor tekrarı).
Float32List _renderChordSubset(
  int samples,
  int sampleRate,
  int loopSamples,
) {
  final out = Float32List(samples);
  final notes = _chordProgression[0]; // yalnızca Am
  for (final note in notes) {
    final f = loopLockedHz(_freq(note), loopSamples / sampleRate);
    final omega = 2 * math.pi * f / sampleRate;
    for (var i = 0; i < samples; i++) {
      out[i] +=
          _chordsPeakAmp / notes.length * (math.sin(omega * i) + 0.3 * math.sin(2 * omega * i));
    }
  }
  return out;
}

// ─────────────────────────── arpeggio ───────────────────────────

/// Pentatonik ölçek (Am pentatonic): A C D E G — disonans imkânsız.
const List<int> _pentatonicSemitones = <int>[0, 3, 5, 7, 10];

/// Arpej adım süresi (hedef, sn). Döngüye kilitlenir.
const double _arpStepSeconds = 0.75; // ~40 adım / 30 sn döngü

const double _arpNoteAmp = 0.18;

/// Arpej zarfı: hızlı doğuş, orta sönüm — nota duymak isteyen için.
const double _arpAttack = 0.01; // 10 ms
const double _arpDecay = 0.45;  // 450 ms

/// **|çıkış| ≤ _arpNoteAmp** — tek nota her zaman duyulur, üst üste binme yok.
const double arpPeakBound = _arpNoteAmp;

/// Pentatonik arpej — **döngü-periyodik kaynak**.
///
/// Yukarı-aşağı gezinen yumuşak nota dizisi. Her nota saf sinüs + hafif üst
/// harmoni. Notalar pentatonik olduğundan disonans yapısal olarak imkânsızdır.
Float32List arpeggioSource(
  int samples, {
  required int seed,
  required int sampleRate,
  required int loopSamples,
}) {
  final loopSeconds = loopSamples / sampleRate;
  final stepDur = loopLockedPeriod(_arpStepSeconds, loopSeconds);
  final stepSamples = (stepDur * sampleRate).round();

  // Adım deseni: yukarı-aşağı (pingpong) — 0,1,2,3,4,3,2,1 = 8 adım döngüsü.
  const pattern = <int>[0, 1, 2, 3, 4, 3, 2, 1];
  final numSteps = pattern.length;

  // Toplam arpej döngüsünü hesapla ve döngü uzunluğunu tam bölen hale getir.
  final arpLoopSamples = stepSamples * numSteps;
  if (arpLoopSamples <= 0 || arpLoopSamples > samples) {
    return Float32List(samples); // çok kısa döngü → sessiz
  }

  final rng = Lcg(seed ^ 0xA9FE);
  // Oktav varyasyonu: her arpej turunda ±1 oktav rastgele kayma (ama grid'de).
  final octaveShifts = <int>[];
  final numTurs = (samples / arpLoopSamples).ceil() + 1;
  for (var t = 0; t < numTurs; t++) {
    octaveShifts.add(rng.nextBipolar() > 0 ? 12 : 0); // 0 ya da +1 oktav
  }

  final out = Float32List(samples);

  var stepIndex = 0;
  var currentOctave = 0;
  var lastTur = -1;

  for (var start = 0; start < samples; start += stepSamples) {
    final tur = start ~/ arpLoopSamples;
    if (tur != lastTur) {
      currentOctave = _turOctave(tur, octaveShifts);
      lastTur = tur;
    }

    final scaleIdx = pattern[stepIndex % numSteps];
    final semi = _pentatonicSemitones[scaleIdx] + currentOctave;
    final f = loopLockedHz(_freq(semi), loopSeconds);
    final omega = 2 * math.pi * f / sampleRate;

    final noteEnd = math.min(start + stepSamples, samples);
    for (var i = start; i < noteEnd; i++) {
      final u = (i - start) / sampleRate;
      // Zarf: hızlı attack + exponential decay
      var env = 1.0;
      if (u < _arpAttack) {
        env = u / _arpAttack;
      } else {
        env = math.exp(-(u - _arpAttack) / _arpDecay);
      }
      // Nota: temel + hafif 2. harmoni (zengin timbre)
      final v = env * _arpNoteAmp * (math.sin(omega * i) + 0.25 * math.sin(2 * omega * i));
      out[i] += v;
    }
    stepIndex++;
  }

  return out;
}

/// Tur indeksine göre oktav kayması — deterministik (seed'e bağlı).
int _turOctave(int tur, List<int> shifts) =>
    shifts[tur % shifts.length];

/// Akor + arpej kaynaklarının tepe sınırı (mikser headroom hesabı için).
const double chordsPeakBound = _chordsPeakAmp;
