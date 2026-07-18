import 'reflect-metadata';
import { ValidationPipe, type INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { PrismaClient } from '@prisma/client';

import { AppModule } from '../../src/app.module';

/**
 * `PUT /v1/admin/flags/:key` — flag oluştur/değiştir (docs/03 A4). Yalnızca `owner`:
 * flag'ler her özelliğin rollout'unu kontrol eder → editörden dar yetki. Denetim izi
 * zorunlu. Gövde doğrulaması (rollout 0-100, semver) global ValidationPipe ile.
 */
describe('Admin flag upsert e2e (HTTP)', () => {
  let app: INestApplication;
  const prisma = new PrismaClient();
  const createdUsers: string[] = [];
  const flagKey = `up-flag-${Date.now()}`;

  const register = async () => {
    const reg = await request(app.getHttpServer())
      .post('/v1/auth/device')
      .send({
        fingerprint: `upf-${Date.now()}-${Math.round(process.hrtime()[1])}`,
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

  const putFlag = (token: string, key: string, body: object) =>
    request(app.getHttpServer())
      .put(`/v1/admin/flags/${key}`)
      .set('Authorization', `Bearer ${token}`)
      .send(body);

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
    await prisma.feature_flags.deleteMany({ where: { key: flagKey } });
    if (createdUsers.length > 0) {
      await prisma.users.deleteMany({ where: { id: { in: createdUsers } } });
    }
    await prisma.$disconnect();
    await app.close();
  });

  it('ÇEKİRDEK: owner flag OLUŞTURUR sonra DEĞİŞTİRİR (upsert), updated_by yazılır', async () => {
    const token = await tokenFor(['owner']);

    // Oluştur
    const created = await putFlag(token, flagKey, {
      enabled: true,
      rolloutPercentage: 25,
      platforms: ['ios'],
    }).expect(200);
    expect(created.body.key).toBe(flagKey);
    expect(created.body.rules.enabled).toBe(true);
    expect(created.body.rules.rolloutPercentage).toBe(25);
    expect(created.body.rules.platforms).toEqual(['ios']);

    // updated_by token sahibinin id'si olmalı (gövdeden değil)
    const row = await prisma.feature_flags.findUnique({ where: { key: flagKey } });
    expect(row?.updated_by).toBeTruthy();

    // Değiştir: yüzdeyi kaldır (herkes), platformu genişlet
    const updated = await putFlag(token, flagKey, {
      enabled: false,
      platforms: ['ios', 'android'],
    }).expect(200);
    expect(updated.body.rules.enabled).toBe(false);
    expect(updated.body.rules.rolloutPercentage).toBeUndefined();
    expect(updated.body.rules.platforms).toEqual(['ios', 'android']);
  });

  it('denetim izi: upsert sonrası audit akışında flag.upsert görünür', async () => {
    const token = await tokenFor(['owner']);
    const auditKey = `${flagKey}-audit`;
    await putFlag(token, auditKey, { enabled: true }).expect(200);
    const audit = await request(app.getHttpServer())
      .get('/v1/admin/audit')
      .set('Authorization', `Bearer ${token}`)
      .expect(200);
    const hit = (audit.body as Array<{ action: string; target: string }>).find(
      (e) => e.action === 'flag.upsert' && e.target === auditKey,
    );
    expect(hit).toBeDefined();
    await prisma.feature_flags.deleteMany({ where: { key: auditKey } });
  });

  it('ÇEKİRDEK: owner OLMAYAN (editor) 403 — flag yetkisi owner-özel', async () => {
    const token = await tokenFor(['editor']);
    await putFlag(token, `${flagKey}-x`, { enabled: true }).expect(403);
  });

  it('analyst 403 (salt okunur)', async () => {
    const token = await tokenFor(['analyst']);
    await putFlag(token, `${flagKey}-y`, { enabled: true }).expect(403);
  });

  it('doğrulama: rolloutPercentage 100 üstü 400', async () => {
    const token = await tokenFor(['owner']);
    await putFlag(token, `${flagKey}-z`, { enabled: true, rolloutPercentage: 250 }).expect(400);
  });

  it('doğrulama: geçersiz anahtar (büyük harf) 400', async () => {
    const token = await tokenFor(['owner']);
    await putFlag(token, 'BadKey', { enabled: true }).expect(400);
  });

  it('token olmadan 401', async () => {
    await putFlag('', `${flagKey}-w`, { enabled: true }).expect(401);
  });
});
