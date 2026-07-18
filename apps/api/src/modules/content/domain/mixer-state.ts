/**
 * Preset mixer_state **sözleşmesi** — saf domain.
 *
 * Neden var: `presets.mixer_state` şimdiye dek serbest `jsonb` idi (tip: `unknown`).
 * Editör oraya herhangi bir JSON koyabilirdi ve hata ancak **kullanıcının
 * telefonunda, çalma anında** ortaya çıkardı. Şema burada tanımlanır ve okuma
 * yolunda doğrulanır → bozuk içerik istemciye HİÇ ulaşmaz.
 *
 * Şekil, mobil ses motorunun `MixSpec`'iyle birebir hizalıdır (apps/mobile
 * core/audio_engine/dsp/mix_render.dart): katman = {id, type, gain}.
 * İkisi ayrı repo katmanında olduğu için sözleşme burada + docs'ta yazılıdır;
 * değişirse İKİSİ birlikte değişmelidir.
 */

/**
 * Motorun desteklediği jeneratif kaynaklar (mobil `LayerSource` enum'u ile AYNI).
 *
 * `white|pink|brown` düz gürültü; `waves|fire|rain` gürültü yatağı üstüne zarf ve
 * transient kuran meditatif dokular; `pad` tonal (içinde gürültü yok). Hepsi
 * on-device SENTEZDİR — sunucu ses dosyası tutmaz, yalnızca tarifi doğrular.
 *
 * ⚠️ **SIRA ÖNEMLİ:** `tooling/check-layer-source-drift.mjs` bu listeyi mobil
 * enum'la ve admin panelinin kopyasıyla SIRA DAHİL karşılaştırır. Yeni kaynak
 * eklerken üçü birden güncellenmeli, yoksa CI kırmızıya döner. Kapının varlık
 * sebebi: liste ayrışırsa editör panelde geçerli görünen bir tarif kaydeder,
 * hata ancak KULLANICININ TELEFONUNDA çalma anında ortaya çıkar.
 */
export const LAYER_SOURCES = ['white', 'pink', 'brown', 'waves', 'fire', 'rain', 'pad'] as const;
export type LayerSource = (typeof LAYER_SOURCES)[number];

export interface MixerLayer {
  readonly id: string;
  readonly type: LayerSource;
  /** [0,1] — mikser kazancı. */
  readonly gain: number;
}

export interface MixerState {
  readonly layers: readonly MixerLayer[];
}

/** Tek preset'te izin verilen azami katman (CPU + headroom sınırı). */
export const MAX_MIXER_LAYERS = 8;

const MAX_LAYER_ID_LENGTH = 40;

function isLayerSource(v: unknown): v is LayerSource {
  return typeof v === 'string' && (LAYER_SOURCES as readonly string[]).includes(v);
}

export function parseLayer(input: unknown): MixerLayer | null {
  if (typeof input !== 'object' || input === null) return null;
  const { id, type, gain } = input as Record<string, unknown>;

  if (typeof id !== 'string' || id.length === 0 || id.length > MAX_LAYER_ID_LENGTH) return null;
  if (!isLayerSource(type)) return null;
  // NaN/Infinity da elenmeli: Number.isFinite hem tipi hem geçerliliği kontrol eder.
  if (typeof gain !== 'number' || !Number.isFinite(gain) || gain < 0 || gain > 1) return null;

  return { id, type, gain };
}

/**
 * Serbest JSON'u doğrulanmış [MixerState]'e çevirir; geçersizse **null**.
 * Kural: en az 1, en fazla [MAX_MIXER_LAYERS] katman; katman id'leri benzersiz.
 * Tolerans YOK — bozuk preset sessizce "kısmen" yüklenmemeli.
 */
export function parseMixerState(input: unknown): MixerState | null {
  if (typeof input !== 'object' || input === null) return null;
  const { layers } = input as Record<string, unknown>;
  const parsed = parseLayers(layers);
  return parsed === null ? null : { layers: parsed };
}

/**
 * Katman listesini doğrular. `parseMixerState` ve `parseEngineParams` ortak kullanır —
 * kural iki yerde yaşasaydı biri sessizce eskirdi (ör. MAX değişimi tek yerde kalırdı).
 */
export function parseLayers(input: unknown): MixerLayer[] | null {
  if (!Array.isArray(input)) return null;
  if (input.length === 0 || input.length > MAX_MIXER_LAYERS) return null;

  const parsed: MixerLayer[] = [];
  const seen = new Set<string>();
  for (const raw of input) {
    const layer = parseLayer(raw);
    if (!layer) return null;
    if (seen.has(layer.id)) return null; // aynı id iki kez → belirsiz mix
    seen.add(layer.id);
    parsed.push(layer);
  }
  return parsed;
}
