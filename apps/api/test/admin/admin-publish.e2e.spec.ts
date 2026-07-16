import 'reflect-metadata';
import { ValidationPipe, type INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { PrismaClient } from '@prisma/client';
import { AppModule } from '../../src/app.module';

/**
 * Yayınlama e2e (gerçek DB).
 *
 * ÇEKİRDEK İDDİA: SES TARİFİ BOŞ OLAN KAYIT YAYINLANAMAZ. Feed `engineParams`'ı
 * uygulamaya taşır ve ses on-device o tariften üretilir → boş tarifle yayınlamak,
 * kütüphanede görünen ama SES ÇIKARMAYAN bir kayıt demektir. Bu kapı, "taslak boş
 * doğar" kararını (#120) güvenli kılan şeydir.
 */
describe('Admin yayınlama e2e (HTTP)', () => {
  let app: INestApplication;
  const prisma = new PrismaClient();
  const prefix = `pub${Date.now()}`;
  const createdUsers: string[] = [];

  const tokenFor = async (roles: string[]): Promise<string> => {
    const reg = await request(app.getHttpServer())
      .post('/v1/auth/device')
      .send({
        fingerprint: `pub-${Date.now()}-${Math.round(process.hrtime()[1])}`,
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

  /** Kayıt oluşturur; `recipe` verilmezse ses tarifi BOŞ kalır (taslağın doğduğu hâl). */
  const seed = async (
    slug: string,
    opts?: { recipe?: boolean; status?: string },
  ): Promise<void> => {
    await prisma.soundscapes.create({
      data: {
        slug,
        title_i18n: { en: slug },
        engine_params: opts?.recipe ? { noise: 'pink', gain: 0.4 } : {},
        layer_defs: [],
        status: (opts?.status ?? 'draft') as 'draft' | 'scheduled' | 'published',
      },
    });
  };

  const publish = (token: string, slug: string) =>
    request(app.getHttpServer())
      .post(`/v1/admin/soundscapes/${slug}/publish`)
      .set('Authorization', `Bearer ${token}`);

  const unpublish = (token: string, slug: string) =>
    request(app.getHttpServer())
      .post(`/v1/admin/soundscapes/${slug}/unpublish`)
      .set('Authorization', `Bearer ${token}`);

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

  it('ÇEKİRDEK İDDİA: BOŞ ses tarifi yayınlanamaz → 409, kayıt TASLAK kalır', async () => {
    const slug = `${prefix}-empty`;
    await seed(slug);
    const res = await publish(await tokenFor(['editor']), slug).expect(409);
    expect(res.body.code).toBe('empty_recipe');

    // 409 döndü ama yazdıysa facia — DB'den doğrula.
    const row = await prisma.soundscapes.findUnique({ where: { slug } });
    expect(row?.status).toBe('draft');
  });

  it('tarifi olan taslak yayınlanır → 200, durum PUBLISHED', async () => {
    const slug = `${prefix}-ok`;
    await seed(slug, { recipe: true });
    const res = await publish(await tokenFor(['editor']), slug).expect(200);
    expect(res.body.status).toBe('published');

    const row = await prisma.soundscapes.findUnique({ where: { slug } });
    expect(row?.status).toBe('published');
  });

  it("yayınlanan kayıt UYGULAMANIN feed'inde görünür (uçtan uca anlam)", async () => {
    const slug = `${prefix}-feed`;
    await seed(slug, { recipe: true });
    await publish(await tokenFor(['editor']), slug).expect(200);

    // Yayınlamanın ANLAMI bu: kullanıcı görebilsin. Yalnızca DB'deki enum değil.
    const device = await request(app.getHttpServer())
      .post('/v1/auth/device')
      .send({ fingerprint: `feed-${Date.now()}`, platform: 'ios' })
      .expect(201);
    createdUsers.push(device.body.userId);

    const feed = await request(app.getHttpServer())
      .get('/v1/content/feed')
      .set('Authorization', `Bearer ${device.body.accessToken}`)
      .expect(200);
    expect(feed.body.some((s: { slug: string }) => s.slug === slug)).toBe(true);
  });

  it("yayından kaldırma feed'den DÜŞÜRÜR (kapı yok: geri çekmek daima güvenli)", async () => {
    const slug = `${prefix}-pull`;
    await seed(slug, { recipe: true, status: 'published' });
    const res = await unpublish(await tokenFor(['editor']), slug).expect(200);
    expect(res.body.status).toBe('draft');

    const row = await prisma.soundscapes.findUnique({ where: { slug } });
    expect(row?.status).toBe('draft');
  });

  it('🔴 ACİL GERİ ÇEKME: geri çekilen içerik feed’den ANINDA düşer (cache tutmaz)', async () => {
    // Bu testin sebebi CANLI ÖLÇÜM: feed archetype başına 5dk cache'leniyor ve durum
    // değişimi cache'i temizlemiyordu → "yanlış içerik canlıda" durumunda geri çekme
    // 5 DAKİKA boyunca işe yaramıyordu. Kod "geri çekmek daima güvenli" diyordu;
    // gerçek tersiydi. Kritik ayrıntı: cache'i ÖNCE ISITMAK — asıl senaryo bu,
    // kullanıcılar zaten geziniyor.
    const slug = `${prefix}-cache`;
    await seed(slug, { recipe: true, status: 'published' });

    const device = await request(app.getHttpServer())
      .post('/v1/auth/device')
      .send({ fingerprint: `cache-${Date.now()}`, platform: 'ios' })
      .expect(201);
    createdUsers.push(device.body.userId);
    const feedNow = () =>
      request(app.getHttpServer())
        .get('/v1/content/feed')
        .set('Authorization', `Bearer ${device.body.accessToken}`)
        .expect(200);

    const before = await feedNow();
    expect(before.body.some((s: { slug: string }) => s.slug === slug)).toBe(true);

    await unpublish(await tokenFor(['editor']), slug).expect(200);

    const after = await feedNow();
    expect(after.body.some((s: { slug: string }) => s.slug === slug)).toBe(false);
  });

  it('yayınlama da ANINDA görünür (ısıtılmış cache yeni içeriği saklamaz)', async () => {
    const slug = `${prefix}-warm`;
    await seed(slug, { recipe: true });

    const device = await request(app.getHttpServer())
      .post('/v1/auth/device')
      .send({ fingerprint: `warm-${Date.now()}`, platform: 'ios' })
      .expect(201);
    createdUsers.push(device.body.userId);
    const feedNow = () =>
      request(app.getHttpServer())
        .get('/v1/content/feed')
        .set('Authorization', `Bearer ${device.body.accessToken}`)
        .expect(200);

    await feedNow(); // cache ısındı: yeni kayıt HENÜZ yok
    await publish(await tokenFor(['editor']), slug).expect(200);

    const after = await feedNow();
    expect(after.body.some((s: { slug: string }) => s.slug === slug)).toBe(true);
  });

  it('BOŞ tarifli kayıt bile yayından KALDIRILABİLİR (acil çekme koşula takılmaz)', async () => {
    // Boş tarifli bir kayıt bir şekilde yayına düştüyse (elle DB müdahalesi vb.),
    // onu geri çekmek "önce tarifi doldur" koşuluna takılmamalı.
    const slug = `${prefix}-emergency`;
    await seed(slug, { status: 'published' });
    await unpublish(await tokenFor(['owner']), slug).expect(200);
  });

  it('analyst yayınlayamaz → 403 (salt okunur rol)', async () => {
    const slug = `${prefix}-analyst`;
    await seed(slug, { recipe: true });
    await publish(await tokenFor(['analyst']), slug).expect(403);

    const row = await prisma.soundscapes.findUnique({ where: { slug } });
    expect(row?.status).toBe('draft');
  });

  it('analyst yayından kaldıramaz → 403', async () => {
    const slug = `${prefix}-analyst-un`;
    await seed(slug, { recipe: true, status: 'published' });
    await unpublish(await tokenFor(['analyst']), slug).expect(403);
  });

  it('olmayan slug → 404', async () => {
    await publish(await tokenFor(['editor']), `${prefix}-yok`).expect(404);
  });

  it('token yok → 401', async () => {
    await request(app.getHttpServer())
      .post(`/v1/admin/soundscapes/${prefix}-x/publish`)
      .expect(401);
  });

  it('yayınlama IDEMPOTENT: iki kez → yine published', async () => {
    const slug = `${prefix}-twice`;
    await seed(slug, { recipe: true });
    const token = await tokenFor(['editor']);
    await publish(token, slug).expect(200);
    const res = await publish(token, slug).expect(200);
    expect(res.body.status).toBe('published');
  });
});
