import {
  isKnownEventName,
  isValidEventName,
  MAX_EVENTS_PER_BATCH,
  type NewAnalyticsEvent,
} from '../domain/analytics-event';
import { AnalyticsError } from '../domain/errors';
import type { AnalyticsEventRepository } from '../domain/ports';

/**
 * Olay batch'ini yutar (ingest). Boş/aşırı batch ve geçersiz ad reddedilir.
 * Kabul edilen olay sayısını döner (202 Accepted semantiği).
 */
export class IngestEventsUseCase {
  constructor(private readonly repo: AnalyticsEventRepository) {}

  async execute(userId: string, events: readonly NewAnalyticsEvent[]): Promise<number> {
    if (events.length === 0) {
      throw new AnalyticsError('empty_batch', 'En az bir olay gerekli.');
    }
    if (events.length > MAX_EVENTS_PER_BATCH) {
      throw new AnalyticsError(
        'batch_too_large',
        `Tek istekte en fazla ${MAX_EVENTS_PER_BATCH} olay.`,
      );
    }
    for (const e of events) {
      if (!isValidEventName(e.name)) {
        throw new AnalyticsError('invalid_event_name', `Geçersiz olay adı: ${e.name}`);
      }
      // Sözlük kapısı (docs/01 §7): tanımsız olay veri kalitesini bozar → reddedilir.
      if (!isKnownEventName(e.name)) {
        throw new AnalyticsError('unknown_event', `Sözlükte olmayan olay: ${e.name}`);
      }
    }
    return this.repo.saveBatch(userId, events);
  }
}
