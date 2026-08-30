import 'package:flutter/material.dart';

import '../../core/audio_engine/dsp/mix_render.dart';
import '../../core/audio_engine/dsp/tone.dart' show toneMaxHz, toneMinHz;
import '../../core/audio_engine/master_limiter.dart';
import '../../core/audio_engine/mix_player.dart';
import '../../core/media/mix_video_channel.dart';
import '../../core/storage/key_value_store.dart';
import '../mixer/data/mix_state_store.dart';
import '../mixer/domain/melodic_preset_store.dart';
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

  /// Kullanıcı mikste ZATEN olan bir sesi tekrar seçti.
  ///
  /// [assetAdd]'den ayrı: ortada arıza yok, yalnızca yapılacak bir şey yok — ama
  /// kullanıcıya SÖYLENMESİ gerekir. Eskiden bu yol sessizce hiçbir şey yapmıyordu.
  assetDuplicate,

  /// Katman tavanı dolu: yeni bir sentez katmanı eklenemez.
  ///
  /// [assetAdd]'den ayrı: dosya yüklemesi değil, BÜTÇE reddi. CPU/RAM bütçesi
  /// (katman başına ~2.8 MB RAM + render süresi) sunucu sözleşmesindeki
  /// MAX_MIXER_LAYERS ile aynı sayıda tutulur; aşılırsa sessizce eklememek,
  /// kullanıcıya "dolu" demekten beterdir.
  layerLimit,
}

/// [MixerController.addToneLayer] sonucu. `duplicate` YOK: id'yi controller
/// üretir, çakışma imkânsızdır — enum'da olmayan durum, olmayan koddur.
enum AddToneOutcome { added, full }

/// [MixerController.addSource] sonucu.
enum AddSourceOutcome { added, duplicate, full }

/// Kullanıcının yeniden ekleyebileceği kaynakların varsayılan kazancı.
///
/// 0.25: tek başına duyulur ama mevcut mix'in üstüne çıkmaz.
const double defaultSourceGain = 0.25;

/// [MixerController.addAsset] sonucu.
///
/// **`bool` DEĞİL:** eski dönüş `false`'u iki ayrı şey için kullanıyordu —
/// "zaten ekli" ve "yüklenemedi". Çağıran ikisini ayırt edemediği için ikisini de
/// yok sayıyordu; kullanıcı ne olduğunu hiç öğrenmiyordu.
enum AddAssetOutcome { added, duplicate, loadFailed }

/// Mikser durumu — UI'ın gördüğü tek şey.
class MixerState {
  const MixerState({
    required this.layers,
    required this.gains,
    this.assets = const <AssetLayer>[],
    this.userAddedSynthIds = const <String>[],
    this.assetsUnavailable = false,
    this.isPlaying = false,
    this.isPreparing = false,
    this.limiterScale = 1.0,
    this.exportProgress,
    this.error,
    this.errorKind,
  });

  final List<MixLayer> layers;

  /// Kullanıcının kendisinin eklediği SENTEZ katmanlarının id'leri (bugün yalnız
  /// tone). Bu id'ler kaldırılabilir; tarifle gelen sentez katmanları gelmez —
  /// onlar tarifin kendisidir (sürgü 0'a çekilebilir ama satır silinemez).
  final List<String> userAddedSynthIds;

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

  /// Master limitleyicinin UYGULADIĞI ölçek. 1.0 → devrede değil.
  ///
  /// **[gains] ile karıştırılmamalı:** `gains` kullanıcının sürgüleridir ve
  /// limitleyici onlara ASLA dokunmaz. Bu ayrı alan, çıkışın ne kadar kısıldığını
  /// söyler; sürgüde %70 yazıyorsa %70 yazmaya devam eder.
  final double limiterScale;

  /// Kullanıcıya gösterge gösterilecek mi.
  bool get isLimiting => isLimiterEngaged(limiterScale);

