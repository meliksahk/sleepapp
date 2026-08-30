import 'dart:convert';

import '../../../core/audio_engine/dsp/mix_render.dart';
import '../../../core/storage/key_value_store.dart';

/// Mikser durumunun KALICI saklanması — kullanıcı uygulama kapatıp açtığında
/// son mix'i aynen görmeli (kullanıcı isteği).
///
/// Saklanan JSON: `{"layers":[{id,type,gain,frequencyHz?,beatHz?}]}`
/// Dosya katmanları saklanMAZ (URL'ler süresiz değildir); yalnızca sentez.
class MixStateStore {
  MixStateStore(this._store);

  final KeyValueStore _store;
  static const String _key = 'mixer_last_state';

  Future<void> save(MixSpec spec) async {
    final layers = [
      for (final l in spec.layers)
        <String, Object?>{
          'id': l.id,
          'type': l.type.name,
          'gain': l.gain,
          if (l.frequencyHz != null) 'frequencyHz': l.frequencyHz,
          if (l.beatHz != null) 'beatHz': l.beatHz,
        },
    ];
    await _store.write(_key, jsonEncode({'layers': layers}));
  }

  /// Kayıtlı durumu okur; yoksa veya bozuksa null.
  ///
  /// Tolerans YOK (engine_params ile aynı felsefe): kısmen geçerli bir kayıt,
  /// sessizce yanlış ses üretir. Ya tamamı geçerli ya null.
  Future<MixSpec?> load() async {
    final raw = await _store.read(_key);
    if (raw == null || raw.isEmpty) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final layersRaw = json['layers'] as List<dynamic>? ?? [];
      if (layersRaw.isEmpty) return null;

      final layers = <MixLayer>[];
      for (final raw in layersRaw) {
        final map = raw as Map<String, dynamic>;
        final typeName = map['type'] as String?;
        final type = LayerSource.values.where((t) => t.name == typeName).firstOrNull;
        if (type == null) return null;
        final gain = (map['gain'] as num?)?.toDouble();
        if (gain == null || gain < 0 || gain > 1) return null;
        double? frequencyHz;
        if (type == LayerSource.tone) {
          frequencyHz = (map['frequencyHz'] as num?)?.toDouble();
          if (frequencyHz == null) return null; // tone için zorunlu
        }
        double? beatHz;
        final rawBeat = map['beatHz'];
        if (rawBeat != null) {
          beatHz = (rawBeat as num).toDouble();
          if (type != LayerSource.tone || beatHz <= 0) return null;
        }
        layers.add(MixLayer(
          id: map['id'] as String? ?? type.name,
          type: type,
          gain: gain,
          frequencyHz: frequencyHz,
          beatHz: beatHz,
        ));
      }
      return MixSpec(layers);
    } catch (_) {
      return null; // bozuk JSON → sessizce varsayılana düş
    }
  }
}
