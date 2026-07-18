import 'reflect-metadata';
import { ValidationPipe, type INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { PrismaClient } from '@prisma/client';

import { AppModule } from '../../src/app.module';

/**
 * `GET /v1/admin/flags` — feature flag rollout görünürlüğü (docs/03 A4). Salt okuma:
 * her panel rolü görebilir (kullanıcı aramasının aksine — o PII, owner/support).
 */
describe('Admin flags list e2e (HTTP)', () => {
  let app: INestApplication;
  const prisma = new PrismaClient();
  const createdUsers: string[] = [];
  const flagKey = `test-flag-${Date.now()}`;

  const register = async () => {
    const reg = await request(app.getHttpServer())
      .post('/v1/auth/device')
      .send({
        fingerprint: `flg-${Date.now()}-${Math.round(process.hrtime()[1])}`,
        platform: 'ios',
      })
      .expect(201);
    createdUsers.push(reg.body.userId);
    return reg.body;
  };

  const tokenFor = async (roles: string[]): Promise<string> => {
    const reg = await register();
    await prisma.users.update({ where: { id: reg.userId }, data: { kind: 'admin', roles } });
    const refreshed = await request(app.getHttpServer())
      .post('/v1/auth/refresh')
      .send({ refreshToken: reg.refreshToken })
      .expect(200);
    return refreshed.body.accessToken;
  };

  const listFlags = (token: string) =>
    request(app.getHttpServer()).get('/v1/admin/flags').set('Authorization', `Bearer ${token}`);

  beforeAll(async () => {
    await prisma.$connect();
    const moduleRef = await Test.createTestingModule({ imports: [AppModule] }).compile();
    app = moduleRef.createNestApplication();
    app.setGlobalPrefix('v1', { exclude: ['health'] });
    app.useGlobalPipes(
      new ValidationPipe({ whitelist: true, forbidNonWhitelisted: true, transform: true }),
    );
    await app.init();
    await prisma.feature_flags.create({
      data: { key: flagKey, rules: { enabled: true, rolloutPercentage: 50 } },
    });
  });

  afterAll(async () => {
    await prisma.feature_flags.deleteMany({ where: { key: flagKey } });
    if (createdUsers.length > 0) {
      await prisma.users.deleteMany({ where: { id: { in: createdUsers } } });
    }
    await prisma.$disconnect();
    await app.close();
  });

  it('token olmadan 401', async () => {
    await request(app.getHttpServer()).get('/v1/admin/flags').expect(401);
  });

  it('ÇEKİRDEK: owner ham kurallarıyla flag listesini alır', async () => {
    const token = await tokenFor(['owner']);
    const res = await listFlags(token).expect(200);
    const hit = (
      res.body as Array<{ key: string; rules: { enabled: boolean; rolloutPercentage?: number } }>
    ).find((f) => f.key === flagKey);
    expect(hit).toBeDefined();
    expect(hit!.rules.enabled).toBe(true);
    expect(hit!.rules.rolloutPercentage).toBe(50);
  });

  it('salt okuma: analyst da GÖREBİLİR (kullanıcı aramasının aksine — PII değil)', async () => {
    const token = await tokenFor(['analyst']);
    await listFlags(token).expect(200);
  });

  it('ÇEKİRDEK: admin OLMAYAN 403', async () => {
    const reg = await register();
    await listFlags(reg.accessToken).expect(403);
  });
});
