import 'package:flutter/material.dart';

import '../../core/audio_engine/dsp/mix_render.dart';
import '../../core/audio_engine/mix_player.dart';
import '../../core/media/mix_video_channel.dart';
import 'mix_video_exporter.dart';

/// Hatanın hangi işten geldiği.
///
/// **Neden ayrı bir alan:** UI önce `isExporting`e bakıp karar veriyordu ve bu
/// SESSİZCE yanlıştı — export patladığında ilerleme temizlendiği için `isExporting`
/// zaten `false` oluyor, kullanıcı video hatası için "ses başlatılamadı" görürdü
/// (ve çalan sesi kurcalamaya giderdi). Hatanın türü, hatayla birlikte taşınmalı.
enum MixerErrorKind {
  sound,
  export,

  /// Kullanıcı katalogdan bir ses EKLEMEK istedi ve olmadı (ağ, süresi dolmuş
  /// URL, bozuk dosya). [sound]'dan ayrı çünkü mix çalmaya devam ediyor —
  /// "ses başlatılamadı" demek yalan olurdu.
  assetAdd,
}

/// Mikser durumu — UI'ın gördüğü tek şey.
class MixerState {
  const MixerState({
    required this.layers,
    required this.gains,
    this.assets = const <AssetLayer>[],
    this.assetsUnavailable = false,
    this.isPlaying = false,
    this.isPreparing = false,
    this.exportProgress,
    this.error,
    this.errorKind,
  });

  final List<MixLayer> layers;

  /// DOSYA katmanları — sentez katmanlarıyla aynı mikserde, aynı sürgü davranışıyla.
  final List<AssetLayer> assets;

  /// En az bir dosya katmanı YÜKLENEMEDİ (dosya yok, ağ yok, kod çözücü bozuk).
  ///
  /// Bu bir HATA DEĞİL, dipnottur: mix çalmaya devam eder, yalnızca o katman
  /// eksiktir. `error`/`errorKind` kullanılmıyor çünkü onlar "ses başlamadı"
  /// anlamına gelir ve kullanıcıyı çalan bir sesin başında hata ekranına
  /// bakmaya iterdi (offline-first, CLAUDE.md §3.1).
  final bool assetsUnavailable;

  /// katman id → kazanç [0,1]. Spec'ten AYRI tutulur: slider her oynadığında yeni
  /// bir MixSpec üretmek, render'ı da tetiklemek anlamına gelirdi.
  final Map<String, double> gains;

  final bool isPlaying;
  final bool isPreparing;

  /// Video export'u sürerken 0..1, aksi hâlde null.
  ///
  /// Ayrı bir `isExporting` bayrağı YOK: iki alan birbirine yalan söyleyebilirdi
  /// (`isExporting: false, progress: 0.4`). Null = sürmüyor.
  final double? exportProgress;

  bool get isExporting => exportProgress != null;

  final String? error;

  /// [error] non-null ise dolu.
  final MixerErrorKind? errorKind;

  MixerState copyWith({
    List<MixLayer>? layers,
    List<AssetLayer>? assets,
    bool? assetsUnavailable,
    Map<String, double>? gains,
    bool? isPlaying,
    bool? isPreparing,
    double? exportProgress,
    bool clearExport = false,
    String? error,
    MixerErrorKind? errorKind,
    bool clearError = false,
  }) {
    return MixerState(
      layers: layers ?? this.layers,
      assets: assets ?? this.assets,
      assetsUnavailable: assetsUnavailable ?? this.assetsUnavailable,
      gains: gains ?? this.gains,
      isPlaying: isPlaying ?? this.isPlaying,
      isPreparing: isPreparing ?? this.isPreparing,
      exportProgress:
          clearExport ? null : (exportProgress ?? this.exportProgress),
      error: clearError ? null : (error ?? this.error),
      errorKind: clearError ? null : (errorKind ?? this.errorKind),
    );
  }
}

/// Varsayılan mix — uygulama ilk açıldığında duyulan şey.
///
/// Kazançlar toplamı 1'in altında tutuldu: katmanlar işletim sistemi mikserinde
/// toplandığı için (referans kompresör devrede değil, bkz. [MixPlayer]) yüksek
/// kazançlar OS seviyesinde kırpardı.
/// **#213:** meditatif kaynaklar (dalga/ateş/yağmur/pad) buraya eklendi — mikserin
/// vaadi "gürültüyü meditatif seslerle KARIŞTIR" ise, kullanıcının onları sürgü
/// olarak görmesi gerekir. Kazanç toplamı yine 1.00 (bkz. yukarıdaki gerekçe).
///
/// ⚠️ **MALİYET (gizlenmiyor):** katman başına 30 sn @48 kHz render + ~2.8 MB RAM.
/// 3 → 7 katman, ilk `prepare()` süresini ve bellek ayak izini ~2.3× büyütür.
/// Ölçüm raporda; native graf gelince (docs/04) bu tamamen değişecek.
MixSpec defaultMixSpec() => const MixSpec([
      MixLayer(id: 'brown', type: LayerSource.brown, gain: 0.28),
      MixLayer(id: 'pink', type: LayerSource.pink, gain: 0.12),
      MixLayer(id: 'white', type: LayerSource.white, gain: 0.06),
      MixLayer(id: 'waves', type: LayerSource.waves, gain: 0.22),
      MixLayer(id: 'rain', type: LayerSource.rain, gain: 0.14),
      MixLayer(id: 'fire', type: LayerSource.fire, gain: 0.10),
      MixLayer(id: 'pad', type: LayerSource.pad, gain: 0.08),
    ]);

