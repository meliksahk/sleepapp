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

/** Tek istekte kabul edilen azami olay sayısı (kötüye kullanım/DoS sınırı). */
export const MAX_EVENTS_PER_BATCH = 100;
