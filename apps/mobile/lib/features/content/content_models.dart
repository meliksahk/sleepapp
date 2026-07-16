import '../../core/audio_engine/dsp/mix_render.dart';

// İçerik modelleri (docs/04). Kimlik doğrulamalı /v1/content uçları.
// engineParams/layerDefs (ses motoru) on-device motor gelince eklenecek; şimdilik
// liste/kütüphane için gereken alanlar. Üretilen Dart client (B-3) gelince değişir.

class Soundscape {
  const Soundscape({
    required this.id,
    required this.slug,
    required this.titleI18n,
    required this.archetypeAffinity,
    required this.version,
  });

  final String id;
  final String slug;
  final Map<String, String> titleI18n;
  final List<String> archetypeAffinity;
  final int version;

  /// Verilen dile göre başlık; yoksa 'en', o da yoksa slug.
  String title(String locale) => titleI18n[locale] ?? titleI18n['en'] ?? slug;

  /// archetypeAffinity slug'larını okunur etikete çevirir (ilk [max] tanesi):
  /// ['deep-ocean','delta-drifter'] → 'Deep Ocean · Delta Drifter'. Boşsa ''.
  String affinityLabel({int max = 2}) {
    if (archetypeAffinity.isEmpty) return '';
    return archetypeAffinity.take(max).map(_humanizeSlug).join(' · ');
  }

  factory Soundscape.fromJson(Map<String, dynamic> json) => Soundscape(
        id: json['id'] as String,
        slug: json['slug'] as String,
        titleI18n: (json['titleI18n'] as Map<String, dynamic>).map(
          (k, v) => MapEntry(k, v as String),
        ),
        archetypeAffinity:
            (json['archetypeAffinity'] as List<dynamic>).map((e) => e as String).toList(),
        version: json['version'] as int,
      );
}

/// 'delta-drifter' → 'Delta Drifter' (slug → başlık biçimi).
String _humanizeSlug(String slug) => slug
    .split('-')
    .where((w) => w.isNotEmpty)
    .map((w) => '${w[0].toUpperCase()}${w.substring(1)}')
    .join(' ');

/// Preset'in tek katmanı — sunucu sözleşmesiyle birebir (docs/02 mixer_state).
class MixerLayerState {
  const MixerLayerState({required this.id, required this.type, required this.gain});

  final String id;
  final NoiseType type;
  final double gain;
}

/// Preset mixer durumu → ses motorunun [MixSpec]'ine çevrilebilir.
///
/// Sunucu #99'dan beri şemayı doğruluyor; yine de [tryParse] **savunmacıdır**:
/// istemci sunucudan eski/yeni olabilir ve bozuk JSON'la çökmek yerine preset'i
/// yok saymak doğrusudur. Kural sunucuyla aynı: geçersizse **kısmi değil, null**.
class MixerState {
  const MixerState(this.layers);

  final List<MixerLayerState> layers;

  static const _types = <String, NoiseType>{
    'white': NoiseType.white,
    'pink': NoiseType.pink,
    'brown': NoiseType.brown,
  };

  /// Geçersiz/tanınmayan yapı → null (çağıran preset'i yok sayar).
  static MixerState? tryParse(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final rawLayers = json['layers'];
    if (rawLayers is! List<dynamic> || rawLayers.isEmpty) return null;

    final layers = <MixerLayerState>[];
    final seen = <String>{};
    for (final raw in rawLayers) {
      if (raw is! Map<String, dynamic>) return null;
      final id = raw['id'];
      final type = _types[raw['type']];
      final gain = raw['gain'];
      if (id is! String || id.isEmpty || type == null) return null;
      if (gain is! num || !gain.isFinite || gain < 0 || gain > 1) return null;
      if (!seen.add(id)) return null; // tekrar eden id → belirsiz mix
      layers.add(MixerLayerState(id: id, type: type, gain: gain.toDouble()));
    }
    return MixerState(layers);
  }

  /// Motorun render girdisi.
  MixSpec toMixSpec() => MixSpec([
    for (final l in layers) MixLayer(id: l.id, type: l.type, gain: l.gain),
  ]);
}

class Preset {
  const Preset({required this.archetypeSlug, required this.mixerState});

  final String archetypeSlug;

  /// Sunucu sözleşmesi tanınmazsa null (CLAUDE.md §4: `dynamic` yasak).
  final MixerState? mixerState;

  factory Preset.fromJson(Map<String, dynamic> json) => Preset(
    archetypeSlug: json['archetypeSlug'] as String,
    mixerState: MixerState.tryParse(json['mixerState']),
  );
}

class SoundscapeDetail {
  const SoundscapeDetail({
    required this.soundscape,
    required this.presets,
    required this.previewUrl,
  });

  final Soundscape soundscape;
  final List<Preset> presets;
  final String? previewUrl;

  factory SoundscapeDetail.fromJson(Map<String, dynamic> json) => SoundscapeDetail(
        soundscape: Soundscape.fromJson(json['soundscape'] as Map<String, dynamic>),
        presets: (json['presets'] as List<dynamic>)
            .map((e) => Preset.fromJson(e as Map<String, dynamic>))
            .toList(),
        previewUrl: json['previewUrl'] as String?,
      );
}

class WeeklyRelease {
  const WeeklyRelease({
    required this.weekStart,
    required this.notes,
    required this.soundscapes,
  });

  final String weekStart;
  final String? notes;
  final List<Soundscape> soundscapes;

  factory WeeklyRelease.fromJson(Map<String, dynamic> json) => WeeklyRelease(
        weekStart: json['weekStart'] as String,
        notes: json['notes'] as String?,
        soundscapes: (json['soundscapes'] as List<dynamic>)
            .map((e) => Soundscape.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
