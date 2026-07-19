import 'dart:typed_data';

import 'asset_layer.dart';
import 'dc_blocker.dart';
import 'meditative.dart';
import 'mixer.dart';
import 'noise.dart';

export 'asset_layer.dart' show AssetLayer;

/// Mix tanımı ve **offline render** — DSP zincirinin birleştiği yer:
/// kaynaklar → [Mixer] → [DcBlocker].
///
/// Bu, native grafın (AVAudioEngine/Oboe) eşleşmesi gereken **referans**
/// implementasyondur; ayrıca mix-to-video export'unun (viral kanca #3) ihtiyaç
/// duyduğu offline üretimin ta kendisidir. Spekülatif değil, ürün yolunda.

/// Mikserin çalabildiği jeneratif kaynaklar.
///
/// **Neden `NoiseType` DEĞİL (#213'te yeniden adlandırıldı):** liste artık yalnız
/// gürültü içermiyor — `waves`/`fire`/`rain` gürültü YATAĞI üstüne zarf ve
/// transient kuran dokular, `pad` ise içinde hiç gürültü olmayan tonal bir kaynak.
/// "NoiseType.pad" yazan bir satır okuyanı yanıltırdı ve ileride "gürültü olmayan
/// şeyi buraya koyamayız" diye yanlış bir kısıt doğururdu. Tel üzerindeki
/// dizgiler (`'white'`, `'pink'`, ...) DEĞİŞMEDİ: sunucudaki mevcut tarifler ve
/// veritabanındaki 6 seed reçetesi aynen geçerli kalır.
///
/// Sunucu karşılığı: `apps/api/src/modules/content/domain/mixer-state.ts`
/// (`LAYER_SOURCES`). İki liste `tooling/check-layer-source-drift.mjs` ile
/// karşılaştırılır — ayrışırlarsa CI kırmızıya döner.
enum LayerSource {
  white,
  pink,
  brown,
  waves,
  fire,
  rain,
  pad,
}

/// Kaynak, döngü periyoduna **kilitli** mi (kuyruk ile baş birebir aynı mı)?
///
/// `renderSeamlessLoop` buna bakarak crossfade'i uygular ya da ATLAR. Kilitli bir
/// kaynağa eşit-güç crossfade uygulamak zararlıdır: aynı sinyalin kendisiyle
/// sin+cos ağırlıklı toplamı √2'ye kadar çıkar → döngü başında +3 dB kabarma.
/// Kilitli kaynakta crossfade'e GEREK de yoktur, çünkü süreklilik zaten sağlanır.
bool isLoopPeriodic(LayerSource type) => type == LayerSource.pad;

/// Tek bir mikser katmanı: hangi kaynak, hangi kazanç.
class MixLayer {
  const MixLayer({required this.id, required this.type, required this.gain});

  final String id;
  final LayerSource type;

  /// [0,1] — mikser zaten sıkıştırır.
  final double gain;
}

/// Bir mix'in tanımı (preset). Katman sırası render'ı etkilemez (toplama).
///
/// **İKİ AYRI LİSTE — bilinçli:** [layers] sentezlenir (bu dosyadaki render
/// zinciri), [assets] dosyadan çalınır (`MixPlayer`, render YOK). Tek listede
/// tutup "tipine bak" deseydik, render fonksiyonlarının HER BİRİ o ayrımı
/// hatırlamak zorunda kalırdı; unutan ilk fonksiyon bir dosyayı sentezlemeye
/// çalışırdı. Ayrı liste, hatayı yapısal olarak imkânsız kılar: render zinciri
/// [assets]'i hiç görmez.
///
/// ⚠️ **Bunun bedeli — `renderMix` asset katmanını ATLAR.** Yani mix-to-video
/// export'u (viral kanca #3) asset katmanlarını İÇERMEZ; paylaşılan videoda
/// yalnızca sentez katmanları duyulur. Gizlenmiyor: bkz. `MixVideoExporter` ve
/// rapor. Çözümü dosyayı çözüp PCM'ini karıştırmaktır (native graf işi).
class MixSpec {
  const MixSpec(this.layers, {this.assets = const <AssetLayer>[]});

  /// SENTEZ katmanları — `renderMix`/`renderSeamlessLoop` yalnızca bunları görür.
  final List<MixLayer> layers;

  /// DOSYA katmanları — render EDİLMEZ, `MixPlayer` doğrudan çalar.
  final List<AssetLayer> assets;

  /// Sentez + dosya, mikserdeki görünme sırasıyla toplam katman sayısı.
  int get totalLayerCount => layers.length + assets.length;

  /// Aynı id iki katmanda mı? `setLayerGain` id ile eşleştiği için çakışma,
  /// sürgünün YANLIŞ katmanı oynatması demektir (sessiz ve teşhisi zor bir hata).
  bool get hasDuplicateIds {
    final seen = <String>{};
    for (final l in layers) {
      if (!seen.add(l.id)) return true;
    }
    for (final a in assets) {
      if (!seen.add(a.id)) return true;
    }
    return false;
  }
}

/// Katman başına seed türetir. **Kritik:** tüm katmanlar aynı seed'i kullanırsa
/// aynı gürültü üretilir → katmanlar birebir korelasyonlu olur ve toplama sesi
/// zenginleştirmek yerine sadece yükseltir. Asal çarpanla ayrıştırıyoruz.
int layerSeed(int baseSeed, int index) => baseSeed + (index + 1) * 7919;

