import {
  isValidEventName,
  MAX_EVENTS_PER_BATCH,
} from '../../src/modules/analytics/domain/analytics-event';
import { IngestEventsUseCase } from '../../src/modules/analytics/application/ingest-events.usecase';
import { AnalyticsError } from '../../src/modules/analytics/domain/errors';
import type { AnalyticsEventRepository } from '../../src/modules/analytics/domain/ports';
import type { NewAnalyticsEvent } from '../../src/modules/analytics/domain/analytics-event';

class FakeRepo implements AnalyticsEventRepository {
  saved: NewAnalyticsEvent[] = [];
  async saveBatch(_userId: string, events: readonly NewAnalyticsEvent[]): Promise<number> {
    this.saved.push(...events);
    return events.length;
  }
}

const ev = (name: string): NewAnalyticsEvent => ({
  name,
  occurredAt: new Date('2026-01-01T00:00:00Z'),
  props: {},
});

describe('isValidEventName', () => {
  it('geçerli adlar', () => {
    for (const n of ['archetype_completed', 'sleep.session.recorded', 'a1']) {
      expect(isValidEventName(n)).toBe(true);
    }
  });
  it('geçersiz adlar', () => {
    for (const n of ['UpperCase', 'has space', 'çğ', '', 'a'.repeat(65)]) {
      expect(isValidEventName(n)).toBe(false);
    }
  });
});

describe('IngestEventsUseCase', () => {
  it('geçerli batch kaydeder ve sayı döner', async () => {
    const repo = new FakeRepo();
    const n = await new IngestEventsUseCase(repo).execute('u', [ev('a_b'), ev('c.d')]);
    expect(n).toBe(2);
    expect(repo.saved).toHaveLength(2);
  });

  it('boş batch → empty_batch', async () => {
    const repo = new FakeRepo();
    await expect(new IngestEventsUseCase(repo).execute('u', [])).rejects.toBeInstanceOf(
      AnalyticsError,
    );
  });

  it('aşırı batch → batch_too_large', async () => {
    const repo = new FakeRepo();
    const big = Array.from({ length: MAX_EVENTS_PER_BATCH + 1 }, () => ev('a'));
    await expect(new IngestEventsUseCase(repo).execute('u', big)).rejects.toMatchObject({
      code: 'batch_too_large',
    });
  });

  it('geçersiz ad → invalid_event_name', async () => {
    const repo = new FakeRepo();
    await expect(
      new IngestEventsUseCase(repo).execute('u', [ev('Bad Name')]),
    ).rejects.toMatchObject({ code: 'invalid_event_name' });
  });
});