/// Mikser ekranının denetleyicisi (docs/04 M2).
///
/// **Render PAHALI** (katman başına 30 sn @48kHz) ve yalnızca [prepare]'de bir kez
/// yapılır; slider `setLayerGain`'e gider → yeniden render YOK, ses kesilmez.
class MixerController {
  MixerController({MixPlayer? player, MixSpec? spec, MixVideoExporter? exporter})
      : _player = player ?? MixPlayer(),
        _exporter = exporter ??
            const MixVideoExporter(encoder: PlatformMixVideoEncoder()),
        _spec = spec ?? defaultMixSpec() {
    _state = MixerState(
      layers: _spec.layers,
      assets: _spec.assets,
      // Sentez ve dosya katmanları TEK kazanç haritasında: sürgü kodu ikisini
      // ayırt etmez, `MixPlayer.setLayerGain` de id ile çalışır.
      gains: {
        for (final l in _spec.layers) l.id: l.gain,
        for (final a in _spec.assets) a.id: a.gain,
      },
    );
  }

  final MixPlayer _player;
  final MixVideoExporter _exporter;
  final MixSpec _spec;

  late MixerState _state;
  MixerState get state => _state;

  /// UI'ın yeniden çizilmesi için dinleyici. Riverpod/setState ikisi de bağlanabilir.
  void Function()? onChanged;

  void _emit(MixerState next) {
    _state = next;
    onChanged?.call();
  }

  /// Katmanları render edip player'lara yükler. İlk seste bir kez.
  ///
  /// **`_spec` DEĞİL [currentSpec] yüklenir.** `_spec` kurulum anının fotoğrafı:
  /// kullanıcı çalmaya basmadan ÖNCE bir dosya eklediyse (katalog mikser
  /// açılır açılmaz erişilebilir) o katman `_spec`'te YOKTUR ve sessizce
  /// yüklenmezdi — sürgüsü ekranda duran, sesi olmayan bir katman. Aynı şey
  /// çalmadan önce oynatılan sürgüler için de geçerliydi.
  Future<void> prepare() async {
    _emit(_state.copyWith(isPreparing: true, clearError: true));
    try {
      await _player.load(currentSpec());
      // Düşen dosya katmanı varsa mix YİNE ÇALAR; kullanıcı yalnızca eksikliği
      // öğrenir (yoksa "sürgüyü açtım ama ses gelmiyor" diye motoru suçlar).
      _emit(_state.copyWith(
        isPreparing: false,
        assetsUnavailable: _player.failedAssetIds.isNotEmpty,
      ));
    } catch (e) {
      // Hata YUTULMAZ (CLAUDE.md §4): kullanıcı sessiz bir ekranla kalmamalı.
      _emit(_state.copyWith(
        isPreparing: false,
        error: e.toString(),
        errorKind: MixerErrorKind.sound,
      ));
    }
  }

  Future<void> toggle() async {
    if (_state.isPlaying) {
      await _player.pause();
      _emit(_state.copyWith(isPlaying: false));
      return;
    }
    if (_player.voiceCount == 0) {
      await prepare();
      if (_state.error != null) return;
    }
    await _player.play();
    _emit(_state.copyWith(isPlaying: true));
  }

  /// Katalogdan seçilen dosyayı mikse KATMAN olarak ekler.
  ///
  /// Dönüş: eklendi mi (UI hata gösterip göstermeyeceğine buna bakar).
  ///
  /// İki hâl var ve ikisi de bilinçli:
  /// - **Mix hazır (`prepare` olmuş):** katman canlı eklenir, mix çalıyorsa
  ///   yeni katman da hemen başlar. Yükleme patlarsa katman EKLENMEZ ve hata
  ///   söylenir — sesi olmayan bir sürgü bırakmak, kullanıcıya sessizce yalan
  ///   söylemek olurdu.
  /// - **Mix henüz hazır değil:** yalnızca state'e girer; [prepare] artık
  ///   [currentSpec]'i yüklediği için ilk çalışta o da yüklenir.
  ///
  /// Aynı id ikinci kez eklenemez: `MixPlayer.setLayerGain` id ile eşleştiği
  /// için çakışan iki katmanda sürgü YANLIŞ katmanı oynatırdı.
  Future<bool> addAsset(AssetLayer asset) async {
    if (_state.gains.containsKey(asset.id)) return false;

    if (_player.voiceCount > 0) {
      final ok = await _player.addAsset(asset, autoPlay: _state.isPlaying);
      if (!ok) {
        _emit(_state.copyWith(
          error: 'asset load failed: ${asset.id}',
          errorKind: MixerErrorKind.assetAdd,
        ));
        return false;
      }
    }

    _emit(_state.copyWith(
      assets: <AssetLayer>[..._state.assets, asset],
      gains: <String, double>{..._state.gains, asset.id: asset.gain},
      clearError: true,
    ));
    return true;
  }

