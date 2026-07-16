import 'reflect-metadata';
import { ValidationPipe, type INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { PrismaClient } from '@prisma/client';
import { AppModule } from '../../src/app.module';

/**
 * Ses tarifi yazma e2e (gerçek DB).
 *
 * NEDEN: #122 yayınlama kapısını koydu (boş tarif yayınlanamaz) ama tarifi doldurmanın
 * PANELDEN yolu yoktu → içerik ancak DB'ye elle müdahaleyle yayınlanabiliyordu.
 *
 * ÇEKİRDEK İDDİA: bozuk tarif DB'ye GİREMEZ. `engine_params` serbest `jsonb`;
 * doğrulanmazsa hata ancak KULLANICININ TELEFONUNDA, çalma anında ortaya çıkar.
 */
describe('Admin ses tarifi e2e (HTTP)', () => {
  let app: INestApplication;
  const prisma = new PrismaClient();
  const prefix = `rcp${Date.now()}`;
  const createdUsers: string[] = [];

  const VALID = { schemaVersion: 1, layers: [{ id: 'base', type: 'pink', gain: 0.5 }] };

  const tokenFor = async (roles: string[]): Promise<string> => {
    const reg = await request(app.getHttpServer())
      .post('/v1/auth/device')
      .send({
        fingerprint: `rcp-${Date.now()}-${Math.round(process.hrtime()[1])}`,
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

  const seed = async (slug: string, status = 'draft'): Promise<void> => {
    await prisma.soundscapes.create({
      data: {
        slug,
        title_i18n: { en: slug },
        engine_params: {},
        layer_defs: [],
        status: status as 'draft' | 'published',
      },
    });
  };

  const setRecipe = (token: string, slug: string, body: unknown) =>
    request(app.getHttpServer())
      .put(`/v1/admin/soundscapes/${slug}/recipe`)
      .set('Authorization', `Bearer ${token}`)
      .send(body as object);

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
    if (createdUsers.length > 0) {
      await prisma.users.deleteMany({ where: { id: { in: createdUsers } } });
    }
    await prisma.$disconnect();
    await app.close();
  });

  it("geçerli tarif yazılır ve DB'de DOĞRULANMIŞ hâliyle durur", async () => {
    const slug = `${prefix}-ok`;
    await seed(slug);
    await setRecipe(await tokenFor(['editor']), slug, VALID).expect(200);

    const row = await prisma.soundscapes.findUnique({ where: { slug } });
    expect(row?.engine_params).toEqual(VALID);
  });

  it('ÇEKİRDEK: tarif yazınca kayıt YAYINLANABİLİR hâle gelir (#122 kapısı açılır)', async () => {
    // Bu iterasyonun bütün sebebi: kapı vardı ama açacak anahtar (panelden tarif)
    // yoktu → içerik ancak DB'ye elle müdahaleyle yayınlanabiliyordu.
    const slug = `${prefix}-unlock`;
    await seed(slug);
    const token = await tokenFor(['editor']);

    await request(app.getHttpServer())
      .post(`/v1/admin/soundscapes/${slug}/publish`)
      .set('Authorization', `Bearer ${token}`)
      .expect(409); // önce: boş tarif → yayınlanamaz

    await setRecipe(token, slug, VALID).expect(200);

    await request(app.getHttpServer())
      .post(`/v1/admin/soundscapes/${slug}/publish`)
      .set('Authorization', `Bearer ${token}`)
      .expect(200); // sonra: yayınlanabilir
  });

  it("tarif UYGULAMANIN feed'ine ulaşır (uçtan uca anlam)", async () => {
    const slug = `${prefix}-feed`;
    await seed(slug);
    const token = await tokenFor(['editor']);
    await setRecipe(token, slug, VALID).expect(200);
    await request(app.getHttpServer())
      .post(`/v1/admin/soundscapes/${slug}/publish`)
      .set('Authorization', `Bearer ${token}`)
      .expect(200);

    const device = await request(app.getHttpServer())
      .post('/v1/auth/device')
      .send({ fingerprint: `rcp-feed-${Date.now()}`, platform: 'ios' })
      .expect(201);
    createdUsers.push(device.body.userId);

    const feed = await request(app.getHttpServer())
      .get('/v1/content/feed')
      .set('Authorization', `Bearer ${device.body.accessToken}`)
      .expect(200);
    const mine = feed.body.find((s: { slug: string }) => s.slug === slug);
    expect(mine.engineParams).toEqual(VALID);
  });

  it('YAYINDAKİ kaydın tarifi değişince feed ANINDA günceller (ısıtılmış cache)', async () => {
    // #122'nin dersi: cache'i ısıtmadan test etmek, bayat içerik hatasını gizler.
    const slug = `${prefix}-cache`;
    await seed(slug);
    const token = await tokenFor(['editor']);
    await setRecipe(token, slug, VALID).expect(200);
    await request(app.getHttpServer())
      .post(`/v1/admin/soundscapes/${slug}/publish`)
      .set('Authorization', `Bearer ${token}`)
      .expect(200);

    const device = await request(app.getHttpServer())
      .post('/v1/auth/device')
      .send({ fingerprint: `rcp-cache-${Date.now()}`, platform: 'ios' })
      .expect(201);
    createdUsers.push(device.body.userId);
    const feedNow = async () => {
      const r = await request(app.getHttpServer())
        .get('/v1/content/feed')
        .set('Authorization', `Bearer ${device.body.accessToken}`)
        .expect(200);
      return r.body.find((s: { slug: string }) => s.slug === slug);
    };

    expect((await feedNow()).engineParams.layers[0].gain).toBe(0.5); // cache ısındı

    const changed = { schemaVersion: 1, layers: [{ id: 'base', type: 'brown', gain: 0.9 }] };
    await setRecipe(token, slug, changed).expect(200);

    const after = await feedNow();
    expect(after.engineParams.layers[0].gain).toBe(0.9);
    expect(after.engineParams.layers[0].type).toBe('brown');
  });

  it.each([
    ['sürüm yok', { layers: [{ id: 'a', type: 'pink', gain: 0.5 }] }],
    ['bilinmeyen sürüm', { schemaVersion: 99, layers: [{ id: 'a', type: 'pink', gain: 0.5 }] }],
    [
      'bilinmeyen gürültü türü',
      { schemaVersion: 1, layers: [{ id: 'a', type: 'green', gain: 0.5 }] },
    ],
    ['gain > 1', { schemaVersion: 1, layers: [{ id: 'a', type: 'pink', gain: 1.5 }] }],
    ['gain negatif', { schemaVersion: 1, layers: [{ id: 'a', type: 'pink', gain: -0.1 }] }],
    ['gain sayı değil', { schemaVersion: 1, layers: [{ id: 'a', type: 'pink', gain: 'yüksek' }] }],
    [
      'tekrarlı katman id',
      {
        schemaVersion: 1,
        layers: [
          { id: 'a', type: 'pink', gain: 0.5 },
          { id: 'a', type: 'brown', gain: 0.5 },
        ],
      },
    ],
    ['katman yok', { schemaVersion: 1, layers: [] }],
  ])("BOZUK tarif DB'ye giremez: %s → 400", async (_ad, body) => {
    const slug = `${prefix}-bad-${Math.random().toString(36).slice(2, 8)}`;
    await seed(slug);
    await setRecipe(await tokenFor(['editor']), slug, body).expect(400);

    // 400 döndü ama yazdıysa facia — kullanıcının telefonunda patlardı.
    const row = await prisma.soundscapes.findUnique({ where: { slug } });
    expect(row?.engine_params).toEqual({});
  });

  it('9 katman reddedilir (CPU/headroom sınırı 8)', async () => {
    const slug = `${prefix}-toomany`;
    await seed(slug);
    const layers = Array.from({ length: 9 }, (_, i) => ({ id: `l${i}`, type: 'pink', gain: 0.1 }));
    await setRecipe(await tokenFor(['editor']), slug, { schemaVersion: 1, layers }).expect(400);
  });

  it('FAZLADAN alanlar elenir — doğrulanmış hâl yazılır, ham girdi değil', async () => {
    const slug = `${prefix}-extra`;
    await seed(slug);
    await setRecipe(await tokenFor(['editor']), slug, {
      schemaVersion: 1,
      layers: [{ id: 'base', type: 'pink', gain: 0.5, sahteAlan: 'atılmalı' }],
    }).expect(200);

    const row = await prisma.soundscapes.findUnique({ where: { slug } });
    expect(row?.engine_params).toEqual(VALID);
  });

  it('analyst tarif yazamaz → 403', async () => {
    const slug = `${prefix}-analyst`;
    await seed(slug);
    await setRecipe(await tokenFor(['analyst']), slug, VALID).expect(403);
  });

  it('olmayan slug → 404', async () => {
    await setRecipe(await tokenFor(['editor']), `${prefix}-yok`, VALID).expect(404);
  });
});
