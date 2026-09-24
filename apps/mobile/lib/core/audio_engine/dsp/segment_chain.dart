import 'dart:math' as math;
import 'dart:typed_data';

import 'mix_loop.dart';
import 'mix_render.dart';
import 'wav_encoder.dart';

/// **Sonsuz uzatma: katmanın sesi gece boyunca birebir tekrar etmez.**
///
/// ## Sorun
///
/// `MixPlayer` her katmanı 30 sn'lik TEK bir buffer'dan `LoopMode.one` ile
/// döngülüyordu. Dikiş tıksızdı ama içerik aynıydı: aynı çıtırtı, aynı damla,
/// aynı çan vuruşu gece boyunca her 30 sn'de bir, sekiz saatte ~960 kez birebir
/// dönüyordu.
///
/// ## Çözüm: tohum zinciri
///
/// Katman, 30 sn'lik PARÇALARIN ardışık bir zinciri olarak çalınır. Parça k
/// kendi tohumuyla ([segmentSeed]) üretilir; çalar parça k'yı çalarken k+1
/// hazırlanıp çalma listesine eklenir (bkz. `MixPlayer`). Ardışık iki parça
/// kaynağın türüne göre iki yoldan biriyle dikişsiz birleşir:
///
/// - **Harmanlanan kaynaklar** (`isLoopPeriodic` false: gürültüler, doğa,
///   sürtünme). Parça k, n+x örnek üretilir. k+1'in ilk x örneği, k'nın
///   kuyruğuyla eşit-güç harmanlanır. Bugünkü döngü dikişinin aynı matematiği,
///   tek farkla: kuyruk aynı buffer'ın değil ÖNCEKİ parçanın devamıdır.
/// - **Kilitli kaynaklar** (`isLoopPeriodic` true). Sürekli bileşenler döngüye
///   kilitli ve tohumdan bağımsızdır, her parçanın sınırında aynı fazdadır;
///   olaylar (parıltı, vuruş) sınıra taşmayacak biçimde yerleştirilir. Parçalar
///   harmansız eklenir: bugünkü döngü sarmasının aynısı.
///
/// İlk parça (index 0) bugünkü döngü buffer'ının BİREBİR aynısıdır ve kendi
/// başına dikişsiz döner. Üretim bir an durursa çalar listeyi döndürür; ses
/// kesilmez, en kötü ihtimalle eski davranışa (tekrar) düşer.
///
/// ## Seviye hizalama
///
/// Gürültü kaynakları her buffer'ı kendi tepesine normalize eder. İki farklı
/// tohumun RMS'i ölçüldü: pembe 0.198 / 0.229 (≈1.3 dB), kahverengi 0.227 /
/// 0.207. Tek buffer döngülenirken görünmezdi; zincirde her 30 sn'de bir seviye
/// basamağı olurdu. Harmanlanan kaynaklarda her parça ilk parçanın RMS'ine
/// hizalanır (±3 dB ile sınırlı). Kilitli kaynaklarda yatak tohumdan bağımsız
/// olduğu için hizalamaya gerek yok; seyrek olaylı kaynaklarda (çan) parçalar
/// arası doğal yoğunluk farkı zaten korunmalı.
///
/// ## Neyin yeniden üretilmediği
///
/// `tone`, `chords` ve `topSpin` tohumdan bağımsızdır: farklı tohumlarla ölçülen
/// gövde korelasyonu 1.000. Yeni tohum aynı sesi verir, yeniden üretmek boşa
/// işlemci harcar. Üçü de tasarım gereği sabit ya da ritmiktir (sabit ton,
/// kullanıcının seçtiği akor dizisi, dönen topaç). `pad` ve `ceramic`'te tohum
/// yalnız olayları (parıltı, sürtme pırıltısı) değiştirir; yatakları tasarım
/// gereği periyodiktir.
bool regeneratesPerSegment(LayerSource type) => switch (type) {
      LayerSource.tone || LayerSource.chords || LayerSource.topSpin => false,
      LayerSource.white ||
      LayerSource.pink ||
      LayerSource.brown ||
      LayerSource.waves ||
      LayerSource.fire ||
      LayerSource.rain ||
      LayerSource.pad ||
      LayerSource.arpeggio ||
      LayerSource.ceramic ||
      LayerSource.chimes ||
      LayerSource.friction =>
        true,
    };

/// Parça [index]'in tohumu. `index == 0` → [baseSeed]: ilk parça bugünkü döngü
/// buffer'ıyla aynı tohumu kullanır.
int segmentSeed(int baseSeed, int index) => baseSeed + index * _segmentSeedStride;

/// Asal adım: ardışık parçaların tohumları katmanlar arası tohumlarla
/// (`layerSeed`, 7919 adımlı) çakışmasın.
const int _segmentSeedStride = 1000003;

/// Seviye hizalamanın sınırı: bir parça ilk parçadan en çok ±3 dB oynatılır.
/// Ölçülen fark ≤1.3 dB; sınır, beklenmedik bir sessiz/gürültülü parçanın
/// hizalama bahanesiyle aşırı büyütülmesini engeller.
const double _minLevelGain = 0.7;
const double _maxLevelGain = 1.4;

/// Bir parçanın üretim isteği. `compute()` ile isolate'e gider: sade veri.
class SegmentRequest {
  const SegmentRequest({
    required this.layer,
    required this.index,
    required this.baseSeed,
    required this.loopSeconds,
    required this.sampleRate,
    this.prevTail,
    this.refRms,
  });

