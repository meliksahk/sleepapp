import 'dsp/mix_render.dart';

/// `soundscapes.engine_params` → [MixSpec] ayrıştırıcısı.
///
/// **Sözleşme sunucuyla AYNIDIR** (apps/api content/domain/engine-params.ts):
/// `{ schemaVersion: 1, layers: [{id, type: white|pink|brown, gain: 0..1}] }`.
/// İki taraf ayrı dilde olduğu için sözleşme iki yerde yazılı; **değişirse İKİSİ
/// birlikte değişmelidir** (mixer-state.ts'teki aynı not).
///
/// **ÇÖKME YOK — zarifçe null (docs/04 §79):** "engine_params şeması versiyonludur;
/// eski uygulama yeni şemayı görürse zarifçe eski preset'e düşer (crash değil)."
/// Sunucu bu sürümü yazarken doğrular; ama uygulama mağazada YILLARCA yaşar ve
/// bir gün v2 görebilir. O an atmak = kullanıcının kütüphanesinin çökmesi.
/// Çağıran null'ı "bu ses bu sürümde çalınamaz" diye ele alır.
///
/// **TOLERANS YOK:** kısmen geçerli bir tarif sessizce yanlış ses üretir —
/// duyulmayan bir hata, duyulan bir hatadan beterdir. Ya tamamı geçerli ya null.
const int engineParamsSchemaVersion = 1;

/// Tek tarifte izin verilen azami katman (sunucudaki MAX_MIXER_LAYERS ile aynı).
const int maxMixLayers = 8;

MixSpec? parseEngineParams(Object? input) {
  if (input is! Map) return null;

  // Sürüm ZORUNLU ve tanıdığımız sürüm olmalı. Eksikse de reddedilir: sürümsüz bir
  // tarif, hangi kurallara göre okunacağı belirsiz bir tariftir.
  if (input['schemaVersion'] != engineParamsSchemaVersion) return null;

  final layersRaw = input['layers'];
  if (layersRaw is! List) return null;
  if (layersRaw.isEmpty || layersRaw.length > maxMixLayers) return null;

  final layers = <MixLayer>[];
  final seen = <String>{};
  for (final raw in layersRaw) {
    final layer = _parseLayer(raw);
    if (layer == null) return null;
    if (!seen.add(layer.id)) return null; // aynı id iki kez → belirsiz mix
    layers.add(layer);
  }
  return MixSpec(layers);
}

MixLayer? _parseLayer(Object? input) {
  if (input is! Map) return null;

  final id = input['id'];
  if (id is! String || id.isEmpty) return null;

  final type = _parseNoiseType(input['type']);
  if (type == null) return null;

  // `num` kabul edilir: JSON'da 1 (int) ile 1.0 (double) aynı şeydir ve sunucu
  // hangisini yollayacağını garanti etmez. NaN/Infinity elenir.
  final gain = input['gain'];
  if (gain is! num || !gain.isFinite || gain < 0 || gain > 1) return null;

  return MixLayer(id: id, type: type, gain: gain.toDouble());
}

NoiseType? _parseNoiseType(Object? value) {
  switch (value) {
    case 'white':
      return NoiseType.white;
    case 'pink':
      return NoiseType.pink;
    case 'brown':
      return NoiseType.brown;
    default:
      // Sunucu yeni bir kaynak ekleyip bu uygulamayı güncellemeyen kullanıcıya
      // yollarsa: bilmediğimiz kaynağı "yaklaşık" bir şeyle değiştirmek YANLIŞ
      // ses çalmak olurdu. Tarif komple reddedilir.
      return null;
  }
}