/// Tek bir kaynağı üretir. `renderSeamlessLoop` de bunu kullanır (katman başına
/// crossfade kararı verebilmek için) — üretim mantığı tek yerde kalsın diye public.
///
/// [loopSamples]: döngünün NOMİNAL uzunluğu (extraSamples HARİÇ). Meditatif
/// kaynaklar modülasyon periyotlarını ve transient guard'ını buna göre kilitler;
/// bu bilgi olmadan "30 sn'yi tam bölen periyot" hesaplanamaz.
Float32List renderSource(
  LayerSource type,
  int samples, {
  required int seed,
  required int sampleRate,
  required int loopSamples,
}) {
  switch (type) {
    case LayerSource.white:
      return whiteNoise(samples, seed: seed);
    case LayerSource.pink:
      return pinkNoise(samples, seed: seed);
    case LayerSource.brown:
      return brownNoise(samples, seed: seed);
    case LayerSource.waves:
      return wavesSource(samples,
          seed: seed, sampleRate: sampleRate, loopSamples: loopSamples);
    case LayerSource.fire:
      return fireSource(samples,
          seed: seed, sampleRate: sampleRate, loopSamples: loopSamples);
    case LayerSource.rain:
      return rainSource(samples,
          seed: seed, sampleRate: sampleRate, loopSamples: loopSamples);
    case LayerSource.pad:
      return padSource(samples,
          seed: seed, sampleRate: sampleRate, loopSamples: loopSamples);
  }
}

/// Hazır katman buffer'larını kazançlarıyla toplar ve DC'yi temizler.
///
/// `renderMix` ve `renderSeamlessLoop` (periyodik yol) ortak kullanır: toplama +
/// DC zinciri iki yerde yazılsaydı biri sessizce eskirdi.
Float32List mixLayerBuffers(
  MixSpec spec,
  Map<String, Float32List> buffers, {
  required int samples,
  required int sampleRate,
  void Function(int clipped)? onClipReport,
}) {
  final mixer = Mixer(sampleRate: sampleRate);
  for (final layer in spec.layers) {
    mixer.setGain(layer.id, layer.gain, immediate: true);
  }
  final out = Float32List(samples);
  mixer.mixInto(out, buffers);
  DcBlocker().process(out);
  onClipReport?.call(mixer.clippedSamples);
  return out;
}

/// [spec]'i [seconds] saniyelik tek bir buffer'a render eder.
///
/// Kazançlar `immediate` uygulanır (offline render'da rampa gereksiz: tık ancak
/// ÇALARKEN kazanç değişirse olur; burada başlangıç durumu zaten hedeftir).
/// Çıkışta DC engelleyici çalışır → pembe katmanların artık DC'si temizlenir (#95/#96).
///
/// [clippedSamples] non-null verilirse kırpılan örnek sayısı oraya yazılır —
/// çağıran headroom'u görebilsin (mikser sessizce bozmaz).
///
/// [extraSamples] > 0 verilirse `seconds`in ÜSTÜNE o kadar örnek daha üretilir
/// (aynı deterministik gürültü dizisinin devamı). Sorunsuz döngü crossfade'i
/// (`renderSeamlessLoop`) bunu kullanır: kuyruğu başa harmanlamak için döngü
/// uzunluğunun biraz ötesini ister. Süreç aksi halde değişmez.
Float32List renderMix(
  MixSpec spec, {
  required int seconds,
  int sampleRate = 48000,
  int seed = 0,
  int extraSamples = 0,
  int? loopSeconds,
  void Function(int clipped)? onClipReport,
}) {
  assert(seconds > 0);
  assert(extraSamples >= 0);
  assert(loopSeconds == null || loopSeconds > 0);
  final samples = sampleRate * seconds + extraSamples;

  // Meditatif kaynakların döngü kilidi NOMİNAL döngü uzunluğuna göredir: kuyruk
  // (extraSamples) döngünün "devamı"dır, periyodu uzatmaz.
  //
  // **[loopSeconds] NEDEN AYRI BİR PARAMETRE — ÖLÇÜLMÜŞ BİR HATA:** başta döngü
  // periyodu `seconds`ten türetiliyordu, yani "ne kadar render ediyorsam döngüm
  // o kadardır" varsayılıyordu. Bu, ÇALMA yolunda doğru (MixPlayer 30 sn render
  // edip 30 sn döngüler) ama EXPORT yolunda YANLIŞ: mix-to-video 15 sn'lik TEK
  // ATIMLIK bir render yapıyor, döngülemiyor. Sonuç: dalga kabarması çalarken
  // 10 sn iken paylaşılan videoda 7.5 sn oluyordu — kullanıcı duyduğundan farklı
  // bir sesi paylaşıyordu (viral kanca #3). Ölçüldü: 30 sn render'da zarf enerjisi
  // @10 sn = 0.76, 15 sn render'da @7.5 sn = 0.77.
  //
  // Artık çağıran, döngü periyodunu AÇIKÇA söyler. Verilmezse eski davranış
  // (periyot = render süresi) korunur — döngü uzunluğu ile render uzunluğunun
  // aynı olduğu çağrılar için doğrudur.
  final loopSamples = sampleRate * (loopSeconds ?? seconds);

  final buffers = <String, Float32List>{};
  for (var i = 0; i < spec.layers.length; i++) {
    final layer = spec.layers[i];
    buffers[layer.id] = renderSource(
      layer.type,
      samples,
      seed: layerSeed(seed, i),
      sampleRate: sampleRate,
      loopSamples: loopSamples,
    );
  }

  return mixLayerBuffers(
    spec,
    buffers,
    samples: samples,
    sampleRate: sampleRate,
    onClipReport: onClipReport,
  );
}