  /// Katman EKLENEMEDİ — dosyanın adresi çözülemedi (404: dosya silinmiş, 401:
  /// oturum düştü, ya da ağ yok).
  ///
  /// Bu iş controller'ın DIŞINDA oluyor (presigned URL'i UI katmanı çözüyor) ama
  /// hata yine buraya bildiriliyor: ekranda tek bir hata yüzeyi olsun, iki ayrı
  /// mekanizma birbirinin üstüne yazmasın.
  void reportAssetAddFailed(Object error) {
    _emit(_state.copyWith(
      error: error.toString(),
      errorKind: MixerErrorKind.assetAdd,
    ));
  }

  /// Eklenen dosya katmanını mikserden çıkarır (sesi de susar).
  ///
  /// **Neden var:** ekleyip vazgeçememek, katalogdan denemeyi tek yönlü bir
  /// karara çevirirdi — kullanıcı yanlış dosyayı seçtiğinde tek çıkışı ekranı
  /// kapatmak olurdu. Yalnızca DOSYA katmanları kaldırılabilir; sentez
  /// katmanları tarifin kendisidir (sürgüsü zaten 0'a çekilebilir).
  Future<void> removeAsset(String id) async {
    if (!_state.assets.any((a) => a.id == id)) return;
    await _player.removeVoice(id);
    final gains = Map<String, double>.from(_state.gains)..remove(id);
    _emit(_state.copyWith(
      assets: <AssetLayer>[
        for (final a in _state.assets)
          if (a.id != id) a,
      ],
      gains: gains,
      // Kaldırılan katman "yüklenemeyen" katmansa dipnot da gitmeli: kullanıcı
      // sorunu ÇÖZDÜ, uyarının ekranda kalması ona yalan söylerdi.
      assetsUnavailable: _player.failedAssetIds.isNotEmpty,
    ));
  }

  /// Slider'ın çağırdığı yer. Render YOK — yalnızca ses seviyesi.
  Future<void> setGain(String id, double gain) async {
    final next = Map<String, double>.from(_state.gains)..[id] = gain;
    _emit(_state.copyWith(gains: next));
    await _player.setLayerGain(id, gain);
  }

  /// Kullanıcının ŞU AN duyduğu mix.
  ///
  /// `_spec` DEĞİL: `_spec` katmanların ilk kazançlarını taşır. Slider'ları oynatıp
  /// video export eden kullanıcı, duymadığı bir mix'i paylaşırdı.
  /// ⚠️ Dosya katmanları burada TAŞINIR ama video export'unda KULLANILMAZ:
  /// `renderMix` yalnızca sentez katmanlarını görür (bkz. [MixSpec]). Yani
  /// paylaşılan videoda dosya katmanları duyulmaz. Bilinen sınır, gizlenmiyor.
  MixSpec currentSpec() => MixSpec(
        [
          for (final l in _state.layers)
            MixLayer(id: l.id, type: l.type, gain: _state.gains[l.id] ?? l.gain),
        ],
        assets: [
          for (final a in _state.assets) a.copyWith(gain: _state.gains[a.id] ?? a.gain),
        ],
      );

  /// Mix'i paylaşılabilir 9:16 videoya çevirir — **viral kanca #3**.
  ///
  /// Dosya yolunu döndürür; export patlarsa **null** döner ve hata state'e yazılır
  /// (çağıran UI, atmayı beklemek zorunda kalmasın).
  ///
  /// [seconds] kısa tutulur: kare başına bir render var, 15 sn @24fps = 360 render.
  /// Daha uzunu export'u dakikalara çıkarır ve sosyal platformlar zaten kırpar.
  Future<String?> exportVideo({
    required String title,
    required LinearGradient gradient,
    int seconds = 15,
  }) async {
    if (_state.isExporting) return null; // çift basış ikinci oturum açmasın
    _emit(_state.copyWith(exportProgress: 0, clearError: true));
    try {
      final path = await _exporter.export(
        spec: currentSpec(),
        title: title,
        gradient: gradient,
        seconds: seconds,
        onProgress: (p) => _emit(_state.copyWith(exportProgress: p)),
      );
      _emit(_state.copyWith(clearExport: true));
      return path;
    } catch (e) {
      // Hata YUTULMAZ (CLAUDE.md §4): teknik detay state'e, kullanıcıya sade metin.
      _emit(_state.copyWith(
        clearExport: true,
        error: e.toString(),
        errorKind: MixerErrorKind.export,
      ));
      return null;
    }
  }

  Future<void> dispose() => _player.dispose();
}
