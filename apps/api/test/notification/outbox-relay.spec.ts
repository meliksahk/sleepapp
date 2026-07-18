import { OutboxRelay } from '../../src/modules/notification/application/outbox-relay';
import type { OutboxRecord, OutboxRepository } from '../../src/shared/outbox/outbox.types';
import type { CampaignJob, PushQueue } from '../../src/modules/notification/domain/push-queue';

/**
 * Relay dispatch mantığı (Redis/Postgres'siz). Uçtan uca (gerçek Postgres → kuyruk) ayrı
 * e2e'de; burada olay-tipi eşlemesi ve "damgala" garantisi doğrulanır.
 */
const evt = (over: Partial<OutboxRecord>): OutboxRecord => ({
  id: 'e1',
  aggregateType: 'sleep_session',
  eventType: 'sleep.session_recorded',
  payload: { userId: 'u1' },
  createdAt: new Date('2026-07-18T06:00:00Z'),
  ...over,
});

function fakeRepo(events: OutboxRecord[]): { repo: OutboxRepository; marked: string[] } {
  const marked: string[] = [];
  return {
    marked,
    repo: {
      findUnpublished: async () => events,
      markPublished: async (id) => {
        marked.push(id);
      },
    },
  };
}

describe('OutboxRelay (dispatch)', () => {
  const collectingQueue = (): { queue: PushQueue; jobs: CampaignJob[] } => {
    const jobs: CampaignJob[] = [];
    return { jobs, queue: { enqueue: async (j) => void jobs.push(j) } };
  };

  it('ÇEKİRDEK: session_recorded → push kuyruğa alınır + olay damgalanır', async () => {
    const { repo, marked } = fakeRepo([evt({ id: 'e1', payload: { userId: 'u1' } })]);
    const { queue, jobs } = collectingQueue();

    const published = await new OutboxRelay(repo, queue).relayOnce();

    expect(published).toBe(1);
    expect(jobs).toHaveLength(1);
    expect(jobs[0]?.userId).toBe('u1');
    expect(marked).toEqual(['e1']); // yayınlandı damgalandı → kuyrukta kalmaz
  });

  it('bilinmeyen olay tipi: push YOK ama yine DAMGALANIR (sonsuz döngü olmaz)', async () => {
    const { repo, marked } = fakeRepo([evt({ id: 'e2', eventType: 'something.else' })]);
    const { queue, jobs } = collectingQueue();

    await new OutboxRelay(repo, queue).relayOnce();

    expect(jobs).toHaveLength(0);
    expect(marked).toEqual(['e2']);
  });

  it('userId yoksa push YOK (savunmacı) ama damgalanır', async () => {
    const { repo, marked } = fakeRepo([evt({ id: 'e3', payload: {} })]);
    const { queue, jobs } = collectingQueue();

    await new OutboxRelay(repo, queue).relayOnce();

    expect(jobs).toHaveLength(0);
    expect(marked).toEqual(['e3']);
  });

  it('boş kuyruk: 0 yayınlanır, çökmez', async () => {
    const { repo } = fakeRepo([]);
    const { queue } = collectingQueue();
    expect(await new OutboxRelay(repo, queue).relayOnce()).toBe(0);
  });
});
