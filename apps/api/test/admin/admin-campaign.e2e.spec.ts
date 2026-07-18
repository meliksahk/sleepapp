import 'reflect-metadata';
import { ValidationPipe, type INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { PrismaClient } from '@prisma/client';

import { AppModule } from '../../src/app.module';

/**
 * `POST /v1/admin/campaigns` — owner push kampanyası (#183). Segment = push token'ı olan
 * kullanıcılar; teslim LogPushSender. Opt-out fan-out'ta zaten dışlanır (send-notification.spec
 * kapsıyor). Paylaşımlı DB → segment başka token'ları da içerebilir; assert'ler `>=` (kendi
 * seed'imizin dahil olduğunu kanıtlar, izole sayı değil).
 */
describe('Admin campaign e2e (HTTP)', () => {
  let app: INestApplication;
  const prisma = new PrismaClient();
  const createdUsers: string[] = [];
  const createdTokens: string[] = [];

  const register = async () => {
    const reg = await request(app.getHttpServer())
      .post('/v1/auth/device')
      .send({
        fingerprint: `cmp-${Date.now()}-${Math.round(process.hrtime()[1])}`,
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

  /** Yeni bir kullanıcı + tek push token'ı seed'ler (segment üyesi). */
  const seedPushUser = async (platform: string): Promise<void> => {
    const reg = await register();
    const token = `cmp-tok-${platform}-${Date.now()}-${Math.round(process.hrtime()[1])}`;
    createdTokens.push(token);
    await prisma.device_tokens.create({
      data: { user_id: reg.userId, token, platform },
    });
  };

  const sendCampaign = (jwt: string, body: object) =>
    request(app.getHttpServer())
      .post('/v1/admin/campaigns')
      .set('Authorization', `Bearer ${jwt}`)
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
    // İki ios push kullanıcısı (varsayılan notifications_enabled=true → gönderilir).
    await seedPushUser('ios');
    await seedPushUser('ios');
  });

  afterAll(async () => {
    if (createdTokens.length > 0) {
      await prisma.device_tokens.deleteMany({ where: { token: { in: createdTokens } } });
    }
    if (createdUsers.length > 0) {
      await prisma.users.deleteMany({ where: { id: { in: createdUsers } } });
    }
    await prisma.$disconnect();
    await app.close();
  });

  it('token olmadan 401', async () => {
    await sendCampaign('', { title: 't', body: 'b' }).expect(401);
  });

  it('ÇEKİRDEK: owner kampanya gönderir, segment fan-out edilir (seed edilenler dahil)', async () => {
    const token = await tokenFor(['owner']);
    const res = await sendCampaign(token, { title: 'Haftalık ses', body: 'Yayında.' }).expect(200);
    // İki seed kullanıcı + token'ı; başka token'lar da olabilir → >=.
    expect(res.body.recipients).toBeGreaterThanOrEqual(2);
    expect(res.body.sent).toBeGreaterThanOrEqual(2);
    expect(res.body.failed).toBe(0); // LogPushSender hep başarır
  });

  it('ÇEKİRDEK: platform filtresi ALT KÜME (all ⊇ ios), ios seed edilenleri içerir', async () => {
    const token = await tokenFor(['owner']);
    const all = await sendCampaign(token, { title: 'a', body: 'b' }).expect(200);
    const ios = await sendCampaign(token, { title: 'a', body: 'b', platform: 'ios' }).expect(200);
    expect(ios.body.recipients).toBeGreaterThanOrEqual(2); // iki ios seed
    expect(all.body.recipients).toBeGreaterThanOrEqual(ios.body.recipients); // all, ios'un üst kümesi
  });

  it('denetim izi: gönderim sonrası audit akışında campaign.send görünür', async () => {
    const token = await tokenFor(['owner']);
    await sendCampaign(token, { title: 'Denetim', body: 'x' }).expect(200);
    const audit = await request(app.getHttpServer())
      .get('/v1/admin/audit')
      .set('Authorization', `Bearer ${token}`)
      .expect(200);
    const hit = (audit.body as Array<{ action: string }>).find((e) => e.action === 'campaign.send');
    expect(hit).toBeDefined();
  });

  it('ÇEKİRDEK: owner OLMAYAN (editor) 403 — kampanya owner-özel', async () => {
    const token = await tokenFor(['editor']);
    await sendCampaign(token, { title: 't', body: 'b' }).expect(403);
  });

  it('doğrulama: boş başlık 400', async () => {
    const token = await tokenFor(['owner']);
    await sendCampaign(token, { title: '', body: 'b' }).expect(400);
  });

  it('doğrulama: geçersiz platform 400', async () => {
    const token = await tokenFor(['owner']);
    await sendCampaign(token, { title: 't', body: 'b', platform: 'windows' }).expect(400);
  });
});
