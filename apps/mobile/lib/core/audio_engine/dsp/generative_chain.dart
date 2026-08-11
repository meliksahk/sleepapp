/// **Sonsuz jeneratif uzatma** — ürünün asıl vaadi: *hiç tekrar etmeyen ses*.
///
/// ## Neden var
///
/// Motor bugüne kadar 30 saniyelik bir buffer üretip `LoopMode.one` ile
/// döngülüyordu. Dikiş tıksızdı (`renderSeamlessLoop`) ama ses **aynıydı**:
/// gecede 960 kez birebir tekrar. Kulak, farkında olmadan periyodu öğrenir;
/// "gerçek bir yerde duruyorum" hissini bozan şey tam olarak budur ve rakip
/// uygulamaların (BetterSleep vb.) statik/döngülü seslerinden ayrıldığımız yer
/// de burasıdır.
///
/// ## Nasıl
///
/// Döngü yerine **zincir**: her segment KENDİ tohumundan üretilir, yani hiçbir
/// segment bir öncekinin kopyası değildir. Segmentler arka arkaya çalınır.
///
/// Dikiş sorunu döngüdekiyle aynı ve çözümü de aynı: segment *k* nominal
/// uzunluğunun (`n`) üstüne `x` örnek daha üretir — bu kuyruk, "o segment devam
/// etseydi ne gelirdi"dir. Segment *k+1*'in ilk `x` örneği, o kuyrukla
/// **eşit-güç** harmanlanır:
///
///   head[i] = yeni[i]·sin(θ) + kuyruk[i]·cos(θ),  θ = (i/x)·π/2
///
/// i=0'da harman tamamen kuyruktur → önceki segmentin son örneğiyle SÜREKLİ.
/// i=x'te tamamen yeni malzemedir. Korelasyonsuz gürültüde sin²+cos²=1 gücü
/// sabit tutar (lineer harman burada ~3 dB çukur açardı).
///
/// ## Pad (tonal) kaynak için farklı süre — bilinçli
///
/// 50 ms, korelasyonsuz gürültü için doğru; iki FARKLI akor arasında ise bir
/// kesme gibi duyulur. Pad'de harman [padSeamCrossfade] kadar sürer: sonuç bir
/// dikiş değil, yavaş bir akor geçişidir — jeneratif ambient müziğin kendi
/// dili. (`renderSeamlessLoop`'taki "kilitli kaynağa crossfade UYGULAMA" kuralı
/// buraya taşınmaz: orada kuyruk ile baş BİREBİR aynıydı, burada iki farklı
/// tohumdan gelen iki farklı akor.)
///
/// ## Bu sınıf ses ÇALMAZ
///
/// Saf DSP: buffer üretir, testi ucuzdur. Çalma/kuyruk yönetimi `MixPlayer`'da.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'meditative.dart';
import 'mix_render.dart';

/// Ardışık segmentlerin tohumu. Asal adım: iki segment aynı diziyi ÜRETEMEZ ve
/// katman tohumlarıyla (`layerSeed`, 7919) çakışma örüntüsü kurmaz.
int segmentSeed(int baseSeed, int index) => baseSeed + index * 15485863;

/// Tonal kaynakta dikiş harmanı — akor geçişi kadar uzun.
const Duration padSeamCrossfade = Duration(seconds: 3);

/// Gürültü/doku kaynağında dikiş harmanı — `renderSeamlessLoop` ile aynı süre.
const Duration noiseSeamCrossfade = Duration(milliseconds: 50);

Duration seamCrossfadeFor(LayerSource type) =>
    isLoopPeriodic(type) ? padSeamCrossfade : noiseSeamCrossfade;

/// Tek bir segmentin RENDER isteği — **saf veri**, isolate sınırından geçebilir.
///
/// Zincir durumlu olduğu için isolate'e taşınamaz (durum kopyalanır, kaybolur).
/// Bu yüzden iş ikiye ayrıldı: PAHALI kısım (kaynak sentezi) saf bir istektir ve
/// `compute()` ile ayrı isolate'te koşar; UCUZ kısım (dikiş harmanı + seviye
/// eşitleme, O(n) toplama) zincirin kendisinde, ana isolate'te kalır.
class SegmentRequest {
  const SegmentRequest({
    required this.type,
    required this.seed,
    required this.variant,
    required this.samples,
    required this.sampleRate,
    required this.loopSamples,
  });

