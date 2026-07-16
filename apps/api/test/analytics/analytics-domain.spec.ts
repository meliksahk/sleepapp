import {
  isKnownEventName,
  isValidEventName,
  KNOWN_EVENT_NAMES,
  MAX_EVENTS_PER_BATCH,
} from '../../src/modules/analytics/domain/analytics-event';
import { IngestEventsUseCase } from '../../src/modules/analytics/application/ingest-events.usecase';
import { AnalyticsError } from '../../src/modules/analytics/domain/errors';
import type {
  AnalyticsEventRepository,
  ShareFunnelCounts,
} from '../../src/modules/analytics/domain/ports';
import type { NewAnalyticsEvent } from '../../src/modules/analytics/domain/analytics-event';

class FakeRepo implements AnalyticsEventRepository {
  shareFunnel(): Promise<ShareFunnelCounts> {
    throw new Error('kullanılmaz');
  }

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

describe('olay sözlüğü (docs/analytics-events.md)', () => {
  it('sözlükteki olaylar bilinir', () => {
    for (const n of ['archetype_completed', 'share_tapped', 'report_shared']) {
      expect(isKnownEventName(n)).toBe(true);
    }
  });

  it('sözlükte olmayan (biçimi geçerli) olay bilinmez', () => {
    expect(isValidEventName('totally_made_up')).toBe(true); // biçim tamam
    expect(isKnownEventName('totally_made_up')).toBe(false); // ama sözlükte yok
  });

  it('sözlükteki her ad biçim kuralına uyar (tutarlılık)', () => {
    for (const n of KNOWN_EVENT_NAMES) {
      expect(isValidEventName(n)).toBe(true);
    }
  });
});

describe('IngestEventsUseCase', () => {
  it('geçerli batch kaydeder ve sayı döner', async () => {
    const repo = new FakeRepo();
    const n = await new IngestEventsUseCase(repo).execute('u', [
      ev('archetype_completed'),
      ev('share_tapped'),
    ]);
    expect(n).toBe(2);
    expect(repo.saved).toHaveLength(2);
  });

  it('sözlükte olmayan ad → unknown_event (batch tümden reddedilir)', async () => {
    const repo = new FakeRepo();
    await expect(
      new IngestEventsUseCase(repo).execute('u', [ev('archetype_completed'), ev('made_up')]),
    ).rejects.toMatchObject({ code: 'unknown_event' });
    expect(repo.saved).toHaveLength(0); // kısmi kabul yok
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
