import '../../core/audio_engine/engine_params.dart';
import '../../core/audio_engine/dsp/mix_render.dart';

// İçerik modelleri (docs/04). Kimlik doğrulamalı /v1/content uçları.
// Üretilen Dart client (B-3) gelince değişir.

class Soundscape {
  const Soundscape({
    required this.id,
    required this.slug,
    required this.titleI18n,
    required this.archetypeAffinity,
    required this.version,
    this.mixSpec,
  });

  final String id;
  final String slug;
  final Map<String, String> titleI18n;
  final List<String> archetypeAffinity;
  final int version;

  /// Ses tarifi (`engine_params` → [MixSpec]). **null olabilir:** tarif boş
  /// (taslak), bozuk, ya da BU UYGULAMANIN TANIMADIĞI bir şema sürümünde olabilir
  /// (docs/04 §79). null = "bu ses bu sürümde çalınamaz" — çökme değil.
  final MixSpec? mixSpec;

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
        // Tarif AYRIŞTIRILAMAZSA kayıt yine de listelenir (başlık/affinity geçerli);
        // yalnızca çalınamaz. Tüm kaydı düşürmek, kütüphaneyi sessizce boşaltırdı.
        mixSpec: parseEngineParams(json['engineParams']),
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
  final LayerSource type;
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

  /// Tel dizgisi → enum. `LayerSource.values`'tan türetilir; elle yazılmış liste
  /// enum'a kaynak eklenince sessizce eksik kalırdı (preset "geçersiz" sayılırdı).
  static final Map<String, LayerSource> _types = {
    for (final s in LayerSource.values) s.name: s,
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

/// Sunucudaki ses DOSYASI kaydı (`/v1/content/audio-assets`).
///
/// Depolama anahtarı (`key`) BİLEREK yok: sunucu onu tele koymuyor. İstemci
/// dosyaya yalnızca tekil uçtan aldığı kısa ömürlü presigned URL ile erişir.
class AudioAsset {
  const AudioAsset({
    required this.id,
    required this.title,
    required this.genre,
    required this.mood,
    required this.durationSeconds,
    required this.license,
    required this.source,
  });

  final String id;
  final String title;
  final String genre;
  final List<String> mood;
  final int durationSeconds;

  /// Lisans ve kaynak İSTEMCİDE DE taşınır — gösterilmek zorunda olduğumuz
  /// atıflar (CC-BY gibi) için. Sunucuda zorunlu, burada opsiyonel olsaydı
  /// atıf gösteremeden çalan bir dosyamız olurdu.
  final String license;
  final String source;

  factory AudioAsset.fromJson(Map<String, dynamic> json) => AudioAsset(
        id: json['id'] as String,
        title: json['title'] as String,
        genre: json['genre'] as String,
        mood: (json['mood'] as List<dynamic>? ?? const <dynamic>[])
            .map((e) => e as String)
            .toList(),
        durationSeconds: (json['durationSeconds'] as num?)?.toInt() ?? 0,
        license: json['license'] as String? ?? '',
        source: json['source'] as String? ?? '',
      );
}

/// Tekil uç yanıtı: meta + kısa ömürlü URL.
class AudioAssetDetail {
  const AudioAssetDetail({
    required this.asset,
    required this.url,
    required this.expiresInSeconds,
  });

  final AudioAsset asset;
  final String url;
  final int expiresInSeconds;

  factory AudioAssetDetail.fromJson(Map<String, dynamic> json) => AudioAssetDetail(
        asset: AudioAsset.fromJson(json['asset'] as Map<String, dynamic>),
        url: json['url'] as String,
        expiresInSeconds: (json['expiresInSeconds'] as num?)?.toInt() ?? 0,
      );

  /// Mikserin çalabileceği katmana çevirir.
  ///
  /// [gain] varsayılanı düşük (0.3): kullanıcının eklediği dosya, hâlihazırda
  /// çalan mix'in üstüne BİRDEN bindirilmemeli — gece yarısı ani seviye artışı
  /// uyandırır. Kullanıcı sürgüyle yükseltir.
  AssetLayer toLayer({double gain = 0.3}) => AssetLayer(
        id: asset.id,
        title: asset.title,
        url: url,
        gain: gain,
      );
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
