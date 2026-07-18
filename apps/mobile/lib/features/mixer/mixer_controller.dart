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
enum MixerErrorKind { sound, export }

/// Mikser durumu — UI'ın gördüğü tek şey.
class MixerState {
  const MixerState({
    required this.layers,
    required this.gains,
    this.isPlaying = false,
    this.isPreparing = false,
    this.exportProgress,
    this.error,
    this.errorKind,
  });

  final List<MixLayer> layers;

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
      gains: {for (final l in _spec.layers) l.id: l.gain},
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
  Future<void> prepare() async {
    _emit(_state.copyWith(isPreparing: true, clearError: true));
    try {
      await _player.load(_spec);
      _emit(_state.copyWith(isPreparing: false));
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
  MixSpec currentSpec() => MixSpec([
        for (final l in _state.layers)
          MixLayer(id: l.id, type: l.type, gain: _state.gains[l.id] ?? l.gain),
      ]);

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
