/// Kullanıcı tanımlı melodik parametreler — akor/arpej kaynakları için.
///
/// Bu parametreler MixLayer'da opsiyonel alanlar olarak taşınır (mobil-özel,
/// sunucu sözleşmesi tanımaz). Kullanıcı "Akor ekle"/"Arpej ekle" dediğinde
/// bu parametrelerle özelleştirilmiş ses üretilir.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'lcg.dart';
import 'meditative.dart' show loopLockedHz, loopLockedPeriod;

// ─────────────────────────── dalga şekilleri ───────────────────────────

enum Waveform { sine, triangle, saw, square }

double _osc(Waveform wf, double phase) {
  switch (wf) {
    case Waveform.sine: return math.sin(phase);
    case Waveform.triangle:
      final t = (phase / (2 * math.pi)) % 1.0;
      return t < 0.5 ? 4 * t - 1 : 3 - 4 * t;
    case Waveform.saw:
      return 2 * ((phase / (2 * math.pi)) % 1.0) - 1;
    case Waveform.square:
      return math.sin(phase) >= 0 ? 1.0 : -1.0;
  }
}

// ─────────────────────────── notalar ───────────────────────────

const double _a2 = 110.0;
final double _semiRatio = math.pow(2, 1 / 12).toDouble();

double _freq(int semi) => _a2 * math.pow(_semiRatio, semi);

/// Nota adları — UI'da gösterilir.
const List<String> noteNames = [
  'A','A♯','B','C','C♯','D','D♯','E','F','F♯','G','G♯',
];

String noteName(int semi) {
  final octave = 2 + ((semi + 9) ~/ 12); // A2'den itibaren
  final idx = semi % 12;
  return '${noteNames[idx]}$octave';
}

// ─────────────────────────── ölçekler ───────────────────────────

class MelodicScale {
  const MelodicScale(this.name, this.semitones);
  final String name;
  final List<int> semitones;
}

const melodicScales = <MelodicScale>[
  MelodicScale('Pentatonik', [0, 3, 5, 7, 10]),
  MelodicScale('Majör', [0, 2, 4, 5, 7, 9, 11]),
  MelodicScale('Minör', [0, 2, 3, 5, 7, 8, 10]),
  MelodicScale('Dorian', [0, 2, 3, 5, 7, 9, 10]),
  MelodicScale('Frygian', [0, 1, 3, 5, 7, 8, 10]),
  MelodicScale('Lydian', [0, 2, 4, 6, 7, 9, 11]),
  MelodicScale('Mixolydian', [0, 2, 4, 5, 7, 9, 10]),
  MelodicScale('Harmonic Minör', [0, 2, 3, 5, 7, 8, 11]),
  MelodicScale('Blues', [0, 3, 5, 6, 7, 10]),
];

// ─────────────────────────── akor progresyonları ───────────────────────────

class ChordProgression {
  const ChordProgression(this.name, this.chords);
  final String name;
  /// Her akor kök yarım-ses ofseti + akor tipi (minör=[0,3,7], majör=[0,4,7]).
  final List<List<int>> chords;
}

const chordProgressions = <ChordProgression>[
  ChordProgression('Am→F→C→G', [[0,3,7],[8,12,15],[3,7,10],[10,14,17]]),
  ChordProgression('Am→G→F→E', [[0,3,7],[10,14,17],[8,12,15],[7,11,14]]),
  ChordProgression('C→Am→F→G', [[3,7,10],[0,3,7],[8,12,15],[10,14,17]]),
  ChordProgression('Am→Dm→E→Am', [[0,3,7],[5,8,12],[7,11,14],[0,3,7]]),
  ChordProgression('C→G→Am→F', [[3,7,10],[10,14,17],[0,3,7],[8,12,15]]),
  ChordProgression('Em→Am→Dm→G', [[7,11,14],[0,3,7],[5,8,12],[10,14,17]]),
  ChordProgression('Dm→G→C→F', [[5,8,12],[10,14,17],[3,7,10],[8,12,15]]),
  ChordProgression('Am→F→G→Em', [[0,3,7],[8,12,15],[10,14,17],[7,11,14]]),
];

// ─────────────────────────── render fonksiyonları ───────────────────────────

