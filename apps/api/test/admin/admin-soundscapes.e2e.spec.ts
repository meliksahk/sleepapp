import 'reflect-metadata';
import { ValidationPipe, type INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { PrismaClient } from '@prisma/client';
import { AppModule } from '../../src/app.module';

/**
 * Admin içerik listesi e2e (gerçek DB).
 *
 * ÇEKİRDEK İDDİA: panel TASLAKLARI görür. Uygulamanın feed'i yalnızca yayınlanmışı
 * görür — editör kaydettiği taslağı panelde göremezse CMS'in anlamı kalmaz.
 */
describe('Admin soundscape listesi e2e (HTTP)', () => {
  let app: INestApplication;
  const prisma = new PrismaClient();
  const prefix = `adm${Date.now()}`;
  const slugs = {
    draft: `${prefix}-draft`,
    scheduled: `${prefix}-scheduled`,
    published: `${prefix}-published`,
  };
  const createdUsers: string[] = [];

  const adminToken = async (): Promise<string> => {
    const reg = await request(app.getHttpServer())
      .post('/v1/auth/device')
      .send({
        fingerprint: `adm-ss-${Date.now()}-${Math.round(process.hrtime()[1])}`,
        platform: 'ios',
      })
      .expect(201);
    createdUsers.push(reg.body.userId);
    await prisma.users.update({
      where: { id: reg.body.userId },
      data: { kind: 'admin', roles: ['owner'] },
    });
    const refreshed = await request(app.getHttpServer())
      .post('/v1/auth/refresh')
      .send({ refreshToken: reg.body.refreshToken })
      .expect(200);
    return refreshed.body.accessToken;
  };

  const deviceToken = async (): Promise<string> => {
    const reg = await request(app.getHttpServer())
      .post('/v1/auth/device')
      .send({
        fingerprint: `dev-ss-${Date.now()}-${Math.round(process.hrtime()[1])}`,
        platform: 'ios',
      })
      .expect(201);
    createdUsers.push(reg.body.userId);
    return reg.body.accessToken;
  };

  const list = (token: string) =>
    request(app.getHttpServer())
      .get('/v1/admin/soundscapes')
      .set('Authorization', `Bearer ${token}`);

  beforeAll(async () => {
    await prisma.$connect();
    await prisma.soundscapes.createMany({
      data: [
        {
          slug: slugs.draft,
          status: 'draft',
          title_i18n: { en: 'Draft One' },
          engine_params: {},
          layer_defs: [],
          archetype_affinity: ['deep-ocean'],
        },
        {
          slug: slugs.scheduled,
          status: 'scheduled',
          title_i18n: { en: 'Scheduled One' },
          engine_params: {},
          layer_defs: [],
        },
        // title_i18n'de EN YOK: başlık slug'a düşmeli (panelde boş hücre olmasın).
        {
          slug: slugs.published,
          status: 'published',
          title_i18n: { tr: 'Yayında' },
          engine_params: {},
          layer_defs: [],
        },
      ],
    });

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

  it('token yok → 401', async () => {
    await request(app.getHttpServer()).get('/v1/admin/soundscapes').expect(401);
  });

  it('mobil (cihaz) token → 403 (panel oturumu değil)', async () => {
    await list(await deviceToken()).expect(403);
  });

  it('ÇEKİRDEK İDDİA: panel TASLAK ve PLANLI kayıtları da görür', async () => {
    const res = await list(await adminToken()).expect(200);
    const mine = res.body.filter((s: { slug: string }) => s.slug.startsWith(prefix));
    const bySlug = Object.fromEntries(mine.map((s: { slug: string }) => [s.slug, s]));

    expect(Object.keys(bySlug).sort()).toEqual(
      [slugs.draft, slugs.published, slugs.scheduled].sort(),
    );
    expect(bySlug[slugs.draft].status).toBe('draft');
    expect(bySlug[slugs.scheduled].status).toBe('scheduled');
  });

  it("EN başlık yoksa slug'a düşer (panelde boş hücre olmaz)", async () => {
    const res = await list(await adminToken()).expect(200);
    const published = res.body.find((s: { slug: string }) => s.slug === slugs.published);
    expect(published.title).toBe(slugs.published);
  });

  it('affinity ve version taşınır, createdAt ISO 8601 (CLAUDE.md §4)', async () => {
    const res = await list(await adminToken()).expect(200);
    const draft = res.body.find((s: { slug: string }) => s.slug === slugs.draft);
    expect(draft.archetypeAffinity).toEqual(['deep-ocean']);
    expect(typeof draft.version).toBe('number');
    expect(draft.createdAt).toMatch(/^\d{4}-\d{2}-\d{2}T.*Z$/);
  });

  it('ağır alanlar (engineParams/layerDefs) listede TAŞINMAZ', async () => {
    // Liste 100 satır olabilir; ses tarifini her satırda göndermek gereksiz yük.
    const res = await list(await adminToken()).expect(200);
    const draft = res.body.find((s: { slug: string }) => s.slug === slugs.draft);
    expect(draft.engineParams).toBeUndefined();
    expect(draft.layerDefs).toBeUndefined();
  });
});