  /// Katman tanımı: kaynak ve TÜM parametreleri (ton frekansı, melodi ayarları).
  /// Kazancı yok sayılır: katman 1.0 ile üretilir, kazanç `setVolume` ile gelir.
  final MixLayer layer;

  /// Zincirdeki sıra. 0 = ilk parça.
  final int index;
  final int baseSeed;
  final int loopSeconds;
  final int sampleRate;

  /// Harmanlanan kaynaklarda önceki parçanın kuyruğu (`index > 0` için zorunlu).
  final Float32List? prevTail;

  /// Harmanlanan kaynaklarda seviye referansı (`index > 0` için zorunlu).
  final double? refRms;
}

/// Bir parçanın PCM hâli ve zincirin bir sonraki halkası için durum.
class SegmentPcm {
  const SegmentPcm(this.pcm, {this.tail, this.refRms});

  /// Tam olarak `sampleRate × loopSeconds` örnek, mono.
  final Float32List pcm;

  /// Harmanlanan kaynaklarda bir sonraki parçanın başıyla harmanlanacak kuyruk.
  /// Kopyadır, görünüm değil: görünüm, önceki parçanın bütün tamponunu (~5.8 MB)
  /// bir sonraki parçaya kadar bellekte tutardı.
  final Float32List? tail;

  /// Harmanlanan kaynaklarda zincir boyunca taşınan seviye referansı.
  final double? refRms;
}

/// Çalara giden hâl: WAV baytları + zincir durumu. PCM taşınmaz; isolate
/// sınırından yarı boyutlu bayt geçer.
class SegmentResult {
  const SegmentResult(this.wav, {this.tail, this.refRms});

  final Uint8List wav;
  final Float32List? tail;
  final double? refRms;
}

/// Isolate giriş noktası: parçayı üretip WAV'a paketler.
SegmentResult renderSegmentSync(SegmentRequest r) {
  final s = renderSegmentPcm(r);
  return SegmentResult(
    encodeWav(s.pcm, sampleRate: r.sampleRate),
    tail: s.tail,
    refRms: s.refRms,
  );
}

/// Zincirin bir halkasını üretir. Testler PCM'e doğrudan bakabilsin diye ayrı.
SegmentPcm renderSegmentPcm(SegmentRequest r) {
  assert(regeneratesPerSegment(r.layer.type), '${r.layer.type} parça parça üretilmez');
  final n = r.sampleRate * r.loopSeconds;
  final spec = MixSpec(<MixLayer>[_unitGain(r.layer)]);
  final seed = segmentSeed(r.baseSeed, r.index);

  if (isLoopPeriodic(r.layer.type)) {
    // Kilitli kaynak: her parça tek başına döngü, ardışık parçalar harmansız
    // eklenir. `renderSeamlessLoop` bu tür için ham kopyalar; index 0'da
    // bugünkü buffer'ın aynısıdır.
    return SegmentPcm(renderSeamlessLoop(
      spec,
      loopSeconds: r.loopSeconds,
      sampleRate: r.sampleRate,
      seed: seed,
    ));
  }

  final x = seamCrossfadeSamples(r.sampleRate, n);
  final s = renderMix(
    spec,
    seconds: r.loopSeconds,
    sampleRate: r.sampleRate,
    seed: seed,
    extraSamples: x,
  );
  final out = Float32List(n);

  if (r.index == 0) {
    // İlk parça: kendi kuyruğu kendi başına harmanlanır. `renderSeamlessLoop`
    // ile aynı hesap, yani bugünkü döngü buffer'ının birebir aynısı; ayrıca
    // üretim durursa tek başına dikişsiz döner.
    writeEqualPowerSeam(out, head: s, tail: s, tailOffset: n, x: x);
    out.setRange(x, n, s, x);
    return SegmentPcm(
      out,
      tail: s.sublist(n, n + x),
      refRms: _rms(s, n),
    );
  }

  final prevTail = r.prevTail;
  final refRms = r.refRms;
  if (prevTail == null || refRms == null || prevTail.length != x) {
    throw ArgumentError('parça ${r.index}: önceki parçanın kuyruğu ve seviye referansı gerekli');
  }
  final gain = _levelGain(refRms, _rms(s, n));
  for (var i = 0; i < s.length; i++) {
    s[i] *= gain;
  }
  writeEqualPowerSeam(out, head: s, tail: prevTail, x: x);
  // Gövde: hizalama kazancı 1'i aşabildiği için kırpılır (WAV kodlayıcı da
  // kırpardı; burada kırpmak test edilen PCM'i çalınan sesle aynı tutar).
  for (var i = x; i < n; i++) {
    final v = s[i];
    out[i] = v > 1.0 ? 1.0 : (v < -1.0 ? -1.0 : v);
  }
  return SegmentPcm(
    out,
    tail: s.sublist(n, n + x),
    refRms: refRms,
  );
}

MixLayer _unitGain(MixLayer l) => MixLayer(
      id: l.id,
      type: l.type,
      gain: 1.0,
      frequencyHz: l.frequencyHz,
      beatHz: l.beatHz,
      rootSemi: l.rootSemi,
      waveform: l.waveform,
      tempoScale: l.tempoScale,
      patternIdx: l.patternIdx,
    );

double _rms(Float32List s, int n) {
  var sum = 0.0;
  for (var i = 0; i < n; i++) {
    sum += s[i] * s[i];
  }
  return math.sqrt(sum / n);
}

double _levelGain(double ref, double rms) {
  if (ref <= 0 || rms <= 0) return 1.0;
  final g = ref / rms;
  return g < _minLevelGain ? _minLevelGain : (g > _maxLevelGain ? _maxLevelGain : g);
}
