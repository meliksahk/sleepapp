import 'reflect-metadata';
import { ValidationPipe, type INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { PrismaClient } from '@prisma/client';
import { AppModule } from '../../src/app.module';

/**
 * Panel panosu e2e (gerçek DB).
 *
 * NEDEN: pano dört yer tutucu "—" gösteriyordu. İçerik yönetimi çalışırken panelin
 * İLK ekranının sahte olması en görünür yalandı.
 *
 * KAPSAM DÜRÜSTLÜĞÜ: yalnızca bugün DOĞRU hesaplanabilenler var. D7 retention
 * (kohort analizi) ve deneme→ücretli (F6/billing yok) bilerek YOK — sahte sayı
 * göstermektense yer tutucu dürüsttür.
 */
describe('Admin pano e2e (HTTP)', () => {
  let app: INestApplication;
  const prisma = new PrismaClient();
  const prefix = `ovw${Date.now()}`;
  const createdUsers: string[] = [];

  const tokenFor = async (roles: string[]): Promise<string> => {
    const reg = await request(app.getHttpServer())
      .post('/v1/auth/device')
      .send({
        fingerprint: `ovw-${Date.now()}-${Math.round(process.hrtime()[1])}`,
        platform: 'ios',
      })
      .expect(201);
    createdUsers.push(reg.body.userId);
    await prisma.users.update({ where: { id: reg.body.userId }, data: { kind: 'admin', roles } });
    const refreshed = await request(app.getHttpServer())
      .post('/v1/auth/refresh')
      .send({ refreshToken: reg.body.refreshToken })
      .expect(200);
    return refreshed.body.accessToken;
  };

  const overview = (token: string) =>
    request(app.getHttpServer()).get('/v1/admin/overview').set('Authorization', `Bearer ${token}`);

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
    await prisma.soundscapes.deleteMany({ where: { slug: { startsWith: prefix } } });
    await prisma.waitlist.deleteMany({ where: { email: { startsWith: prefix } } });
    if (createdUsers.length > 0) {
      await prisma.users.deleteMany({ where: { id: { in: createdUsers } } });
    }
    await prisma.$disconnect();
    await app.close();
  });

  it('durum başına sayılar DOĞRU (eklenen kayıtlar sayıya yansır)', async () => {
    const token = await tokenFor(['owner']);
    const before = await overview(token).expect(200);

    await prisma.soundscapes.createMany({
      data: [
        {
          slug: `${prefix}-d1`,
          title_i18n: {},
          engine_params: {},
          layer_defs: [],
          status: 'draft',
        },
        {
          slug: `${prefix}-d2`,
          title_i18n: {},
          engine_params: {},
          layer_defs: [],
          status: 'draft',
        },
        {
          slug: `${prefix}-p1`,
          title_i18n: {},
          engine_params: {},
          layer_defs: [],
          status: 'published',
        },
      ],
    });

    const after = await overview(token).expect(200);
    // Mutlak sayı yerine FARK: test DB'sinde başka kayıtlar olabilir.
    expect(after.body.soundscapes.draft - before.body.soundscapes.draft).toBe(2);
    expect(after.body.soundscapes.published - before.body.soundscapes.published).toBe(1);
  });

  it('hiç kayıt olmayan durum 0 döner, EKSİK ALAN değil', async () => {
    // groupBy yalnızca VAR OLAN durumları döndürür; eksik anahtar panelde
    // "undefined" olarak görünürdü.
    const res = await overview(await tokenFor(['owner'])).expect(200);
    expect(typeof res.body.soundscapes.scheduled).toBe('number');
    expect(typeof res.body.soundscapes.draft).toBe('number');
    expect(typeof res.body.soundscapes.published).toBe('number');
  });

  it('bekleme listesi sayısı DOĞRU (katılım sayıya yansır)', async () => {
    const token = await tokenFor(['owner']);
    const before = await overview(token).expect(200);

    await request(app.getHttpServer())
      .post('/v1/waitlist')
      .send({ email: `${prefix}-a@nocta.test` })
      .expect(202);
    await request(app.getHttpServer())
      .post('/v1/waitlist')
      .send({ email: `${prefix}-b@nocta.test` })
      .expect(202);

    const after = await overview(token).expect(200);
    expect(after.body.waitlist - before.body.waitlist).toBe(2);
  });

  it('aynı e-posta iki kez → sayı BİR artar (waitlist idempotent)', async () => {
    const token = await tokenFor(['owner']);
    const email = `${prefix}-dup@nocta.test`;

    await request(app.getHttpServer()).post('/v1/waitlist').send({ email }).expect(202);
    const mid = await overview(token).expect(200);
    await request(app.getHttpServer()).post('/v1/waitlist').send({ email }).expect(202);
    const after = await overview(token).expect(200);

    expect(after.body.waitlist).toBe(mid.body.waitlist);
  });

  it('ÖLÇÜLEMEYEN metrik UYDURULMAZ: yanıtta d7/trial alanı YOK', async () => {
    // Sahte sayı üretmektense panelde dürüst yer tutucu kalır.
    const res = await overview(await tokenFor(['owner'])).expect(200);
    expect(res.body).not.toHaveProperty('d7Retention');
    expect(res.body).not.toHaveProperty('trialConversion');
    expect(Object.keys(res.body).sort()).toEqual(['soundscapes', 'waitlist']);
  });

  it('analyst panoyu görebilir (salt okunur rol okumaya açık)', async () => {
    await overview(await tokenFor(['analyst'])).expect(200);
  });

  it('mobil (cihaz) token → 403', async () => {
    const dev = await request(app.getHttpServer())
      .post('/v1/auth/device')
      .send({ fingerprint: `ovw-dev-${Date.now()}`, platform: 'ios' })
      .expect(201);
    createdUsers.push(dev.body.userId);
    await overview(dev.body.accessToken).expect(403);
  });

  it('token yok → 401', async () => {
    await request(app.getHttpServer()).get('/v1/admin/overview').expect(401);
  });
});
