import 'reflect-metadata';
import { ValidationPipe, type INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { PrismaClient } from '@prisma/client';
import { AppModule } from '../../src/app.module';

/** content e2e (gerçek DB). Soundscape'ler prisma ile seed edilir. */
describe('Content e2e (HTTP)', () => {
  let app: INestApplication;
  const prisma = new PrismaClient();
  const prefix = `c${Date.now()}`;
  const slugs = {
    over: `${prefix}-pub-over`,
    deep: `${prefix}-pub-deep`,
    draft: `${prefix}-draft`,
  };

  const token = async (): Promise<string> => {
    const res = await request(app.getHttpServer())
      .post('/v1/auth/device')
      .send({
        fingerprint: `content-e2e-${Date.now()}-${Math.round(process.hrtime()[1])}`,
        platform: 'ios',
      })
      .expect(201);
    return res.body.accessToken;
  };

  beforeAll(async () => {
    await prisma.$connect();
    const base = { title_i18n: { en: 'X' }, engine_params: {}, layer_defs: {} };
    const over = await prisma.soundscapes.create({
      data: {
        ...base,
        slug: slugs.over,
        archetype_affinity: ['overthinker'],
        status: 'published',
        preview_asset_key: 'previews/over.opus',
      },
    });
    await prisma.soundscapes.create({
      data: { ...base, slug: slugs.deep, archetype_affinity: ['deep-ocean'], status: 'published' },
    });
    await prisma.soundscapes.create({
      data: { ...base, slug: slugs.draft, archetype_affinity: ['overthinker'], status: 'draft' },
    });
    await prisma.presets.create({
      data: { soundscape_id: over.id, archetype_slug: 'overthinker', mixer_state: { rain: 0.7 } },
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
    await prisma.soundscapes.deleteMany({ where: { slug: { in: Object.values(slugs) } } });
    await prisma.$disconnect();
    await app.close();
  });

  it('token olmadan 401', async () => {
    await request(app.getHttpServer()).get('/v1/content/feed').expect(401);
  });

  it('feed yalnızca yayınlanmışları döner, affinity sıralı', async () => {
    const t = await token();
    const res = await request(app.getHttpServer())
      .get('/v1/content/feed?archetype=overthinker')
      .set('Authorization', `Bearer ${t}`)
      .expect(200);
    const mine = res.body.filter((x: { slug: string }) => x.slug.startsWith(prefix));
    const mineSlugs = mine.map((x: { slug: string }) => x.slug);
    expect(mineSlugs).toContain(slugs.over);
    expect(mineSlugs).toContain(slugs.deep);
    expect(mineSlugs).not.toContain(slugs.draft); // draft servis edilmez
    // overthinker affinity'li olan deep'ten önce
    expect(mineSlugs.indexOf(slugs.over)).toBeLessThan(mineSlugs.indexOf(slugs.deep));
  });

  it('yayınlanmış soundscape detay + preset', async () => {
    const t = await token();
    const res = await request(app.getHttpServer())
      .get(`/v1/content/soundscapes/${slugs.over}`)
      .set('Authorization', `Bearer ${t}`)
      .expect(200);
    expect(res.body.soundscape.slug).toBe(slugs.over);
    expect(res.body.presets).toHaveLength(1);
    expect(res.body.presets[0].archetypeSlug).toBe('overthinker');
    // preview_asset_key → presigned URL (offline üretim): anahtar + imza içerir
    expect(typeof res.body.previewUrl).toBe('string');
    expect(res.body.previewUrl).toContain('previews/over.opus');
    expect(res.body.previewUrl).toMatch(/X-Amz-Signature=/);
  });

  it('preview_asset_key olmayan soundscape → previewUrl null', async () => {
    const t = await token();
    const res = await request(app.getHttpServer())
      .get(`/v1/content/soundscapes/${slugs.deep}`)
      .set('Authorization', `Bearer ${t}`)
      .expect(200);
    expect(res.body.previewUrl).toBeNull();
  });

  it('draft (yayınlanmamış) slug → 404', async () => {
    const t = await token();
    await request(app.getHttpServer())
      .get(`/v1/content/soundscapes/${slugs.draft}`)
      .set('Authorization', `Bearer ${t}`)
      .expect(404);
  });
});
