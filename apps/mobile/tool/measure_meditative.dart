// ÖLÇÜM HARNESS'İ — test değil, geliştirici aracı.
//
// Meditatif kaynakların (#213) sayısal karakterini basar: tepe, RMS, DC, crest,
// modülasyon derinliği, tonallik, döngü dikişi, render süresi. `meditative_test.dart`
// eşikleri BURADAN ölçülerek alındı — eşik uydurmamak için.
//
// Çalıştır: cd apps/mobile && dart run tool/measure_meditative.dart
//
// `print` kasıtlı: bu bir CLI raporu, üretim kodu değil.
// ignore_for_file: avoid_print
import 'dart:math' as math;
import 'dart:typed_data';


import 'package:nocta/core/audio_engine/dsp/meditative.dart';
import 'package:nocta/core/audio_engine/dsp/mix_loop.dart';
import 'package:nocta/core/audio_engine/dsp/mix_render.dart';
import 'package:nocta/core/audio_engine/dsp/noise.dart';

const sr = 48000;
const loopSec = 30;
const n = sr * loopSec;

double peak(Float32List b) {
  var m = 0.0;
  for (final v in b) {
    if (v.abs() > m) m = v.abs();
  }
  return m;
}

/// Hilbert yok: |x|'in alçak geçirenden geçmiş hâli = zarf vekili.
Float32List envelope(Float32List b, {double a = 0.0008}) {
  final e = Float32List(b.length);
  var y = 0.0;
  for (var i = 0; i < b.length; i++) {
    y += a * (b[i].abs() - y);
    e[i] = y;
  }
  return e;
}

/// Zarfın verilen periyottaki modülasyon derinliği (normalize edilmiş
/// tek-frekans Goertzel benzeri iç çarpım / ortalama).
double modDepth(Float32List env, double periodSeconds) {
  final w = 2 * math.pi / (periodSeconds * sr);
  var re = 0.0, im = 0.0, mean = 0.0;
  for (var i = 0; i < env.length; i++) {
    re += env[i] * math.cos(w * i);
    im += env[i] * math.sin(w * i);
    mean += env[i];
  }
  mean /= env.length;
  final amp = 2 * math.sqrt(re * re + im * im) / env.length;
  return amp / mean;
}

/// Normalize otokorelasyon (tonallik kanıtı).
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

/// Pencere başına sıfır geçiş oranının değişim katsayısı (küçük = kararlı).
double zcrCv(Float32List b, {int win = 4800}) {
  final rates = <double>[];
  for (var s = 0; s + win <= b.length; s += win) {
    var c = 0;
    for (var i = s + 1; i < s + win; i++) {
      if ((b[i] < 0) != (b[i - 1] < 0)) c++;
    }
    rates.add(c / win);
  }
  final mean = rates.reduce((a, b) => a + b) / rates.length;
  var v = 0.0;
  for (final r in rates) {
    v += (r - mean) * (r - mean);
  }
  return math.sqrt(v / rates.length) / mean;
}

/// Dikiş etrafındaki zarf türevi vs buffer içindeki tipik zarf türevi.
/// Döngü faz sürekliliğinin sayısal kanıtı.
Map<String, double> seamEnvelope(Float32List b) {
  final env = envelope(b);
  // Döngüyü kendine ekle: dikiş ortada.
  final d = <double>[];
  for (var i = 1; i < env.length; i++) {
    d.add((env[i] - env[i - 1]).abs());
  }
  d.sort();
  final p999 = d[(d.length * 0.999).toInt()];
  final median = d[d.length ~/ 2];

  // Dikiş: env[son] → env[0] adımı, ama zarf durumlu olduğu için buffer'ı
  // iki kez arka arkaya işleyip ikinci turun başındaki türevi ölçüyoruz.
  final twice = Float32List(b.length * 2);
  twice.setRange(0, b.length, b);
  twice.setRange(b.length, b.length * 2, b);
  final env2 = envelope(twice);
  var seamMax = 0.0;
  final w = (0.25 * sr).round();
  for (var i = b.length - w; i < b.length + w; i++) {
    final step = (env2[i] - env2[i - 1]).abs();
    if (step > seamMax) seamMax = step;
  }
  return {'seamMax': seamMax, 'p999': p999, 'median': median};
}

void row(String name, Float32List b) {
  final p = peak(b);
  final r = rms(b);
  print('${name.padRight(8)}peak=${p.toStringAsFixed(4)}  rms=${r.toStringAsFixed(4)}  '
      'dc=${dcOffset(b).toStringAsFixed(6)}  crest=${(p / r).toStringAsFixed(2)}  '
      'mad=${meanAbsDelta(b).toStringAsFixed(5)}  zcrCv=${zcrCv(b).toStringAsFixed(4)}');
}

