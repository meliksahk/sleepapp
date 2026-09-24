import 'dart:convert';

import '../../../core/storage/key_value_store.dart';

/// Kullanıcının kaydettiği melodik preset.
class MelodicPreset {
  const MelodicPreset({
    required this.name,
    required this.rootSemi,
    required this.patternIdx,
    required this.waveform,
    required this.tempoScale,
    this.isChords = false,
  });

  final String name;
  final int rootSemi;
  final int patternIdx;
  final String waveform;
  final double tempoScale;
  final bool isChords;

  Map<String, Object?> toJson() => {
        'name': name,
        'rootSemi': rootSemi,
        'patternIdx': patternIdx,
        'waveform': waveform,
        'tempoScale': tempoScale,
        'isChords': isChords,
      };

  factory MelodicPreset.fromJson(Map<String, dynamic> json) => MelodicPreset(
        name: json['name'] as String? ?? '',
        rootSemi: json['rootSemi'] as int? ?? 0,
        patternIdx: json['patternIdx'] as int? ?? 0,
        waveform: json['waveform'] as String? ?? 'sine',
        tempoScale: (json['tempoScale'] as num?)?.toDouble() ?? 1.0,
        isChords: json['isChords'] as bool? ?? false,
      );
}

/// Kullanıcı preset'lerinin kalıcı saklanması — KeyValueStore üzerinde JSON liste.
class MelodicPresetStore {
  MelodicPresetStore(this._store);

  static const String _key = 'melodic_presets';
  final KeyValueStore _store;

  Future<List<MelodicPreset>> list() async {
    final raw = await _store.read(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) => MelodicPreset.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> save(MelodicPreset preset) async {
    final presets = await list();
    presets.removeWhere((p) => p.name == preset.name);
    presets.add(preset);
    await _store.write(_key, jsonEncode(presets.map((p) => p.toJson()).toList()));
  }

  Future<void> delete(String name) async {
    final presets = await list();
    presets.removeWhere((p) => p.name == name);
    await _store.write(_key, jsonEncode(presets.map((p) => p.toJson()).toList()));
  }
}
