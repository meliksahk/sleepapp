import 'dart:math' as math;
import 'dart:typed_data';

import 'mix_render.dart';

/// Sorunsuz (dikişsiz) döngü render'ı — mikserin **döngü tıkını** çözer.
///
/// ## Sorun
///
/// `MixPlayer` sonlu bir buffer'ı `LoopMode.one` ile döngüler. Ham `renderMix`
/// çıkışında `pcm[son]` ile `pcm[0]` arasında hiçbir süreklilik yoktur → her döngü
/// başında bir SÜREKSİZLİK (tık/pop) duyulur. Kahverengi (integre edilmiş) gürültüde
/// bu bir rastgele-yürüyüşün iki ucu olduğu için özellikle büyük bir sıçramadır.
/// Bir uyku uygulamasında periyodik bir tık, hafif uykudakini uyandırabilir.
///
/// ## Çözüm — eşit-güç crossfade
///
/// `N + X` örnek üretilir (X = crossfade uzunluğu). Çıkış döngü buffer'ı N örnektir:
/// ilk X örnekte, **kuyruk** (`s[N..N+X)`) ile **baş** (`s[0..X)`) eşit-güç ağırlıkla
/// harmanlanır:
///
///   L[i] = s[i]·sin(θ) + s[N+i]·cos(θ),  θ = (i/X)·π/2,  i ∈ [0, X)
///   L[i] = s[i]                                        ,  i ∈ [X, N)
///
/// Bu, döngü dikişini **kurgusal olarak** sürekli kılar: L[N-1] = s[N-1] ve
/// L[0] = s[N] (çünkü sin0=0, cos0=1). Orijinal render'da `s[N-1] → s[N]` zaten
/// ardışık/süreklidir → dolayısıyla döngü dikişi de sürekli olur.
///
/// **Neden eşit-güç (sin/cos), lineer değil:** katmanlar KORELASYONSUZ gürültü.
/// Lineer crossfade'de harman bölgesinde güç ~3 dB düşer (duyulur bir ses azalması);
/// sin²+cos²=1 olduğu için eşit-güç, korelasyonsuz sinyallerde gücü SABİT tutar.
///
/// ## İSTİSNA — döngüye KİLİTLİ kaynaklar (#213)
///
/// Eşit-güç crossfade'in dayandığı varsayım "kuyruk ile baş KORELASYONSUZ"dur.
/// `LayerSource.pad` bu varsayımı bilerek çiğner: tamamen tonaldir ve her frekansı
/// döngüde tam sayıda periyot tamamlar → `s[n+i] = s[i]`, yani kuyruk ile baş
/// BİREBİR AYNIdır. Böyle bir sinyalde eşit-güç harmanı `s[i]·(sinθ + cosθ)`
/// verir; θ=π/4'te çarpan √2, yani **her döngü başında 50 ms boyunca +3 dB**.
/// Uyku uygulamasında 30 saniyede bir gelen bu kabarma tam da gizlemeye
/// çalıştığımız türden bir düzenliliktir.
///
/// Çözüm crossfade'i "düzeltmek" değil, GEREKSİZ olduğunu fark etmektir: kilitli
/// kaynakta `s[n] = s[0]` ve `s[n+1] = s[1]` zaten sağlanır → dikiş hem değerde
/// hem türevde süreklidir. Bu yüzden kilitli katman ham kopyalanır.
///
/// Karar KATMAN BAŞINAdır (`isLoopPeriodic`), spec başına değil: gürültü + pad
/// karışık bir mix'te gürültü crossfade'lenirken pad'in ham kalması gerekir.
/// (`MixPlayer` zaten katman başına ayrı çağırır; bu yol karışık spec'ler için.)
///
/// Bu bir OYNATMA (döngü) kaygısıdır; `renderMix` (native grafın eşleşeceği referans
/// offline render) BİLEREK dokunulmadan bırakıldı.
Float32List renderSeamlessLoop(
  MixSpec spec, {
  required int loopSeconds,
  int sampleRate = 48000,
  int seed = 0,
  Duration crossfade = const Duration(milliseconds: 50),
  void Function(int clipped)? onClipReport,
}) {
  assert(loopSeconds > 0);
  final n = sampleRate * loopSeconds;
  var x = (crossfade.inMicroseconds * sampleRate / 1e6).round();
  // Crossfade döngünün yarısını geçemez (kenar durumu: çok kısa döngü); güvenli kırp.
  if (x > n ~/ 2) x = n ~/ 2;
  if (x < 1) {
    // Crossfade istenmedi/anlamsız → düz N-örnek render (dikiş korunur ama çağıran
    // bilerek istemiş; sessiz bir "sorunsuz" yalanı üretmeyiz).
    return renderMix(spec,
        seconds: loopSeconds, sampleRate: sampleRate, seed: seed, onClipReport: onClipReport);
  }

  if (spec.layers.any((l) => isLoopPeriodic(l.type))) {
    return _renderPerLayerLoop(
      spec,
      n: n,
      x: x,
      sampleRate: sampleRate,
      seed: seed,
      onClipReport: onClipReport,
    );
  }

  // N+X üret: aynı deterministik dizinin devamı (kuyruk = döngü sonrası ne gelirdi).
  final s = renderMix(
    spec,
    seconds: loopSeconds,
    sampleRate: sampleRate,
    seed: seed,
    extraSamples: x,
    onClipReport: onClipReport,
  );

  final out = Float32List(n);
  // Harman bölgesi [0, X): kuyruğu başa eşit-güç harmanla.
  //
  // Clamp NEDENİ: eşit-güç ağırlıkları GÜCÜ korur ama anlık TOPLAM θ=π/4'te
  // sin+cos=√2'ye kadar çıkabilir → iki büyük aynı-işaretli örnek [-1,1]'i aşabilir
  // (korelasyonsuz gürültüde nadir). Dikiş örnekleri ETKİLENMEZ: i=0'da wIn=0 →
  // out[0]=s[n] (zaten [-1,1]); [X,N) bölgesi ham. Yani süreklilik kanıtı bozulmaz,
  // yalnızca nadir bir iç harman örneği kırpılır (mikserin clamp felsefesiyle aynı).
  final scale = (math.pi / 2) / x;
  for (var i = 0; i < x; i++) {
    final theta = i * scale;
    final wIn = math.sin(theta); // 0 → 1 (baş)
    final wOut = math.cos(theta); // 1 → 0 (kuyruk)
    final v = s[i] * wIn + s[n + i] * wOut;
    out[i] = v > 1.0 ? 1.0 : (v < -1.0 ? -1.0 : v);
  }
  // Kalan [X, N): değişmeden kopyala.
  for (var i = x; i < n; i++) {
    out[i] = s[i];
  }
  return out;
}

