import 'reflect-metadata';
import { ValidationPipe, type INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { PrismaClient } from '@prisma/client';
import { AppModule } from '../../src/app.module';

/** analytics-ingest e2e (gerçek DB). Yut + validasyon + kalıcılık. */
describe('Analytics e2e (HTTP)', () => {
  let app: INestApplication;
  const prisma = new PrismaClient();

  const registerAndToken = async (): Promise<{ token: string; userId: string }> => {
    const res = await request(app.getHttpServer())
      .post('/v1/auth/device')
      .send({
        fingerprint: `analytics-e2e-${Date.now()}-${Math.round(process.hrtime()[1])}`,
        platform: 'ios',
      })
      .expect(201);
    return { token: res.body.accessToken, userId: res.body.userId };
  };

  beforeAll(async () => {
    await prisma.$connect();
    const moduleRef = await Test.createTestingModule({ imports: [AppModule] }).compile();
    app = moduleRef.createNestApplication();
    app.setGlobalPrefix('v1', { exclude: ['health'] });
    app.useGlobalPipes(
      new ValidationPipe({ whitelist: true, forbidNonWhitelisted: true, transform: true }),
    );
    await app.init();
  });

  afterAll(async () => {
    await prisma.$disconnect();
    await app.close();
  });

  it('token olmadan 401', async () => {
    await request(app.getHttpServer()).post('/v1/analytics/events').expect(401);
  });

  it('geçerli batch → 202 accepted + DB satırları', async () => {
    const { token, userId } = await registerAndToken();
    const res = await request(app.getHttpServer())
      .post('/v1/analytics/events')
      .set('Authorization', `Bearer ${token}`)
      .send({
        events: [
          { name: 'archetype_completed', occurredAt: '2026-05-01T10:00:00.000Z', props: { v: 1 } },
          { name: 'share_tapped', occurredAt: '2026-05-01T22:00:00.000Z' },
        ],
      })
      .expect(202);
    expect(res.body.accepted).toBe(2);

    const count = await prisma.analytics_events.count({ where: { user_id: userId } });
    expect(count).toBe(2);
    await prisma.analytics_events.deleteMany({ where: { user_id: userId } });
  });

  it('boş batch → 400 (validasyon)', async () => {
    const { token } = await registerAndToken();
    await request(app.getHttpServer())
      .post('/v1/analytics/events')
      .set('Authorization', `Bearer ${token}`)
      .send({ events: [] })
      .expect(400);
  });

  it('geçersiz olay adı → 400 (validasyon)', async () => {
    const { token } = await registerAndToken();
    await request(app.getHttpServer())
      .post('/v1/analytics/events')
      .set('Authorization', `Bearer ${token}`)
      .send({ events: [{ name: 'Bad Name', occurredAt: '2026-05-01T10:00:00.000Z' }] })
      .expect(400);
  });

  it('sözlükte olmayan olay → 400 unknown_event (docs/analytics-events.md)', async () => {
    const { token, userId } = await registerAndToken();
    const res = await request(app.getHttpServer())
      .post('/v1/analytics/events')
      .set('Authorization', `Bearer ${token}`)
      // biçimi geçerli ama sözlükte yok
      .send({ events: [{ name: 'totally_made_up', occurredAt: '2026-05-01T10:00:00.000Z' }] })
      .expect(400);
    expect(res.body.code).toBe('unknown_event');
    // batch reddedildi → hiçbir satır yazılmadı
    expect(await prisma.analytics_events.count({ where: { user_id: userId } })).toBe(0);
  });
});
