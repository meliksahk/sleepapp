/// **DOSYADAN** gelen mikser katmanı — sentezin karşıtı.
///
/// ## Neden `LayerSource`'a bir enum değeri EKLENMEDİ
///
/// İlk akla gelen `LayerSource.asset` eklemekti. Yanlış olurdu, iki sert sebeple:
///
/// 1. **`renderSource` onu üretemez.** O switch'in her dalı bir DSP algoritması
///    döndürür; "dosya" için döndürecek bir algoritma YOKTUR. Eklenirse dal ya
///    atar (çalma yolunda çökme) ya da sessizlik döndürür — ikincisi daha kötü:
///    kullanıcı sürgüyü açar, hiçbir şey duymaz, hata da görmez.
/// 2. **Sürüklenme kapısı.** `LayerSource` üç yerde aynı sırada yaşamak zorunda
///    (mobil enum, sunucu `LAYER_SOURCES`, panel listesi —
///    `tooling/check-layer-source-drift.mjs`). O liste SENTEZ kaynaklarının
///    sözleşmesidir; içine dosya koymak, panelde "asset" diye seçilebilen ama
///    hiçbir dosyaya işaret etmeyen bir tip üretirdi.
///
/// Bu yüzden asset katmanı [MixSpec] içinde **AYRI bir listede** durur. Sonuç
/// yapısaldır, disipline bağlı değil: `renderMix`/`renderSeamlessLoop`/
/// `renderSource` asset katmanını GÖREMEZ, dolayısıyla yanlışlıkla sentezlemeye
/// çalışamaz. Yollar derleyici seviyesinde ayrıdır.
///
/// ## ⚠️ Döngü dikişi — BİLİNEN ve KABUL EDİLEN sınır
///
/// Sentez katmanlarının dikişini `renderSeamlessLoop` çözüyor (kuyruk→baş eşit-güç
/// crossfade). Asset katmanında bu YAPILAMAZ: dosyayı biz üretmiyoruz, PCM'ine
/// çalma anında sahip değiliz ve `LoopMode.one` dosyayı olduğu gibi başa sarar.
/// **Dosya kendi başına dikişsiz değilse her döngüde tık duyulur.**
///
/// Karar: kabul + BEYAN. Kullanıcıya mikserde bir dipnotla söyleniyor
/// (`mixerAssetLoopNotice`), sessizce yaşanan bir kusur değil. Gerçek çözüm
/// (dosyayı çözüp kuyruğunu başına crossfade'lemek) native ses grafı işidir
/// (CLAUDE.md §3.1) — bugünkü `just_audio` katmanında PCM'e erişim yok.
library;

/// Mikserde çalan bir ses DOSYASI.
class AssetLayer {
  const AssetLayer({
    required this.id,
    required this.title,
    required this.url,
    required this.gain,
  });

  /// Mikser içinde benzersiz. Sentez katmanlarının id'leriyle de çakışmamalı:
  /// `MixPlayer.setLayerGain` id ile eşleştirir, çakışırsa sürgü YANLIŞ katmanı
  /// oynatır. Sunucudan gelen asset id'si uuid olduğu için pratikte çakışmaz;
  /// yine de [MixSpec.hasDuplicateIds] ile doğrulanabilir.
  final String id;

  /// Kullanıcıya gösterilen ad. **i18n'e girmez** — bu bir İÇERİK adıdır
  /// (sunucudaki `audio_assets.title`), arayüz metni değil. Arayüz metinleri
  /// arb'de yaşar; içerik adını arb'ye koymak yeni her dosya için çeviri
  /// gerektirirdi.
  final String title;

  /// Presigned HTTP URL ya da yerel dosya yolu. İkisi de desteklenir
  /// (bkz. `MixPlayer` içindeki `assetAudioUri`).
  final String url;

  /// [0,1].
  final double gain;

  AssetLayer copyWith({double? gain}) => AssetLayer(
        id: id,
        title: title,
        url: url,
        gain: gain ?? this.gain,
      );
}