void main() {
  print('--- ham kaynaklar (30 sn @48k, seed 1234) ---');
  final srcs = <String, Float32List>{};
  for (final t in LayerSource.values) {
    srcs[t.name] =
        renderSource(t, n, seed: 1234, sampleRate: sr, loopSamples: n);
  }
  srcs.forEach(row);

  print('\n--- sınırlar ---');
  print('waves bound=$wavesPeakBound  fire=$firePeakBound  '
      'rain=$rainPeakBound  pad=$padPeakBound');

  print('\n--- dalga: zarf modülasyonu ---');
  final wEnv = envelope(srcs['waves']!);
  for (final p in [10.0, 7.5, 6.0, 3.0]) {
    print('  periyot ${p}sn → derinlik ${modDepth(wEnv, p).toStringAsFixed(4)}');
  }
  for (final name in ['brown', 'pink', 'white', 'rain', 'fire', 'pad']) {
    print('  [$name] 10sn derinlik '
        '${modDepth(envelope(srcs[name]!), 10.0).toStringAsFixed(4)}');
  }

  print('\n--- tonallik: otokorelasyon (lag = 1/f0) ---');
  final lag = (sr / loopLockedHz(padF0, loopSec.toDouble())).round();
  print('  lag=$lag örnek');
  for (final t in LayerSource.values) {
    print('  ${t.name.padRight(6)} ac=${autocorr(srcs[t.name]!, lag).toStringAsFixed(4)}');
  }

  print('\n--- döngü faz sürekliliği (renderSeamlessLoop, tek katman) ---');
  for (final t in LayerSource.values) {
    final b = renderSeamlessLoop(
      MixSpec([MixLayer(id: 'a', type: t, gain: 1.0)]),
      loopSeconds: loopSec,
      sampleRate: sr,
      seed: 7,
    );
    final s = seamEnvelope(b);
    print('  ${t.name.padRight(6)} seamMax=${s['seamMax']!.toStringAsExponential(3)} '
        'p999=${s['p999']!.toStringAsExponential(3)} '
        'oran=${(s['seamMax']! / s['p999']!).toStringAsFixed(3)}  '
        'peak=${peak(b).toStringAsFixed(4)}');
  }

  print('\n--- transient istatistikleri ---');
  double kurtosis(Float32List b) {
    final m = dcOffset(b);
    var m2 = 0.0, m4 = 0.0;
    for (final v in b) {
      final d = v - m;
      m2 += d * d;
      m4 += d * d * d * d;
    }
    m2 /= b.length;
    m4 /= b.length;
    return m4 / (m2 * m2);
  }

  double pct(Float32List b, double p) {
    final a = List<double>.generate(b.length, (i) => b[i].abs())..sort();
    return a[(a.length * p).clamp(0, a.length - 1).toInt()];
  }

  for (final t in LayerSource.values) {
    final b = srcs[t.name]!;
    print('  ${t.name.padRight(6)} kurt=${kurtosis(b).toStringAsFixed(2)}  '
        'p9999/rms=${(pct(b, 0.9999) / rms(b)).toStringAsFixed(2)}  '
        'p999/rms=${(pct(b, 0.999) / rms(b)).toStringAsFixed(2)}');
  }

  print('\n  KONTROLLÜ KARŞILAŞTIRMA (aynı yatak, transientli vs transientsiz):');
  final fireBed = brownNoise(n, seed: 1234);
  final fb = Float32List(n);
  for (var i = 0; i < n; i++) {
    fb[i] = 0.48 * fireBed[i];
  }
  print('    fire yatağı  kurt=${kurtosis(fb).toStringAsFixed(2)} '
      'crest=${(peak(fb) / rms(fb)).toStringAsFixed(2)} rms=${rms(fb).toStringAsFixed(4)}');
  print('    fire tam     kurt=${kurtosis(srcs['fire']!).toStringAsFixed(2)} '
      'crest=${(peak(srcs['fire']!) / rms(srcs['fire']!)).toStringAsFixed(2)}');

  final rawRain = whiteNoise(n, seed: 1234);
  final rb = Float32List(n);
  var y = 0.0;
  for (var i = 0; i < n; i++) {
    y += 0.35 * (rawRain[i] - y);
    rb[i] = 0.40 * y;
  }
  print('    rain yatağı  kurt=${kurtosis(rb).toStringAsFixed(2)} '
      'crest=${(peak(rb) / rms(rb)).toStringAsFixed(2)} rms=${rms(rb).toStringAsFixed(4)}');
  print('    rain tam     kurt=${kurtosis(srcs['rain']!).toStringAsFixed(2)} '
      'crest=${(peak(srcs['rain']!) / rms(srcs['rain']!)).toStringAsFixed(2)}');

  // Kısa pencere RMS'inin tepe/medyan oranı — transientler GLOBAL istatistikte
  // seyreldiği için (crest, kurtosis) burada görünür.
  double windowPeakToMedian(Float32List b, {int win = 480}) {
    final w = <double>[];
    for (var s = 0; s + win <= b.length; s += win ~/ 2) {
      var sum = 0.0;
      for (var i = s; i < s + win; i++) {
        sum += b[i] * b[i];
      }
      w.add(math.sqrt(sum / win));
    }
    final sorted = List<double>.from(w)..sort();
    return sorted.last / sorted[sorted.length ~/ 2];
  }

  print('\n  KISA PENCERE (10 ms) RMS tepe/medyan:');
  for (final t in LayerSource.values) {
    print('    ${t.name.padRight(6)} ${windowPeakToMedian(srcs[t.name]!).toStringAsFixed(3)}');
  }
  print('    fire yatağı  ${windowPeakToMedian(fb).toStringAsFixed(3)}');
  print('    rain yatağı  ${windowPeakToMedian(rb).toStringAsFixed(3)}');

  print('\n  EN YÜKSEK TEK TRANSIENT (uyandırma riski göstergesi):');
  for (final name in ['fire', 'rain']) {
    final bed = name == 'fire' ? fb : rb;
    var maxDiff = 0.0;
    for (var i = 0; i < n; i++) {
      final d = (srcs[name]![i] - bed[i]).abs();
      if (d > maxDiff) maxDiff = d;
    }
    print('    $name: en büyük transient katkısı=${maxDiff.toStringAsFixed(4)}  '
        '(yatak tepesi=${peak(bed).toStringAsFixed(4)})');
  }

  print('\n--- render süresi (tek katman, 30 sn) ---');
  for (final t in LayerSource.values) {
    final sw = Stopwatch()..start();
    renderSource(t, n, seed: 5, sampleRate: sr, loopSamples: n);
    sw.stop();
    print('  ${t.name.padRight(6)} ${sw.elapsedMilliseconds} ms');
  }
}
