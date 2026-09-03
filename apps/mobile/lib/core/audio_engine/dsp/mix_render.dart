import 'dart:typed_data';

import 'asset_layer.dart';
import 'dc_blocker.dart';
import 'material.dart';
import 'meditative.dart';
import 'mixer.dart';
import 'noise.dart';
import 'tone.dart';
import 'user_melodic.dart';

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
  tone,
  chords,
  arpeggio,
  ceramic,
  chimes,
  topSpin,
  friction,
}

/// Kaynak, döngü periyoduna **kilitli** mi (kuyruk ile baş birebir aynı mı)?
///
/// `renderSeamlessLoop` buna bakarak crossfade'i uygular ya da ATLAR. Kilitli bir
/// kaynağa eşit-güç crossfade uygulamak zararlıdır: aynı sinyalin kendisiyle
/// sin+cos ağırlıklı toplamı √2'ye kadar çıkar → döngü başında +3 dB kabarma.
/// Kilitli kaynakta crossfade'e GEREK de yoktur, çünkü süreklilik zaten sağlanır.
///
/// `tone` pad ile AYNI gerekçeyle kilitlidir: saf sinüstür ve frekansı
/// `loopLockedHz` ile ızgaraya oturtulur → kuyruk = baş (bkz. `tone.dart`).
bool isLoopPeriodic(LayerSource type) =>
    type == LayerSource.pad ||
    type == LayerSource.tone ||
    type == LayerSource.chords ||
    type == LayerSource.arpeggio ||
    type == LayerSource.ceramic ||
    type == LayerSource.chimes ||
    type == LayerSource.topSpin ||
    type == LayerSource.friction;

/// Tek bir mikser katmanı: hangi kaynak, hangi kazanç.
class MixLayer {
  const MixLayer({
    required this.id,
    required this.type,
    required this.gain,
    this.frequencyHz,
    this.beatHz,
    this.rootSemi,
    this.waveform,
    this.tempoScale,
    this.patternIdx,
  });

  final String id;
  final LayerSource type;

  /// [0,1] — mikser zaten sıkıştırır.
  final double gain;

  /// `tone` için temel frekans (Hz). Diğer kaynaklarda **null OLMALI** —
  /// sunucu sözleşmesi de öyle doğrular (`mixer-state.ts`): ton dışı katmanda
  /// alan varsa tarif reddedilir, ton katmanında alan YOKSA reddedilir.
  ///
  /// Değer kullanıcının İSTEDİĞİ frekanstır; motor onu döngü ızgarasına
  /// oturtur. Duyulan gerçek değer `toneGridHz` ile hesaplanır (UI etiketi).
  final double? frequencyHz;

  /// `tone` için opsiyonel **binaural vuru** (Hz/s). null → mono ton; > 0 →
  /// MixPlayer bu katmanı STEREO ses olarak çalar (L=taban, R=taban+vuru);
  /// `renderMix` (mono referans/export) ise iki kanalın indirgemesini üretir
  /// (tremololu mono — fark bilinçli ve belgeli; tone.dart).
  ///
  /// Sunucu sözleşmesiyle BİREBİR (mixer-state.ts `beatHz`): yalnızca tone'da,
  /// (0.5, 20] Hz, yokluk = mono. Alan sözleşme üyesidir — parse edilmiş tarif
  /// yazılırken düşürülseydi editörün binaural tarifi sessizce mono olurdu.
  final double? beatHz;

  /// `chords`/`arpeggio`: kök nota kayması (yarım-ses, A2'den). Mobil-özel.
  final int? rootSemi;

  /// `chords`/`arpeggio`: dalga şekli ('sine','triangle','saw','square'). Mobil-özel.
  final String? waveform;

  /// `chords`/`arpeggio`: tempo ölçeği (1.0=normal, 2.0=2× hızlı). Mobil-özel.
  final double? tempoScale;

  /// `chords`: progresyon indeksi. `arpeggio`: ölçek indeksi. Mobil-özel.
  final int? patternIdx;
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
  double? frequencyHz,
  double? beatHz,
  int? rootSemi,
  String? waveform,
  double? tempoScale,
  int? patternIdx,
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
    case LayerSource.tone:
      // Tonun içinde rastgelelik yok → seed anlamsızdır (bkz. tone.dart).
      // frequencyHz null olamaz: sunucu sözleşmesi ton katmanında alanı
      // ZORUNLU kılar; buraya null gelirse çağıran sözleşmeyi bozmuştur.
      assert(frequencyHz != null, 'tone katmanı frequencyHz olmadan render edilemez');
      if (beatHz != null && beatHz > 0) {
        // MONO yol = binaural'ın TAM indirgemesi (tremololu taşıyıcı). Stereo
        // çalma MixPlayer'da olur; bu fonksiyon export/native-referans yoludur.
        return toneMonoFromBinaural(
          samples,
          baseHz: frequencyHz ?? (toneMinHz + toneMaxHz) / 2,
          beatHz: beatHz,
          sampleRate: sampleRate,
          loopSamples: loopSamples,
        );
      }
      return toneSource(
        samples,
        frequencyHz: frequencyHz ?? (toneMinHz + toneMaxHz) / 2,
        sampleRate: sampleRate,
        loopSamples: loopSamples,
      );
    case LayerSource.chords:
      return userChordsSource(
        samples,
        sampleRate: sampleRate,
        loopSamples: loopSamples,
        rootSemi: rootSemi ?? 0,
        progressionIdx: patternIdx ?? 0,
        waveform: waveform != null ? Waveform.values.firstWhere((w) => w.name == waveform, orElse: () => Waveform.sine) : Waveform.sine,
        tempoScale: tempoScale ?? 1.0,
      );
    case LayerSource.arpeggio:
      return userArpeggioSource(
        samples,
        seed: seed,
        sampleRate: sampleRate,
        loopSamples: loopSamples,
        rootSemi: rootSemi ?? 0,
        scaleIdx: patternIdx ?? 0,
        waveform: waveform != null ? Waveform.values.firstWhere((w) => w.name == waveform, orElse: () => Waveform.sine) : Waveform.sine,
        tempoScale: tempoScale ?? 1.0,
      );
    case LayerSource.ceramic:
      return ceramicSource(samples, seed: seed, sampleRate: sampleRate, loopSamples: loopSamples);
    case LayerSource.chimes:
      return chimesSource(samples, seed: seed, sampleRate: sampleRate, loopSamples: loopSamples);
    case LayerSource.topSpin:
      return topSpinSource(samples, seed: seed, sampleRate: sampleRate, loopSamples: loopSamples);
    case LayerSource.friction:
      return frictionSource(samples, seed: seed, sampleRate: sampleRate, loopSamples: loopSamples);
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
      frequencyHz: layer.frequencyHz,
      beatHz: layer.beatHz,
      rootSemi: layer.rootSemi,
      waveform: layer.waveform,
      tempoScale: layer.tempoScale,
      patternIdx: layer.patternIdx,
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
