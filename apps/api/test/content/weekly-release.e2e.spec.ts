import 'reflect-metadata';
import { type INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { PrismaClient } from '@prisma/client';
import { AppModule } from '../../src/app.module';

/** Haftalık yayın e2e (gerçek DB). Far-future week_start ile 'en güncel' garanti. */
describe('Weekly release e2e (HTTP)', () => {
  let app: INestApplication;
  const prisma = new PrismaClient();
  const slug = `weekly-${Date.now()}`;
  const weekStart = new Date('2099-12-31');
  let soundscapeId = '';

  const token = async (): Promise<string> => {
    const res = await request(app.getHttpServer())
      .post('/v1/auth/device')
      .send({ fingerprint: `wk-${Date.now()}-${Math.round(process.hrtime()[1])}`, platform: 'ios' })
      .expect(201);
    return res.body.accessToken;
  };

  beforeAll(async () => {
    await prisma.$connect();
    // Re-run güvenliği: aynı far-future week_start varsa temizle.
    await prisma.weekly_releases.deleteMany({ where: { week_start: weekStart } });
    const s = await prisma.soundscapes.create({
      data: {
        slug,
        title_i18n: { en: 'Weekly' },
        engine_params: {},
        layer_defs: {},
        archetype_affinity: [],
        status: 'published',
      },
    });
    soundscapeId = s.id;
    await prisma.weekly_releases.create({
      data: { week_start: weekStart, soundscape_ids: [s.id], notes: 'test week' },
    });

    const moduleRef = await Test.createTestingModule({ imports: [AppModule] }).compile();
    app = moduleRef.createNestApplication();
    app.setGlobalPrefix('v1', { exclude: ['health'] });
    await app.init();
  });

  afterAll(async () => {
    await prisma.weekly_releases.deleteMany({ where: { week_start: weekStart } });
    await prisma.soundscapes.deleteMany({ where: { id: soundscapeId } });
    await prisma.$disconnect();
    await app.close();
  });

  it('token olmadan 401', async () => {
    await request(app.getHttpServer()).get('/v1/content/weekly').expect(401);
  });

  it('en güncel haftalık yayını döner (soundscape çözülmüş)', async () => {
    const t = await token();
    const res = await request(app.getHttpServer())
      .get('/v1/content/weekly')
      .set('Authorization', `Bearer ${t}`)
      .expect(200);
    expect(res.body.weekStart).toBe('2099-12-31');
    expect(res.body.notes).toBe('test week');
    const slugs = (res.body.soundscapes as Array<{ slug: string }>).map((x) => x.slug);
    expect(slugs).toContain(slug);
  });
});
