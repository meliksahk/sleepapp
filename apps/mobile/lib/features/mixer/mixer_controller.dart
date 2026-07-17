import '../../core/audio_engine/dsp/mix_render.dart';
import '../../core/audio_engine/mix_player.dart';

/// Mikser durumu — UI'ın gördüğü tek şey.
class MixerState {
  const MixerState({
    required this.layers,
    required this.gains,
    this.isPlaying = false,
    this.isPreparing = false,
    this.error,
  });

  final List<MixLayer> layers;

  /// katman id → kazanç [0,1]. Spec'ten AYRI tutulur: slider her oynadığında yeni
  /// bir MixSpec üretmek, render'ı da tetiklemek anlamına gelirdi.
  final Map<String, double> gains;

  final bool isPlaying;
  final bool isPreparing;
  final String? error;

  MixerState copyWith({
    List<MixLayer>? layers,
    Map<String, double>? gains,
    bool? isPlaying,
    bool? isPreparing,
    String? error,
    bool clearError = false,
  }) {
    return MixerState(
      layers: layers ?? this.layers,
      gains: gains ?? this.gains,
      isPlaying: isPlaying ?? this.isPlaying,
      isPreparing: isPreparing ?? this.isPreparing,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Varsayılan mix — uygulama ilk açıldığında duyulan şey.
///
/// Kazançlar toplamı 1'in altında tutuldu: katmanlar işletim sistemi mikserinde
/// toplandığı için (referans kompresör devrede değil, bkz. [MixPlayer]) yüksek
/// kazançlar OS seviyesinde kırpardı.
MixSpec defaultMixSpec() => const MixSpec([
      MixLayer(id: 'brown', type: NoiseType.brown, gain: 0.45),
      MixLayer(id: 'pink', type: NoiseType.pink, gain: 0.30),
      MixLayer(id: 'white', type: NoiseType.white, gain: 0.10),
    ]);

/// Mikser ekranının denetleyicisi (docs/04 M2).
///
/// **Render PAHALI** (katman başına 30 sn @48kHz) ve yalnızca [prepare]'de bir kez
/// yapılır; slider `setLayerGain`'e gider → yeniden render YOK, ses kesilmez.
class MixerController {
  MixerController({MixPlayer? player, MixSpec? spec})
      : _player = player ?? MixPlayer(),
        _spec = spec ?? defaultMixSpec() {
    _state = MixerState(
      layers: _spec.layers,
      gains: {for (final l in _spec.layers) l.id: l.gain},
    );
  }

  final MixPlayer _player;
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
      _emit(_state.copyWith(isPreparing: false, error: e.toString()));
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

  Future<void> dispose() => _player.dispose();
}
