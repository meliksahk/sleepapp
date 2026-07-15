import 'reflect-metadata';
import { ValidationPipe, type INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { AppModule } from '../../src/app.module';

/** Public web archetype testi (docs/05 W0) — kimlik gerektirmez. */
describe('Web archetype e2e (HTTP, public)', () => {
  let app: INestApplication;
  const allA = { q1: 'q1a', q2: 'q2a', q3: 'q3a', q4: 'q4a', q5: 'q5a', q6: 'q6a' };

  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({ imports: [AppModule] }).compile();
    app = moduleRef.createNestApplication();
    app.setGlobalPrefix('v1', { exclude: ['health'] });
    app.useGlobalPipes(
      new ValidationPipe({ whitelist: true, forbidNonWhitelisted: true, transform: true }),
    );
    await app.init();
  });

  afterAll(async () => {
    await app.close();
  });

  it('token OLMADAN skorlar, paylaşım slug üretir; slug ile geri okunur', async () => {
    const scored = await request(app.getHttpServer())
      .post('/v1/archetype/web')
      .send({ version: 1, answers: allA })
      .expect(201);
    expect(scored.body.archetypeSlug).toBe('deep-ocean');
    expect(scored.body.shareSlug).toBeTruthy();
    expect(scored.body.scores['deep-ocean']).toBe(6);

    const slug = scored.body.shareSlug;
    const fetched = await request(app.getHttpServer()).get(`/v1/archetype/web/${slug}`).expect(200);
    expect(fetched.body.shareSlug).toBe(slug);
    expect(fetched.body.archetypeSlug).toBe('deep-ocean');
  });

  it('public GET questions → auth gerektirmez, version 1, 6 soru', async () => {
    const res = await request(app.getHttpServer()).get('/v1/archetype/web/questions').expect(200);
    expect(res.body.version).toBe(1);
    expect(res.body.questions).toHaveLength(6);
  });

  it('bilinmeyen slug → 404', async () => {
    await request(app.getHttpServer()).get('/v1/archetype/web/yok-boyle-slug').expect(404);
  });

  it('eksik cevap → 400', async () => {
    await request(app.getHttpServer())
      .post('/v1/archetype/web')
      .send({ version: 1, answers: { q1: 'q1a' } })
      .expect(400);
  });

  it('her skorlama benzersiz slug üretir', async () => {
    const a = await request(app.getHttpServer())
      .post('/v1/archetype/web')
      .send({ version: 1, answers: allA })
      .expect(201);
    const b = await request(app.getHttpServer())
      .post('/v1/archetype/web')
      .send({ version: 1, answers: allA })
      .expect(201);
    expect(a.body.shareSlug).not.toBe(b.body.shareSlug);
  });
});