  /// Çıkışın kısıldığı oran, yüzde (gösterge metni için). 0 → kısılma yok.
  int get limiterReductionPercent => ((1.0 - limiterScale) * 100).round();

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
    List<String>? userAddedSynthIds,
    bool? assetsUnavailable,
    Map<String, double>? gains,
    bool? isPlaying,
    bool? isPreparing,
    double? limiterScale,
    double? exportProgress,
    bool clearExport = false,
    String? error,
    MixerErrorKind? errorKind,
    bool clearError = false,
  }) {
    return MixerState(
      layers: layers ?? this.layers,
      assets: assets ?? this.assets,
      userAddedSynthIds: userAddedSynthIds ?? this.userAddedSynthIds,
      assetsUnavailable: assetsUnavailable ?? this.assetsUnavailable,
      gains: gains ?? this.gains,
      isPlaying: isPlaying ?? this.isPlaying,
      isPreparing: isPreparing ?? this.isPreparing,
      limiterScale: limiterScale ?? this.limiterScale,
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
  MixerController({MixPlayer? player, MixSpec? spec, MixVideoExporter? exporter, MixStateStore? stateStore})
      : _player = player ?? MixPlayer(),
        _exporter = exporter ??
            const MixVideoExporter(encoder: PlatformMixVideoEncoder()),
        _spec = spec ?? defaultMixSpec(),
        _stateStore = stateStore {
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
    // Limitleyicinin GERÇEK durumu motorda; UI onu buradan öğrenir.
    // State'ten türetmek (gains toplamına bakmak) yanlış olurdu: rampa sürerken
    // motorun UYGULADIĞI ölçek hedeften farklıdır ve kullanıcıya gösterilen şey,
    // duyduğu şey olmalı.
    _player.onLimiterChanged = (scale) {
      if (scale == _state.limiterScale) return; // gereksiz rebuild yok
      _emit(_state.copyWith(limiterScale: scale));
    };
  }

  final MixPlayer _player;
  final MixVideoExporter _exporter;
  final MixSpec _spec;
  final MixStateStore? _stateStore;


  late MixerState _state;
  MixerState get state => _state;

  /// UI'ın yeniden çizilmesi için dinleyici. Riverpod/setState ikisi de bağlanabilir.
  void Function()? onChanged;

  void _emit(MixerState next) {
    _state = next;
    onChanged?.call();
  }

  /// Kayıtlı son mix'i yükler (varsa) ve state'i günceller.
  ///
  /// Mikser ekranının initState'inden çağrılır: kullanıcı uygulama kapatıp
  /// açtığında SON mix'i görmeli, her seferinde varsayılana sıfırlanmamalı
  /// (kullanıcı isteği).
  Future<void> initFromStore() async {
    final store = _stateStore;
    if (store == null) return;
    final saved = await store.load();
    if (saved == null || saved.layers.isEmpty) return;
    // _spec DOKUNULMAZ (final): savedSpec state'e yazılır, currentSpec()
    // artık _savedSpec ?? _spec mantığıyla çalışır.
    _emit(MixerState(
      layers: saved.layers,
      gains: {for (final l in saved.layers) l.id: l.gain},
    ));
  }

  /// Mevcut mix'i KALICI kaydeder — her gain değişiminde çağrılır.
  Future<void> _persistState() async {
    await _stateStore?.save(currentSpec());
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
  Future<AddAssetOutcome> addAsset(AssetLayer asset) async {
    // Çakışan id, sürgünün YANLIŞ katmanı oynatması demek — ama artık SESSİZ
    // değil: çağıran kullanıcıya "bu ses zaten mikste" diyebilsin.
    if (_state.gains.containsKey(asset.id)) return AddAssetOutcome.duplicate;

    if (_player.voiceCount > 0) {
      final ok = await _player.addAsset(asset, autoPlay: _state.isPlaying);
      if (!ok) {
        _emit(_state.copyWith(
          error: 'asset load failed: ${asset.id}',
          errorKind: MixerErrorKind.assetAdd,
        ));
        return AddAssetOutcome.loadFailed;
      }
    }

    _emit(_state.copyWith(
      assets: <AssetLayer>[..._state.assets, asset],
      gains: <String, double>{..._state.gains, asset.id: asset.gain},
      clearError: true,
    ));
    return AddAssetOutcome.added;
  }

  /// Kullanıcı mikste zaten olan bir sesi seçti — söylenmesi gereken bir durum,
  /// arıza değil.
  void reportDuplicateAsset() {
    _emit(_state.copyWith(
      error: 'duplicate asset',
      errorKind: MixerErrorKind.assetDuplicate,
    ));
  }

  /// Katman tavanı doldu — "Ton ekleyemedim" demenin tek dürüst yolu.
  ///
  /// Renk/ton ayrımı UI'da: bu bir arıza değil BÜTÇE bildirimidir
  /// ([MixerErrorKind.layerLimit]), danger değil inkSecondary gösterilir.
  void reportLayerLimit() {
    _emit(_state.copyWith(
      error: 'layer limit reached',
      errorKind: MixerErrorKind.layerLimit,
    ));
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

  /// Kullanıcının ekleyebileceği TOPLAM katman sınırı (sentez + dosya).
  ///
  /// Sunucu sözleşmesindeki MAX_MIXER_LAYERS ile aynı sayı: tarifte 8'i geçen
  /// mix reddediliyorsa lokalde de aynı bütçe geçerli olmalı — aksi hâlde
  /// "kayıtlı tarifle açılır, elle genişletilmiş hâliyle çökmez" ayrımı doğar.
  static const int maxTotalLayers = 8;

  /// Yeni tone katmanının varsayılan kazancı.
  ///
  /// Düşük tutuldu (dosyanın 0.3'üne yakın mantık): saf sinüs algısal olarak
  /// gürültüden baskındır; kullanıcının mevcut mix'inin üstüne BİRDEN binen bir
  /// uğultu gece yarısı uyandırır. Sürgüyle yükseltir.
  static const double defaultToneGain = 0.20;

  /// Kullanıcıdan gelen Hz (+ opsiyonel binaural vuru) ile **tone** katmanı ekler.
  ///
  /// - [beatHz] null veya 0 → mono ton; > 0 → katman STEREO çalar (L/R farklı
  ///   perde, kulakta vuru). Vuru değeri motorda ızgaraya oturur.
  /// - Mix hazır değilse yalnızca state'e girer ([prepare] ilk çalışta yükler —
  ///   `addAsset`'in iki-hâl sözleşmesiyle aynı).
  /// - Mix hazırsa katman CANLI eklenir, çalıyorsa hemen başlar.
  /// - Tavan doluysa hiçbir şey eklenmez ve [AddToneOutcome.full] döner; UI
  ///   kullanıcıya söyler. Sessiz başarısızlık yasak (§0).
  Future<AddToneOutcome> addToneLayer(double frequencyHz, {double? beatHz}) async {
    final clamped = frequencyHz.clamp(toneMinHz, toneMaxHz);
    if (_state.layers.length + _state.assets.length >= maxTotalLayers) {
      return AddToneOutcome.full;
    }

    final id = _uniqueToneId();
    final layer = MixLayer(
      id: id,
      type: LayerSource.tone,
      gain: defaultToneGain,
      frequencyHz: clamped.toDouble(),
      beatHz: (beatHz != null && beatHz > 0) ? beatHz : null,
    );

    if (_player.voiceCount > 0) {
      await _player.addSynthLayer(layer, autoPlay: _state.isPlaying);
    }

    _emit(_state.copyWith(
      layers: <MixLayer>[..._state.layers, layer],
      gains: <String, double>{..._state.gains, layer.id: layer.gain},
      userAddedSynthIds: <String>[..._state.userAddedSynthIds, layer.id],
      clearError: true,
    ));
    return AddToneOutcome.added;
  }

  /// 'tone', 'tone-2', ... — çakışmayan ilk id. Tariften gelen bir katman da
  /// 'tone' adını taşıyabilir (sunucu id benzersizliğini kendi içinde garanti
  /// eder); o yüzden MEVCUT tüm katmanlara bakıyoruz.
  String _uniqueToneId() {
    if (!_state.gains.containsKey('tone')) return 'tone';
    var n = 2;
    while (_state.gains.containsKey('tone-$n')) {
      n++;
    }
    return 'tone-$n';
  }

  /// Herhangi bir SENTEZ katmanını çıkarır — tarifle gelenler DAHİL.
  ///
  /// **Tasarım değişikliği (kullanıcı isteği):** mikser serbest bir araçtır,
  /// tarif yalnızca BAŞLANGIÇ noktasıdır. Kullanıcı brown'u kaldırıp sonra
  /// geri ekleyebilmelidir. Kaldırılan katman `addSource` ile geri eklenir.
  ///
  /// Dosya katmanları için [removeAsset] ayrıdır (kaynağı dosyadır).
  Future<void> removeLayer(String id) async {
    final layer = _state.layers.where((l) => l.id == id).firstOrNull;
    if (layer == null) return;
    await _player.removeVoice(id);
    final gains = Map<String, double>.from(_state.gains)..remove(id);
    _emit(_state.copyWith(
      layers: <MixLayer>[
        for (final l in _state.layers)
          if (l.id != id) l,
      ],
      gains: gains,
      userAddedSynthIds: <String>[
        for (final s in _state.userAddedSynthIds)
          if (s != id) s,
      ],
    ));
  }

  /// Kaldırılan bir sentez kaynağını yeniden ekler.
  ///
  /// Aynı türden zaten varsa duplicate döner (iki brown katmanı anlamsızdır);
  /// tone hariç — farklı frekanslarda birden fazla tone geçerlidir.
  Future<AddSourceOutcome> addSource(LayerSource type) async {
    if (_state.layers.length + _state.assets.length >= maxTotalLayers) {
      return AddSourceOutcome.full;
    }
    // Tone birden fazla olabilir; diğerleri tekil.
    if (type != LayerSource.tone &&
        type != LayerSource.chords &&
        type != LayerSource.arpeggio &&
        _state.layers.any((l) => l.type == type)) {
      return AddSourceOutcome.duplicate;
    }

    final id = type == LayerSource.tone ? _uniqueToneId() : type.name;
    // Çakışma kontrolü (tone-2 vs tone-3 gibi id'ler için).
    if (_state.gains.containsKey(id)) return AddSourceOutcome.duplicate;

    final layer = MixLayer(
      id: id,
      type: type,
      gain: defaultSourceGain,
    );

    if (_player.voiceCount > 0) {
      await _player.addSynthLayer(layer, autoPlay: _state.isPlaying);
    }

    _emit(_state.copyWith(
      layers: <MixLayer>[..._state.layers, layer],
      gains: <String, double>{..._state.gains, layer.id: layer.gain},
      userAddedSynthIds: <String>[..._state.userAddedSynthIds, layer.id],
      clearError: true,
    ));
    return AddSourceOutcome.added;
  }

  /// Kullanıcı-parametreli akor/arpej katmanı ekler (melodi editöründen).
  Future<AddSourceOutcome> addMelodicLayer(MelodicPreset preset) async {
    if (_state.layers.length + _state.assets.length >= maxTotalLayers) {
      return AddSourceOutcome.full;
    }
    final type = preset.isChords ? LayerSource.chords : LayerSource.arpeggio;
    final id = '${type.name}-${DateTime.now().millisecondsSinceEpoch % 10000}';

    final layer = MixLayer(
      id: id,
      type: type,
      gain: defaultToneGain,
      rootSemi: preset.rootSemi,
      waveform: preset.waveform,
      tempoScale: preset.tempoScale,
      patternIdx: preset.patternIdx,
    );

    if (_player.voiceCount > 0) {
      await _player.addSynthLayer(layer, autoPlay: _state.isPlaying);
    }

    _emit(_state.copyWith(
      layers: <MixLayer>[..._state.layers, layer],
      gains: <String, double>{..._state.gains, layer.id: layer.gain},
      userAddedSynthIds: <String>[..._state.userAddedSynthIds, layer.id],
      clearError: true,
    ));
    return AddSourceOutcome.added;
  }

  /// Mikste OLMAYAN sentez kaynaklarını döndürür — kaynak seçicisi bunu listeler.
  List<LayerSource> missingSources() {
    const all = LayerSource.values;
    final present = _state.layers.map((l) => l.type).toSet();
    return [for (final t in all) if (!present.contains(t)) t];
  }

  /// Slider'ın çağırdığı yer. Render YOK — yalnızca ses seviyesi.
  Future<void> setGain(String id, double gain) async {
    final next = Map<String, double>.from(_state.gains)..[id] = gain;
    _emit(_state.copyWith(gains: next));
    await _player.setLayerGain(id, gain);
    // Her kazanç değişiminde KALICI kaydet: kullanıcı uygulama öldürse bile
    // son mix'i kaybolmaz.
    await _persistState();
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
            MixLayer(
              id: l.id,
              type: l.type,
              gain: _state.gains[l.id] ?? l.gain,
              // Frekans/vuru KAYBEDİLMEZ: tone katmanında null kalan frekans
              // export yolunda render assert'ini kırar; vuru kaybolursa kullanıcı
              // duyduğundan farklı bir mix paylaşmış olurdu.
              frequencyHz: l.frequencyHz,
              beatHz: l.beatHz,
            ),
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

  Future<void> dispose() {
    // Rampa hâlâ sürüyor olabilir; kapatılmış bir controller'a state basmasın.
    _player.onLimiterChanged = null;
    return _player.dispose();
  }
}
