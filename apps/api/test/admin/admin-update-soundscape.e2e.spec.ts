import 'reflect-metadata';
import { ValidationPipe, type INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { PrismaClient } from '@prisma/client';
import { AppModule } from '../../src/app.module';

/**
 * Başlık/affinity güncelleme e2e (gerçek DB).
 *
 * NEDEN: tarif düzenlenebiliyordu (#124) ama BAŞLIK düzeltilemiyordu — yazım hatası
 * olan bir kayıt kütüphanede öylece duruyordu.
 */
describe('Admin soundscape güncelleme e2e (HTTP)', () => {
  let app: INestApplication;
  const prisma = new PrismaClient();
  const prefix = `upd${Date.now()}`;
  const createdUsers: string[] = [];

  const tokenFor = async (roles: string[]): Promise<string> => {
    const reg = await request(app.getHttpServer())
      .post('/v1/auth/device')
      .send({
        fingerprint: `upd-${Date.now()}-${Math.round(process.hrtime()[1])}`,
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

  const seed = async (
    slug: string,
    opts?: { title?: Record<string, string>; affinity?: string[]; status?: string },
  ): Promise<void> => {
    await prisma.soundscapes.create({
      data: {
        slug,
        title_i18n: opts?.title ?? { en: 'Original' },
        engine_params: { schemaVersion: 1, layers: [{ id: 'base', type: 'pink', gain: 0.5 }] },
        layer_defs: [],
        archetype_affinity: opts?.affinity ?? [],
        status: (opts?.status ?? 'draft') as 'draft' | 'published',
      },
    });
  };

  const patch = (token: string, slug: string, body: unknown) =>
    request(app.getHttpServer())
      .patch(`/v1/admin/soundscapes/${slug}`)
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

  it('başlık güncellenir → 200', async () => {
    const slug = `${prefix}-title`;
    await seed(slug);
    const res = await patch(await tokenFor(['editor']), slug, { titleEn: 'Düzeltilmiş' }).expect(
      200,
    );
    expect(res.body.title).toBe('Düzeltilmiş');
  });

  it('ÇEKİRDEK: EN düzenlemesi DİĞER DİLLERİ silmez', async () => {
    // `title_i18n` çok dilli bir nesne. Komple yazsaydık, TR başlığı olan bir kaydın
    // EN'ini düzeltmek TR'yi SESSİZCE uçururdu — kimse fark etmezdi.
    const slug = `${prefix}-i18n`;
    await seed(slug, { title: { en: 'English', tr: 'Türkçe' } });
    await patch(await tokenFor(['editor']), slug, { titleEn: 'English v2' }).expect(200);

    const row = await prisma.soundscapes.findUnique({ where: { slug } });
    expect(row?.title_i18n).toEqual({ en: 'English v2', tr: 'Türkçe' });
  });

  it('KISMİ: yalnızca affinity verilince başlığa DOKUNULMAZ', async () => {
    const slug = `${prefix}-partial`;
    await seed(slug, { title: { en: 'Dokunma' } });
    await patch(await tokenFor(['editor']), slug, { archetypeAffinity: ['night-owl'] }).expect(200);

    const row = await prisma.soundscapes.findUnique({ where: { slug } });
    expect(row?.title_i18n).toEqual({ en: 'Dokunma' });
    expect(row?.archetype_affinity).toEqual(['night-owl']);
  });

  it("KISMİ: yalnızca başlık verilince affinity'ye DOKUNULMAZ", async () => {
    const slug = `${prefix}-partial2`;
    await seed(slug, { affinity: ['deep-ocean'] });
    await patch(await tokenFor(['editor']), slug, { titleEn: 'Yeni' }).expect(200);

    const row = await prisma.soundscapes.findUnique({ where: { slug } });
    expect(row?.archetype_affinity).toEqual(['deep-ocean']);
  });

  it('affinity BOŞ dizi ile temizlenebilir (dokunmama ile karışmaz)', async () => {
    const slug = `${prefix}-clear`;
    await seed(slug, { affinity: ['deep-ocean'] });
    await patch(await tokenFor(['editor']), slug, { archetypeAffinity: [] }).expect(200);

    const row = await prisma.soundscapes.findUnique({ where: { slug } });
    expect(row?.archetype_affinity).toEqual([]);
  });

  it('YAYINDAKİ kaydın başlığı değişince feed ANINDA günceller (ısıtılmış cache)', async () => {
    // #122'nin dersi: cache ısıtılmadan test, bayat içerik hatasını gizler.
    const slug = `${prefix}-cache`;
    await seed(slug, { title: { en: 'Eski Başlık' }, status: 'published' });

    const device = await request(app.getHttpServer())
      .post('/v1/auth/device')
      .send({ fingerprint: `upd-cache-${Date.now()}`, platform: 'ios' })
      .expect(201);
    createdUsers.push(device.body.userId);
    const feedTitle = async (): Promise<string | undefined> => {
      const r = await request(app.getHttpServer())
        .get('/v1/content/feed')
        .set('Authorization', `Bearer ${device.body.accessToken}`)
        .expect(200);
      return r.body.find((s: { slug: string }) => s.slug === slug)?.titleI18n?.en;
    };

    expect(await feedTitle()).toBe('Eski Başlık'); // cache ısındı
    await patch(await tokenFor(['editor']), slug, { titleEn: 'Yeni Başlık' }).expect(200);
    expect(await feedTitle()).toBe('Yeni Başlık');
  });

  it('boş başlık reddedilir → 400 (kayıt bozulmaz)', async () => {
    const slug = `${prefix}-empty`;
    await seed(slug, { title: { en: 'Sağlam' } });
    await patch(await tokenFor(['editor']), slug, { titleEn: '' }).expect(400);

    const row = await prisma.soundscapes.findUnique({ where: { slug } });
    expect(row?.title_i18n).toEqual({ en: 'Sağlam' });
  });

  it('yalnızca boşluktan ibaret başlık reddedilir → 400', async () => {
    const slug = `${prefix}-spaces`;
    await seed(slug);
    await patch(await tokenFor(['editor']), slug, { titleEn: '    ' }).expect(400);
  });

  it('SLUG değiştirilemez: gövdedeki slug reddedilir (derin linkler kırılmasın)', async () => {
    const slug = `${prefix}-slug`;
    await seed(slug);
    await patch(await tokenFor(['editor']), slug, { slug: 'yeni-slug' }).expect(400);

    const row = await prisma.soundscapes.findUnique({ where: { slug } });
    expect(row).not.toBeNull();
  });

  it('STATUS gövdeden enjekte edilemez (yayınlama kapısı delinmesin)', async () => {
    const slug = `${prefix}-status`;
    await seed(slug);
    await patch(await tokenFor(['editor']), slug, { status: 'published' }).expect(400);

    const row = await prisma.soundscapes.findUnique({ where: { slug } });
    expect(row?.status).toBe('draft');
  });

  it('analyst güncelleyemez → 403', async () => {
    const slug = `${prefix}-analyst`;
    await seed(slug, { title: { en: 'Korunmalı' } });
    await patch(await tokenFor(['analyst']), slug, { titleEn: 'Hack' }).expect(403);

    const row = await prisma.soundscapes.findUnique({ where: { slug } });
    expect(row?.title_i18n).toEqual({ en: 'Korunmalı' });
  });

  it('olmayan slug → 404', async () => {
    await patch(await tokenFor(['editor']), `${prefix}-yok`, { titleEn: 'X' }).expect(404);
  });
});
