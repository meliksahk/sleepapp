/**
 * Feature flag domain (docs/02 §3, docs/03 A4). Değerlendirme SAF: rollout kovası
 * (0-99) dışarıda hesaplanır (BucketHasher), böylece domain IO'dan bağımsız kalır.
 * Segment hedefleme: platform allowlist + asgari uygulama sürümü (istemci context'i).
 */
export interface FlagRules {
  readonly enabled: boolean;
  /** 0-100; tanımlıysa userId+key kovası < yüzde → açık. */
  readonly rolloutPercentage?: number;
  /** Tanımlıysa yalnızca bu platformlar (ör. ['ios','android']) alır. */
  readonly platforms?: readonly string[];
  /** Tanımlıysa istemci sürümü >= bu olmalı (ör. '1.4.0'). */
  readonly minAppVersion?: string;
}

/** Değerlendirme bağlamı — istemciden gelir (platform/sürüm). */
export interface EvalContext {
  readonly platform?: string;
  readonly appVersion?: string;
}

export interface Flag {
  readonly key: string;
  readonly rules: FlagRules;
}

/** Deterministik userId+key kovasını (0-99) üretir. */
export interface BucketHasher {
  bucket(userId: string, key: string): number;
}

/** Semver benzeri karşılaştırma: a<b →-1, a==b →0, a>b →1. Eksik/geçersiz parça=0. */
export function compareVersions(a: string, b: string): number {
  const pa = a.split('.').map((x) => Number.parseInt(x, 10) || 0);
  const pb = b.split('.').map((x) => Number.parseInt(x, 10) || 0);
  const len = Math.max(pa.length, pb.length);
  for (let i = 0; i < len; i++) {
    const diff = (pa[i] ?? 0) - (pb[i] ?? 0);
    if (diff !== 0) return diff < 0 ? -1 : 1;
  }
  return 0;
}

/**
 * Kovayı + context'i kurala göre değerlendirir. Segment kapıları FAIL-CLOSED:
 * kural platform/sürüm istiyor ama context yoksa flag KAPALI (güvenli varsayılan).
 */
export function evaluateFlag(rules: FlagRules, bucket: number, ctx: EvalContext = {}): boolean {
  if (!rules.enabled) return false;

  if (rules.platforms && rules.platforms.length > 0) {
    if (!ctx.platform || !rules.platforms.includes(ctx.platform)) return false;
  }
  if (rules.minAppVersion) {
    if (!ctx.appVersion || compareVersions(ctx.appVersion, rules.minAppVersion) < 0) return false;
  }

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
  const platforms = Array.isArray(obj.platforms)
    ? obj.platforms.filter((p): p is string => typeof p === 'string')
    : undefined;
  const minAppVersion = typeof obj.minAppVersion === 'string' ? obj.minAppVersion : undefined;
  return {
    enabled,
    ...(pct !== undefined ? { rolloutPercentage: pct } : {}),
    ...(platforms && platforms.length > 0 ? { platforms } : {}),
    ...(minAppVersion ? { minAppVersion } : {}),
  };
}

export interface FlagRepository {
  findAll(): Promise<Flag[]>;
  /** Flag'i oluşturur ya da kurallarını değiştirir; `updatedBy` denetim için yazılır. */
  upsert(key: string, rules: FlagRules, updatedBy: string): Promise<Flag>;
}

/** Geçersiz flag anahtarı (küçük-harf-kebab değil). Controller 400'e çevirir. */
export class InvalidFlagKeyError extends Error {
  readonly code = 'flag_key_invalid';
  constructor() {
    super('Flag anahtarı geçersiz (küçük-harf-kebab, 1-64 karakter).');
    this.name = 'InvalidFlagKeyError';
  }
}

// Anahtar URL'den gelir (doğrulanmış DTO gövdesinden DEĞİL) → burada kapılanır:
// serbest anahtar, kod içinde beklenen sabit anahtarlarla eşleşmeyen çöp üretir.
const FLAG_KEY_RE = /^[a-z0-9][a-z0-9-]{0,63}$/;

export function assertValidFlagKey(key: string): void {
  if (!FLAG_KEY_RE.test(key)) throw new InvalidFlagKeyError();
}

export const FLAG_REPOSITORY = Symbol('FlagRepository');
export const BUCKET_HASHER = Symbol('BucketHasher');
