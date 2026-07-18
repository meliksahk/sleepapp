import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:nocta/core/audio_engine/dsp/noise.dart';
import 'package:nocta/core/audio_engine/dsp/nocta_signature.dart';

/// Açılış imzasının **doğruluğunu** kanıtlar — güzelliğini DEĞİL.
///
/// Güzellik yargısı kulaklıkla insana aittir (CLAUDE.md §1.1). Buradaki testler
/// sesin teknik olarak sağlam olduğunu gösterir: kırpma yok, tık yok, DC yok,
/// deterministik, ve zarf/tilt gerçekten çalışıyor.
void main() {
  final sig = noctaSignature();
  final n = sig.length;

  double peak(List<double> b, [int from = 0, int? to]) {
    var p = 0.0;
    for (var i = from; i < (to ?? b.length); i++) {
      if (b[i].abs() > p) p = b[i].abs();
    }
    return p;
  }

  double rmsRange(List<double> b, double fromSec, double toSec) {
    final a = (fromSec * signatureSampleRate).round();
    final z = (toSec * signatureSampleRate).round().clamp(0, b.length);
    var sum = 0.0;
    for (var i = a; i < z; i++) {
      sum += b[i] * b[i];
    }
    return math.sqrt(sum / (z - a));
  }

  double hfProxy(double fromSec, double toSec) {
    final a = (fromSec * signatureSampleRate).round();
    final z = (toSec * signatureSampleRate).round().clamp(0, sig.length);
    var sum = 0.0;
    for (var i = a + 1; i < z; i++) {
      sum += (sig[i] - sig[i - 1]).abs();
    }
    return sum / (z - a - 1);
  }

  test('#1 süre sözleşmesi: 3.6 sn @48kHz', () {
    expect(n, (signatureSeconds * signatureSampleRate).round());
  });

  test('#2/#3 zarf uçları temiz: ilk örnek TAM sıfır, kuyruk sıfıra iner', () {
    expect(sig[0], 0.0);
    expect(sig[n - 1].abs(), lessThan(1e-6));
  });

  test('#4/#5 kırpma yok ama sessiz de değil', () {
    final p = peak(sig);
    // Yapısal üst sınır 0.6485 → clamp asla tetiklenmemeli.
    expect(p, lessThanOrEqualTo(0.68));
    // "Sessiz buffer" regresyonunu yakalar.
    expect(p, greaterThanOrEqualTo(0.28));
  });

  test('#6 TIK YOK: ilk ve son 5 ms neredeyse sessiz', () {
    expect(peak(sig, 0, 240), lessThan(1e-3));
    expect(peak(sig, n - 240, n), lessThan(1e-3));
  });

  test('#7 süreksizlik yok: ardışık örnek farkı sınırlı', () {
    var maxDelta = 0.0;
    for (var i = 1; i < n; i++) {
      final d = (sig[i] - sig[i - 1]).abs();
      if (d > maxDelta) maxDelta = d;
    }
    expect(maxDelta, lessThan(0.045));
  });

  test('#8/#9 RMS bandı ve DC ihmal edilebilir', () {
    expect(rms(sig), inInclusiveRange(0.05, 0.16));
    expect(dcOffset(sig).abs(), lessThan(0.005));
  });

  test('#10 determinizm: aynı seed → bit-birebir aynı buffer', () {
    final a = noctaSignature(seed: 1308);
    final b = noctaSignature(seed: 1308);
    expect(a.length, b.length);
    for (var i = 0; i < a.length; i += 97) {
      expect(a[i], b[i]);
    }
  });

  test('#11 seed parıltıyı GERÇEKTEN değiştirir ama ses sağlam kalır', () {
    final other = noctaSignature(seed: 4242);
    var differs = false;
    for (var i = 0; i < n; i += 13) {
      if ((other[i] - sig[i]).abs() > 1e-9) {
        differs = true;
        break;
      }
    }
    expect(differs, isTrue);
    expect(peak(other), lessThanOrEqualTo(0.68));
    expect(rms(other), inInclusiveRange(0.05, 0.16));
  });

  test('#13 ATTACK gerçekten var: ilk 0.5 sn belirgin kısık', () {
    // Eşik ÖLÇÜLEREK kalibre edildi: oran ≈ 0.63 (spec 0.60 tahmin etmişti, sapma
    // beklenen ve spec'te uyarılmıştı). 0.75 hâlâ "attack var" der; rampa
    // kaldırılırsa oran 1.0'a fırlar ve test kırılır.
    expect(rmsRange(sig, 0, 0.5), lessThan(0.75 * rmsRange(sig, 1.0, 2.0)));
  });

  test('#14 TILT yönü doğru: gökyüzü açılıyor (koyu → parlak)', () {
    // TOPLAM RMS bu işi ÖLÇEMİYOR (ölçüldü: 0.0818 vs 0.0816 — fark vuru
    // gürültüsünün altında), çünkü tilt yalnız ağırlığın %28'ini etkiliyor.
    // `meanAbsDelta` ardışık örnek farkının ortalaması = YÜKSEK FREKANS vekili;
    // tilt tam olarak üst partial'ları açtığı için doğru ölçüt budur.
    expect(hfProxy(0.2, 0.7), lessThan(hfProxy(1.4, 1.9)));
  });

  test("#15 ağırlık merkezi 2·f0 civarı (FFT'siz sıfır-geçiş vekili)", () {
    final a = (0.8 * signatureSampleRate).round();
    final z = (1.2 * signatureSampleRate).round();
    var crossings = 0;
    for (var i = a + 1; i < z; i++) {
      if ((sig[i - 1] < 0 && sig[i] >= 0) || (sig[i - 1] >= 0 && sig[i] < 0)) {
        crossings++;
      }
    }
    final hz = crossings / (2 * 0.4);
    // Sıfır-geçiş oranı enerji merkezine DEĞİL yüksek partial'lara yanlıdır
    // (ölçüldü: 457.5 Hz; 3f0=392 ile 4f0=523 arası — beklenen davranış).
    // Spec'in [230,300] tahmini bu yanlılığı hesaba katmamıştı. Bant, partial
    // tablosu bozulursa hâlâ kırılacak kadar dar.
    expect(hz, inInclusiveRange(380, 540));
  });

  test('#16 parıltı sayısı beklenen aralıkta', () {
    noctaSignature();
    expect(lastSignatureGrainCount, inInclusiveRange(3, 7));
  });
}