/// Kullanıcı-parametreli akor progresyonu.
Float32List userChordsSource(
  int samples, {
  required int sampleRate,
  required int loopSamples,
  required int rootSemi,
  required int progressionIdx,
  required Waveform waveform,
  required double tempoScale, // 1.0 = normal; 2.0 = 2× hızlı
}) {
  final loopSeconds = loopSamples / sampleRate;
  const baseDur = 7.5;
  final targetDur = baseDur / tempoScale;
  final chordDur = loopLockedPeriod(targetDur, loopSeconds);
  final chordSamples = (chordDur * sampleRate).round();
  final prog = chordProgressions[progressionIdx % chordProgressions.length];
  final numChords = prog.chords.length;
  final totalChordSamples = chordSamples * numChords;
  final fadeSamples = (chordSamples * 0.15).round();

  final out = Float32List(samples);

  for (var ci = 0; ci * chordSamples < samples; ci++) {
    final notes = prog.chords[ci % numChords];
    final start = ci * chordSamples;
    if (start >= samples) break;
    final end = math.min(start + chordSamples, samples);

    for (final note in notes) {
      final f = loopLockedHz(_freq(rootSemi + note), loopSeconds);
      final omega = 2 * math.pi * f / sampleRate;

      for (var i = start; i < end; i++) {
        final local = i - start;
        var env = 1.0;
        if (local < fadeSamples) env = math.sin(math.pi / 2 * local / fadeSamples);
        else if (local > chordSamples - fadeSamples) {
          env = math.sin(math.pi / 2 * (chordSamples - local) / fadeSamples);
        }
        final v = env * 0.20 / notes.length *
            (_osc(waveform, omega * i) + 0.25 * _osc(waveform, 2 * omega * i));
        if (i < samples) out[i] += v;
      }
    }
  }

  // Periyodik dolgu
  if (totalChordSamples > 0 && totalChordSamples < samples) {
    for (var i = totalChordSamples; i < samples; i++) {
      out[i] = out[i - totalChordSamples];
    }
  }

  return out;
}

/// Kullanıcı-parametreli arpej.
Float32List userArpeggioSource(
  int samples, {
  required int seed,
  required int sampleRate,
  required int loopSamples,
  required int rootSemi,
  required int scaleIdx,
  required Waveform waveform,
  required double tempoScale,
}) {
  final loopSeconds = loopSamples / sampleRate;
  const baseStep = 0.75;
  final stepDur = loopLockedPeriod(baseStep / tempoScale, loopSeconds);
  final stepSamples = (stepDur * sampleRate).round();
  if (stepSamples <= 0) return Float32List(samples);

  final scale = melodicScales[scaleIdx % melodicScales.length];
  // Pingpong deseni: 0,1,2,...,N-1,N-2,...,1
  final pattern = <int>[];
  for (var i = 0; i < scale.semitones.length; i++) pattern.add(i);
  for (var i = scale.semitones.length - 2; i > 0; i--) pattern.add(i);
  final numSteps = pattern.length;

  final arpLoopSamples = stepSamples * numSteps;
  if (arpLoopSamples <= 0 || arpLoopSamples > samples) return Float32List(samples);

  final rng = Lcg(seed ^ 0xA9FE);
  final numTurs = (samples / arpLoopSamples).ceil() + 1;
  final octaves = <int>[];
  for (var t = 0; t < numTurs; t++) {
    octaves.add(rng.nextBipolar() > 0 ? 12 : 0);
  }

  final out = Float32List(samples);
  var stepIndex = 0;
  var lastTur = -1;
  var currentOctave = 0;

  for (var start = 0; start < samples; start += stepSamples) {
    final tur = start ~/ arpLoopSamples;
    if (tur != lastTur) { currentOctave = octaves[tur % octaves.length]; lastTur = tur; }

    final scaleIdx2 = pattern[stepIndex % numSteps];
    final f = loopLockedHz(
      _freq(rootSemi + scale.semitones[scaleIdx2] + currentOctave),
      loopSeconds,
    );
    final omega = 2 * math.pi * f / sampleRate;

    final noteEnd = math.min(start + stepSamples, samples);
    for (var i = start; i < noteEnd; i++) {
      final u = (i - start) / sampleRate;
      var env = u < 0.01 ? u / 0.01 : math.exp(-(u - 0.01) / 0.45);
      out[i] += env * 0.16 *
          (_osc(waveform, omega * i) + 0.2 * _osc(waveform, 2 * omega * i));
    }
    stepIndex++;
  }

  return out;
}
