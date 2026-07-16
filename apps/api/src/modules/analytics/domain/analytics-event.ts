/** Analitik olayı (docs/02 analytics-ingest). Saf domain. PII taşımaz. */
export interface NewAnalyticsEvent {
  readonly name: string;
  readonly occurredAt: Date;
  readonly props: Record<string, unknown>;
}

/** Geçerli olay adı: 1-64, küçük harf/rakam/alt-çizgi/nokta (ör. archetype_completed). */
const EVENT_NAME_RE = /^[a-z0-9_.]{1,64}$/;

export function isValidEventName(name: string): boolean {
  return EVENT_NAME_RE.test(name);
}

/**
 * OLAY SÖZLÜĞÜ (docs/01 §7, docs/analytics-events.md) — tek kaynak.
 * "Sözlükte olmayan event gönderilemez": ingest bilinmeyen adı reddeder.
 * Yeni olay eklerken ÖNCE buraya + docs/analytics-events.md'ye eklenir,
 * sonra istemci gönderebilir. Yalnızca gerçekten yayılan olaylar listelenir.
 */
export const KNOWN_EVENT_NAMES: ReadonlySet<string> = new Set([
  'archetype_completed', // archetype testi tamamlandı (props: archetype)
  'share_tapped', // archetype kartı paylaşıldı (props: archetype)
]);

export function isKnownEventName(name: string): boolean {
  return KNOWN_EVENT_NAMES.has(name);
}

/** Tek istekte kabul edilen azami olay sayısı (kötüye kullanım/DoS sınırı). */
export const MAX_EVENTS_PER_BATCH = 100;
