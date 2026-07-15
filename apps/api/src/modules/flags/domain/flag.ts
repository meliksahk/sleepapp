/**
 * Feature flag domain (docs/02 §3, docs/03 A4). Değerlendirme SAF: rollout kovası
 * (0-99) dışarıda hesaplanır (BucketHasher), böylece domain IO'dan bağımsız kalır.
 * Tam kural motoru (platform/sürüm/archetype segmenti) A4'te genişler.
 */
export interface FlagRules {
  readonly enabled: boolean;
  /** 0-100; tanımlıysa userId+key kovası < yüzde → açık. */
  readonly rolloutPercentage?: number;
}

export interface Flag {
  readonly key: string;
  readonly rules: FlagRules;
}

/** Deterministik userId+key kovasını (0-99) üretir. */
export interface BucketHasher {
  bucket(userId: string, key: string): number;
}

/** Kovayı (0-99) verilen kurala göre değerlendirir. */
export function evaluateFlag(rules: FlagRules, bucket: number): boolean {
  if (!rules.enabled) return false;
  if (rules.rolloutPercentage === undefined) return true;
  const pct = Math.max(0, Math.min(100, rules.rolloutPercentage));
  return bucket < pct;
}

/** Bilinmeyen jsonb'yi güvenli FlagRules'a indirger. */
export function parseRules(raw: unknown): FlagRules {
  if (typeof raw !== 'object' || raw === null) return { enabled: false };
  const obj = raw as Record<string, unknown>;
  const enabled = obj.enabled === true;
  const pct = typeof obj.rolloutPercentage === 'number' ? obj.rolloutPercentage : undefined;
  return pct === undefined ? { enabled } : { enabled, rolloutPercentage: pct };
}

export interface FlagRepository {
  findAll(): Promise<Flag[]>;
}

export const FLAG_REPOSITORY = Symbol('FlagRepository');
export const BUCKET_HASHER = Symbol('BucketHasher');
