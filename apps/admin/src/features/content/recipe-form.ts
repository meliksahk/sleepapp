export const NOISE_TYPES = ['white', 'pink', 'brown'] as const;
export type NoiseType = (typeof NOISE_TYPES)[number];
export const MAX_LAYERS = 8;

export interface RecipeLayer {
  id: string;
  type: NoiseType;
  gain: number;
}

export interface Recipe {
  schemaVersion: number;
  layers: RecipeLayer[];
}

/**
 * Ham `engine_params`'ı forma yüklenebilir hâle getirir.
 *
 * DOĞRULAMAZ, KURTARIR: DB'de eski veya elle girilmiş bozuk bir tarif olabilir ve
 * editörün onu düzeltebilmesi için **elinden geldiğince** göstermek gerekir. Sıkı
 * kapı YAZMA yolunda (API `parseEngineParams`, #123) — burada sıkı olmak, bozuk
 * kaydı düzenlenemez kılardı. Tanınmayan katman atılır; hepsi bozuksa boş liste.
 */
export function toFormLayers(raw: unknown): RecipeLayer[] {
  if (typeof raw !== 'object' || raw === null) return [];
  const layers = (raw as { layers?: unknown }).layers;
  if (!Array.isArray(layers)) return [];

  const out: RecipeLayer[] = [];
  for (const l of layers.slice(0, MAX_LAYERS)) {
    if (typeof l !== 'object' || l === null) continue;
    const { id, type, gain } = l as Record<string, unknown>;
    if (typeof id !== 'string' || id.length === 0) continue;
    out.push({
      id,
      type: isNoiseType(type) ? type : 'pink',
      gain: typeof gain === 'number' && Number.isFinite(gain) ? clamp01(gain) : 0.5,
    });
  }
  return out;
}

function isNoiseType(v: unknown): v is NoiseType {
  return typeof v === 'string' && (NOISE_TYPES as readonly string[]).includes(v);
}

function clamp01(n: number): number {
  return Math.min(1, Math.max(0, n));
}
