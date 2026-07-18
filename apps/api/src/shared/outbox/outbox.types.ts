/**
 * Transactional outbox tipleri (CLAUDE.md §3.2). Domain yazısıyla aynı transaction'da
 * yazılan olay; bir relay sonra yayınlar (dual-write kaybını önler).
 */

/** Yazılacak yeni olay (domain yazısıyla aynı tx içinde). */
export interface NewOutboxEvent {
  /** Kaynak agregat, ör. 'sleep_session'. */
  readonly aggregateType: string;
  /** Olay tipi (relay bunun üstünden dispatch eder), ör. 'sleep.session_recorded'. */
  readonly eventType: string;
  /** Olay verisi — ham PII taşımaz (§6); yalnız id/metrik referansları. */
  readonly payload: Record<string, unknown>;
}

/** Yayınlanmamış outbox satırı (relay okur). */
export interface OutboxRecord {
  readonly id: string;
  readonly aggregateType: string;
  readonly eventType: string;
  readonly payload: Record<string, unknown>;
  readonly createdAt: Date;
}

export const OUTBOX_REPOSITORY = Symbol('OUTBOX_REPOSITORY');

export interface OutboxRepository {
  /** En eski yayınlanmamış olaylar (kısmi index üzerinden). */
  findUnpublished(limit: number): Promise<OutboxRecord[]>;
  /** Yayınlandı olarak damgala (published_at = now). */
  markPublished(id: string): Promise<void>;
}
