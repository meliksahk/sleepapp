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

class Preset {
  const Preset({required this.archetypeSlug, required this.mixerState});

  final String archetypeSlug;
  final dynamic mixerState;

  factory Preset.fromJson(Map<String, dynamic> json) =>
      Preset(archetypeSlug: json['archetypeSlug'] as String, mixerState: json['mixerState']);
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