  final LayerSource type;
  final int seed;
  final int variant;

  /// n + x (nominal uzunluk + dikiş kuyruğu).
  final int samples;
  final int sampleRate;
  final int loopSamples;
}

/// [SegmentRequest]'i sese çevirir. Üst düzey fonksiyon: `compute()` ancak
/// böyle bir fonksiyonu isolate'e gönderebilir (kapanış gönderilemez).
Float32List renderSegmentRequest(SegmentRequest r) => renderSource(
      r.type,
      r.samples,
      seed: r.seed,
      sampleRate: r.sampleRate,
      loopSamples: r.loopSamples,
      variant: r.variant,
    );

/// Tek bir katmanın sonsuz akışını segment segment üretir.
///
/// **Durumlu, bilerek:** dikiş sürekliliği bir önceki segmentin kuyruğunu
/// bilmeyi gerektirir. Saf bir fonksiyon bu bilgiyi her çağrıda yeniden üretmek
/// zorunda kalırdı (segment *k* için *k* kez render → O(k²)).
class LayerSegmentChain {
  LayerSegmentChain({
    required this.type,
    required this.seed,
    required this.segmentSeconds,
    required this.sampleRate,
  })  : assert(segmentSeconds > 0),
        assert(sampleRate > 0);

  final LayerSource type;

  /// Katman tohumu (`layerSeed` çıktısı). Segment tohumları bundan türer →
  /// aynı mix aynı gecede aynı akışı üretir (teşhis edilebilirlik).
  final int seed;

  final int segmentSeconds;
  final int sampleRate;

  int _index = 0;

  /// Önceki segmentin DEVAMI (x örnek). İlk segmentte null → harman yok.
  Float32List? _tail;

  /// Bir önceki akor rengi (yalnız pad). Aynı rengi arka arkaya seçmek, pad'i
  /// yine tekrar eder hâle getirirdi.
  int _lastVariant = -1;

  /// Akışın seviye ölçütü — ilk segmentin RMS'i (bkz. [_levelMatch]).
  double? _refRms;

  /// Seviye eşitlemenin sınırları. Dışına çıkmak, kaynağın gerçekten değiştiği
  /// (ör. çok sessiz bir dalga çukuru) durumları zorla yükseltmek olurdu.
  static const double _minLevelGain = 0.7;
  static const double _maxLevelGain = 1.4;

  /// Şimdiye kadar üretilen segment sayısı (teşhis/test).
  int get producedCount => _index;

  int get _n => sampleRate * segmentSeconds;

  int get _x {
    final wanted =
        (seamCrossfadeFor(type).inMicroseconds * sampleRate / 1e6).round();
    // Harman segmentin yarısını geçemez (çok kısa segment kenar durumu).
    final half = _n ~/ 2;
    return wanted > half ? half : math.max(wanted, 1);
  }

  /// Sıradaki segmentin render isteği. Durumu ilerletmez — [accept] ilerletir.
  ///
  /// İkisi ARDIŞIK çağrılmalıdır; araya ikinci bir [planNext] girerse akor
  /// seçimi kayar (assert yakalar).
  SegmentRequest planNext() {
    assert(_pending == null, 'planNext üst üste çağrıldı; önce accept()');
    final sSeed = segmentSeed(seed, _index);
    final req = SegmentRequest(
      type: type,
      seed: sSeed,
      variant: _pickVariant(sSeed),
      // n + x üret: kuyruk, "bu segment devam etseydi"nin ta kendisi.
      samples: _n + _x,
      sampleRate: sampleRate,
      // Modülasyon periyotları NOMİNAL uzunluğa kilitlenir; kuyruk periyodu
      // uzatmaz (bkz. renderMix'teki loopSeconds notu).
      loopSamples: _n,
    );
    _pending = req;
    return req;
  }

  SegmentRequest? _pending;

  /// Sıradaki segmenti üretir (n örnek). Çağrıldıkça sonsuza kadar devam eder.
  ///
  /// Tek isolate'lik kısayol: pahalı render'ı ayrı isolate'e almak isteyen
  /// çağıran [planNext] + [renderSegmentRequest] + [accept] üçlüsünü kullanır.
  Float32List next() => accept(renderSegmentRequest(planNext()));

