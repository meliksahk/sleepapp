import 'reflect-metadata';
import { ValidationPipe, type INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { PrismaClient } from '@prisma/client';
import { AppModule } from '../../src/app.module';
import { IdempotencyInterceptor } from '../../src/shared/http/idempotency.interceptor';

/** Idempotency-Key: aynı anahtar → aynı yanıt, yeni işlem yok (docs/02 §4). */
describe('Idempotency e2e', () => {
  let app: INestApplication;
  const prisma = new PrismaClient();
  const allA = { q1: 'q1a', q2: 'q2a', q3: 'q3a', q4: 'q4a', q5: 'q5a', q6: 'q6a' };
  const slugs: string[] = [];

  beforeAll(async () => {
    await prisma.$connect();
    const moduleRef = await Test.createTestingModule({ imports: [AppModule] }).compile();
    app = moduleRef.createNestApplication();
    app.setGlobalPrefix('v1', { exclude: ['health'] });
    app.useGlobalPipes(
      new ValidationPipe({ whitelist: true, forbidNonWhitelisted: true, transform: true }),
    );
    app.useGlobalInterceptors(new IdempotencyInterceptor());
    await app.init();
  });

  afterAll(async () => {
    if (slugs.length)
      await prisma.web_archetype_results.deleteMany({ where: { share_slug: { in: slugs } } });
    await prisma.$disconnect();
    await app.close();
  });

  it('aynı Idempotency-Key → aynı sonuç (yeni kayıt yok)', async () => {
    const key = `idem-${Date.now()}-${Math.round(process.hrtime()[1])}`;
    const r1 = await request(app.getHttpServer())
      .post('/v1/archetype/web')
      .set('Idempotency-Key', key)
      .send({ version: 1, answers: allA })
      .expect(201);
    const r2 = await request(app.getHttpServer())
      .post('/v1/archetype/web')
      .set('Idempotency-Key', key)
      .send({ version: 1, answers: allA })
      .expect(201);

    expect(r2.body.shareSlug).toBe(r1.body.shareSlug); // cache hit
    slugs.push(r1.body.shareSlug);

    // Anahtar yoksa her çağrı yeni slug üretir (kontrast).
    const r3 = await request(app.getHttpServer())
      .post('/v1/archetype/web')
      .send({ version: 1, answers: allA })
      .expect(201);
    expect(r3.body.shareSlug).not.toBe(r1.body.shareSlug);
    slugs.push(r3.body.shareSlug);

    // DB'de yalnızca 2 satır olmalı (idempotent olan tek kayıt + anahtarsız).
    const count = await prisma.web_archetype_results.count({
      where: { share_slug: { in: [r1.body.shareSlug, r3.body.shareSlug] } },
    });
    expect(count).toBe(2);
  });
});