/// Katman başına crossfade yolu — spec'te en az bir **döngüye kilitli** kaynak
/// varsa kullanılır (bkz. dosya başındaki "İSTİSNA" notu).
///
/// Kilitli olmayan katmanlar tam olarak yukarıdaki eşit-güç harmanından geçer;
/// kilitli katmanlar ham kopyalanır. Toplama ve DC zinciri `mixLayerBuffers` ile
/// ortaktır → iki yolun mikser semantiği ayrışamaz.
///
/// ⚠️ Sıra farkı (bilinçli): burada DC engelleyici crossfade'den SONRA, düz yolda
/// ÖNCE çalışır. Düz yol bilerek bit-bit korundu (mevcut testler onu kilitliyor);
/// bu yol yalnız pad içeren spec'lerde devreye girer.
Float32List _renderPerLayerLoop(
  MixSpec spec, {
  required int n,
  required int x,
  required int sampleRate,
  required int seed,
  void Function(int clipped)? onClipReport,
}) {
  final scale = (math.pi / 2) / x;
  final buffers = <String, Float32List>{};

  for (var i = 0; i < spec.layers.length; i++) {
    final layer = spec.layers[i];
    final periodic = isLoopPeriodic(layer.type);
    // Kilitli katmanda kuyruğa hiç ihtiyaç yok (kuyruk = başın kopyası).
    final full = renderSource(
      layer.type,
      periodic ? n : n + x,
      seed: layerSeed(seed, i),
      sampleRate: sampleRate,
      loopSamples: n,
    );

    final lay = Float32List(n);
    if (periodic) {
      lay.setRange(0, n, full);
    } else {
      for (var k = 0; k < x; k++) {
        final theta = k * scale;
        lay[k] = full[k] * math.sin(theta) + full[n + k] * math.cos(theta);
      }
      for (var k = x; k < n; k++) {
        lay[k] = full[k];
      }
    }
    buffers[layer.id] = lay;
  }

  return mixLayerBuffers(
    spec,
    buffers,
    samples: n,
    sampleRate: sampleRate,
    onClipReport: onClipReport,
  );
}