  /// Render edilmiş ham segmenti (n + x örnek) çalınabilir hâle getirir:
  /// seviye eşitler, önceki segmentin kuyruğuyla harmanlar, durumu ilerletir.
  Float32List accept(Float32List full) {
    assert(_pending != null, 'accept öncesinde planNext çağrılmalı');
    _pending = null;
    final n = _n;
    final x = _x;

    _levelMatch(full, n);

    final out = Float32List(n);
    final prevTail = _tail;
    if (prevTail == null) {
      out.setRange(0, n, full);
    } else {
      final scale = (math.pi / 2) / x;
      for (var i = 0; i < x; i++) {
        final theta = i * scale;
        final v = full[i] * math.sin(theta) + prevTail[i] * math.cos(theta);
        // Kırpma: eşit-güç GÜCÜ korur ama anlık toplam √2'ye çıkabilir.
        // Dikiş örneği (i=0) etkilenmez: sin0=0 → out[0] = kuyruk[0].
        out[i] = v > 1.0 ? 1.0 : (v < -1.0 ? -1.0 : v);
      }
      out.setRange(x, n, full.sublist(x, n));
    }

    _tail = Float32List.sublistView(full, n, n + x);
    _index++;
    return out;
  }

  /// Segmentleri AYNI seviyeye getirir — zincirin ortaya çıkardığı bir hata.
  ///
  /// **ÖLÇÜLDÜ:** `pinkNoise`/`brownNoise` her buffer'ı KENDİ tepe değerine
  /// normalize eder. Tek bir buffer'ı sonsuza kadar döngülerken bu görünmezdi
  /// (seviye sabitti). Zincirde ise her segment kendi tepesine göre ölçekleniyor
  /// ve segment RMS'i 0.220–0.303 arasında geziyordu (≈1.5 dB): kullanıcı her 30
  /// saniyede bir seviye BASAMAĞI duyardı. Gizlemeye çalıştığımız periyodikliğin
  /// bir başka biçimi.
  ///
  /// Ölçüt akışın ilk segmentidir; sonrakiler ona hizalanır. Kazanç
  /// [_minLevelGain]–[_maxLevelGain] ile sınırlı: kaynağın kendi zarfı gereği
  /// gerçekten sessiz olan bir segmenti (dalga çukuru) zorla yükseltmeyiz.
  ///
  /// ⚠️ **Dürüstlük:** yükseltme, tepe-normalize edilmiş bir segmentte tek
  /// örneklik nadir kırpma üretebilir (tepe zaten 1.0'a değiyor). Kırpma
  /// örnekleri burada [-1,1]'e sıkıştırılıyor; duyulmaz ama sıfır da değil.
  void _levelMatch(Float32List full, int n) {
    var sum = 0.0;
    for (var i = 0; i < n; i++) {
      sum += full[i] * full[i];
    }
    final segRms = math.sqrt(sum / n);
    if (segRms <= 0) return;

    final ref = _refRms ??= segRms;
    final gain = (ref / segRms).clamp(_minLevelGain, _maxLevelGain);
    if ((gain - 1).abs() < 0.01) return;

    for (var i = 0; i < full.length; i++) {
      final v = full[i] * gain;
      full[i] = v > 1.0 ? 1.0 : (v < -1.0 ? -1.0 : v);
    }
  }

  /// Segmentin akor rengi — arka arkaya AYNI renk seçilmez.
  ///
  /// Yalnız pad kullanır; diğer kaynaklar `variant`'ı yok sayar (tohumları
  /// zaten her segmentte farklı bir gerçekleşme üretiyor).
  int _pickVariant(int segSeed) {
    if (!isLoopPeriodic(type)) return 0;
    final count = padVariantRatios.length;
    // Tohumdan türet (deterministik), sonra son rengi ele: kalan (count-1)
    // seçenek arasından seç, böylece "aynı akor iki kez" imkânsız.
    final raw = (segSeed ~/ 7).abs() % (count - 1);
    final picked = _lastVariant < 0 ? raw : (raw + _lastVariant + 1) % count;
    _lastVariant = picked;
    return picked;
  }
}
