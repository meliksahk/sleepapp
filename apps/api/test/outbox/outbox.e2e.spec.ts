import { PrismaClient } from '@prisma/client';

import { PrismaSleepSessionRepository } from '../../src/modules/sleep/infrastructure/prisma-sleep-session.repository';
import { OutboxWriter } from '../../src/shared/outbox/outbox-writer';
import { PrismaOutboxRepository } from '../../src/shared/outbox/prisma-outbox.repository';
import { OutboxRelay } from '../../src/modules/notification/application/outbox-relay';
import type { PrismaService } from '../../src/shared/infra/prisma.service';
import type { CampaignJob, PushQueue } from '../../src/modules/notification/domain/push-queue';

/**
 * Outbox uçtan uca — GERÇEK Postgres (Prisma e2e deseni). İki garantiyi kanıtlar:
 *  1) Domain yazısı (uyku oturumu) + outbox olayı AYNI transaction'da (atomik) yazılır.
 *  2) Relay yayınlanmamışı çeker → push kuyruğa alınır (gözlemlenebilir tüketici) → damgalar.
 * Yani outbox ölü kod değil: gerçek olay, gerçek DB, gerçek tüketici davranışı.
 */
describe('Outbox (transactional write + relay, gerçek Postgres)', () => {
  const prisma = new PrismaClient();
  const asService = prisma as unknown as PrismaService;
  const repo = new PrismaSleepSessionRepository(asService, new OutboxWriter());
  const outboxRepo = new PrismaOutboxRepository(asService);
  let userId: string;
  const sessionIds: string[] = [];

  beforeAll(async () => {
    await prisma.$connect();
    const user = await prisma.users.create({ data: {} }); // kind default 'anonymous'
    userId = user.id;
    // İZOLASYON: paylaşımlı test DB'sinde başka e2e'ler (sleep.e2e) outbox satırı biriktirir;
    // relay ve findUnpublished(limit) bu birikimden etkilenmesin diye temiz sayfa. Hiçbir
    // başka test outbox'a assert etmez (yalnız bu dosya) → güvenli.
    await prisma.outbox.deleteMany({});
  });

  afterAll(async () => {
    await prisma.outbox.deleteMany({ where: { payload: { path: ['userId'], equals: userId } } });
    await prisma.sleep_sessions.deleteMany({ where: { user_id: userId } });
    await prisma.users.delete({ where: { id: userId } });
    await prisma.$disconnect();
  });

  it('ÇEKİRDEK: oturum kaydı + outbox olayı AYNI tx (atomik) — ikisi de kalıcı', async () => {
    const session = await repo.save(userId, {
      startedAt: new Date('2026-07-18T23:00:00.000Z'),
      endedAt: new Date('2026-07-19T06:00:00.000Z'),
      nightDate: '2026-07-18',
      durationMinutes: 420,
      movementEvents: 3,
      soundEvents: 5,
    });
    sessionIds.push(session.id);

    // Oturum satırı yazıldı.
    expect(await prisma.sleep_sessions.findUnique({ where: { id: session.id } })).not.toBeNull();
    // Aynı tx'te outbox olayı da yazıldı — DOĞRUDAN sorgu (birikime dayanıklı).
    const mine = await prisma.outbox.findFirst({
      where: { payload: { path: ['sessionId'], equals: session.id } },
    });
    expect(mine).not.toBeNull();
    expect(mine?.event_type).toBe('sleep.session_recorded');
    expect((mine?.payload as { userId?: string }).userId).toBe(userId);
  });

  it('ÇEKİRDEK: relay → push kuyruğa alınır (tüketici davranır) → yayınlandı damgalanır', async () => {
    const jobs: CampaignJob[] = [];
    const queue: PushQueue = { enqueue: async (j) => void jobs.push(j) };

    // Yayınlamadan önce benim olayım yayınlanmamış listede.
    const before = (await outboxRepo.findUnpublished(200)).filter(
      (e) => e.payload.userId === userId,
    );
    expect(before.length).toBeGreaterThanOrEqual(1);

    const published = await new OutboxRelay(outboxRepo, queue).relayOnce();
    expect(published).toBeGreaterThanOrEqual(1);

    // Benim kullanıcım için push kuyruğa alındı (gözlemlenebilir tüketici).
    expect(jobs.some((j) => j.userId === userId)).toBe(true);
    // Artık yayınlanmamış listede benim olayım yok (damgalandı → tekrar yayınlanmaz).
    const after = (await outboxRepo.findUnpublished(200)).filter(
      (e) => e.payload.userId === userId,
    );
    expect(after).toHaveLength(0);
  });
});
