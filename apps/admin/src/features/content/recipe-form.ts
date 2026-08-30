// apps/* birbirini import EDEMEZ (CLAUDE.md §2) → bu liste sunucudakinin zorunlu
// kopyasıdır. Kopyanın sessizce eskimesini `tooling/check-layer-source-drift.mjs`
// engeller: sıra dahil sunucu + mobil ile karşılaştırılır.
export const LAYER_SOURCES = [
  'white',
  'pink',
  'brown',
  'waves',
  'fire',
  'rain',
  'pad',
  'tone',
  'chords',
  'arpeggio',
  'ceramic',
  'chimes',
] as const;
export type LayerSource = (typeof LAYER_SOURCES)[number];
export const MAX_LAYERS = 8;

/**
 * `tone` katmanının frekans aralığı — sunucudaki TONE_MIN_HZ/TONE_MAX_HZ'nin
 * (mixer-state.ts) ve mobil tone.dart'ın kopyası. Üçü ayrışırsa tarif bir
 * tarafta kaydedilip diğerinde reddedilir.
 */
export const TONE_MIN_HZ = 20;
export const TONE_MAX_HZ = 2000;

/** Binaural vuru — sunucu mixer-state.ts (TONE_BEAT_MIN/MAX) ile aynı kurallar. */
export const TONE_BEAT_MIN_HZ = 0.5;
export const TONE_BEAT_MAX_HZ = 20;

export interface RecipeLayer {
  id: string;
  type: LayerSource;
  gain: number;
  /**
   * YALNIZCA `type === 'tone'`: temel frekans. Form, sunucu kapısına giden
   * JSON'un GEÇERLİ olmasını sağlamak zorunda (kayıt reddedilirse editörün
   * emeği çöpe gider) — o yüzden bu alan formda koşullu görünür ve
   * normalizeLayers yazma yolunda ton dışı katmanlardan alanı SİLER.
   */
  frequencyHz?: number;
  /**
   * Binaural vuru — SÖZLEŞME ÜYESİ: yalnızca tone'da, (0.5, 20] Hz, yokluk =
   * mono. Formda koşullu görünür; düşürülseydi kaydedilen binaural tarif
   * sessizce mono'ya indirgenirdi (parse edilmiş tarif yazılır!).
   */
  beatHz?: number;
}

export interface Recipe {
  schemaVersion: number;
  layers: RecipeLayer[];
}

/** [frequencyHz]'i sözleşme kurallarına göre temizler: ton dışında yok, tonda aralık içinde. */
function sanitizeFrequency(type: LayerSource, raw: unknown): number | undefined {
  if (type !== 'tone') return undefined;
  if (typeof raw !== 'number' || !Number.isFinite(raw)) return undefined;
  return Math.min(TONE_MAX_HZ, Math.max(TONE_MIN_HZ, Math.round(raw)));
}

/**
 * [beatHz]'i temizler: ton dışında YOK, tonda (0, TONE_BEAT_MAX] aralığı.
 * Farklıdır frequencyHz'den: 0 "kapalı" demektir ve alan tamamen SİLİNİR
 * (0 göndermek yerine alanın yokluğu mono'nun tek tel ifadesidir).
 */
function sanitizeBeat(type: LayerSource, raw: unknown): number | undefined {
  if (type !== 'tone') return undefined;
  if (typeof raw !== 'number' || !Number.isFinite(raw)) return undefined;
  if (raw <= 0) return undefined;
  return Math.min(TONE_BEAT_MAX_HZ, raw);
}

/**
 * Ham `engine_params`'ı forma yüklenebilir hâle getirir.
 *
 * DOĞRULAMAZ, KURTARIR: DB'de eski veya elle girilmiş bozuk bir tarif olabilir ve
 * editörün onu düzeltebilmesi için **elinden geldiğince** göstermek gerekir. Sıkı
 * kapı YAZMA yolunda (API `parseEngineParams`, #123) — burada sıkı olmak, bozuk
 * kaydı düzenlenemez kılardı. Tanınmayan katman atılır; hepsi bozuksa boş liste.
 *
 * Frekans KURTARILIR ama garanti EDİLMEZ: aralık dışı değer korunursa editör onu
 * görüp düzeltebilir; normalizeLayers yine de yazma yolunda sıkılaştırır.
 */
export function toFormLayers(raw: unknown): RecipeLayer[] {
  if (typeof raw !== 'object' || raw === null) return [];
  const layers = (raw as { layers?: unknown }).layers;
  if (!Array.isArray(layers)) return [];

  const out: RecipeLayer[] = [];
  for (const l of layers.slice(0, MAX_LAYERS)) {
    if (typeof l !== 'object' || l === null) continue;
    const { id, type, gain, frequencyHz, beatHz } = l as Record<string, unknown>;
    if (typeof id !== 'string' || id.length === 0) continue;
    const resolvedType: LayerSource = isLayerSource(type) ? type : 'pink';
    const base: RecipeLayer = {
      id,
      type: resolvedType,
      gain: typeof gain === 'number' && Number.isFinite(gain) ? clamp01(gain) : 0.5,
    };
    const freq = sanitizeFrequency(resolvedType, frequencyHz);
    const beat = sanitizeBeat(resolvedType, beatHz);
    out.push({
      ...base,
      ...(freq !== undefined ? { frequencyHz: freq } : {}),
      ...(beat !== undefined ? { beatHz: beat } : {}),
    });
  }
  return out;
}

/**
 * Form state'ini YAZMA yoluna uygun hâle getirir:
 * - ton DIŞI katmandan `frequencyHz`/`beatHz` silinir (sunucu kapısı bunları reddeder),
 * - ton frekansı aralığa oturtulur ve tam sayıya yuvarlanır,
 * - beat ≤ 0 ya da bozuksa alan SİLİNİR (0 yerine yokluk = mono).
 *
 * **Neden var:** kullanıcı önce "tone" seçip frekans girer, sonra tipi "pink"
 * yapar — artık geçersiz olan alan satırda KALMIŞ olurdu. Temizliği çağıranın
 * hatırlamasına güvenmek, bir gün unutulacak bir sıra demektir.
 */
export function normalizeLayers(layers: RecipeLayer[]): RecipeLayer[] {
  return layers.map((l) => {
    const base: RecipeLayer = { id: l.id, type: l.type, gain: clamp01(l.gain) };
    const freq = sanitizeFrequency(l.type, l.frequencyHz);
    const beat = sanitizeBeat(l.type, l.beatHz);
    return {
      ...base,
      ...(freq !== undefined ? { frequencyHz: freq } : {}),
      ...(beat !== undefined ? { beatHz: beat } : {}),
    };
  });
}

function isLayerSource(v: unknown): v is LayerSource {
  return typeof v === 'string' && (LAYER_SOURCES as readonly string[]).includes(v);
}

function clamp01(n: number): number {
  return Math.min(1, Math.max(0, n));
}
