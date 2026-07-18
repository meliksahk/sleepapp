import { BullMqPushQueue } from '../../src/modules/notification/infrastructure/bullmq-push-queue';
import type { SendNotificationUseCase } from '../../src/modules/notification/application/send-notification.usecase';

/**
 * GERÇEK Redis'e karşı entegrasyon (Postgres e2e'leri gibi — CI'da redis servisi var).
 *
 * Bu testin var olma sebebi: kuyruk ÖLÜ KOD OLMASIN. Sahte bir kuyruk "enqueue çağrıldı" der
 * ama işlerin Redis üzerinden GERÇEKTEN bir tüketiciye aktığını kanıtlamaz. Burada işler
 * gerçek Redis'e yazılır, worker onları çeker ve SendNotificationUseCase'i çağırır — yani
 * gözlemlenebilir tüketici davranışı doğrulanır.
 *
 * Redis gerekli: yerelde `docker compose up -d` (CLAUDE.md §9), CI'da redis servisi. Postgres
 * e2e'leriyle aynı sözleşme — Redis yoksa bu test (kasıtlı olarak) başarısız olur, sessizce
 * atlanmaz.
 */
const REDIS_URL = process.env.REDIS_TEST_URL ?? 'redis://127.0.0.1:6379';

async function waitFor(cond: () => boolean, timeoutMs: number): Promise<void> {
  const start = Date.now();
  while (!cond()) {
    if (Date.now() - start > timeoutMs) throw new Error(`waitFor zaman aşımı (${timeoutMs}ms)`);
    await new Promise((r) => setTimeout(r, 50));
  }
}

describe('BullMqPushQueue (gerçek Redis entegrasyonu, #190)', () => {
  let queue: BullMqPushQueue;
  const delivered: Array<{ userId: string; message: unknown }> = [];

  const fakeSend = {
    execute: async (userId: string, message: unknown) => {
      delivered.push({ userId, message });
      return { sent: 1, failed: 0 };
    },
  } as unknown as SendNotificationUseCase;

  // Benzersiz kuyruk adı: paylaşımlı yerel Redis'te önceki koşuların işleri karışmasın.
  const queueName = `push-campaign-test-${Date.now()}`;

  beforeAll(() => {
    queue = new BullMqPushQueue(REDIS_URL, fakeSend, queueName);
  });

  afterAll(async () => {
    // Kapatılmazsa açık Redis soketleri jest'i asar (RedisCache.onModuleDestroy ile aynı).
    await queue.onModuleDestroy();
  });

  it('ÇEKİRDEK: enqueue edilen işler worker tarafından gerçek Redis üzerinden teslim edilir', async () => {
    const jobs = [
      { userId: 'u1', title: 'T', body: 'B' },
      { userId: 'u2', title: 'T', body: 'B' },
      { userId: 'u3', title: 'T', body: 'B' },
    ];
    for (const j of jobs) await queue.enqueue(j);

    // Worker asenkron işler → hepsi teslim edilene kadar bekle.
    await waitFor(() => delivered.length === 3, 10000);

    expect(delivered.map((d) => d.userId).sort()).toEqual(['u1', 'u2', 'u3']);
    // Mesaj gövdesi doğru aktarıldı (title/body worker'a ulaştı).
    expect(delivered[0]?.message).toEqual({ title: 'T', body: 'B' });
  }, 20000);
});
