import 'reflect-metadata';
import { ValidationPipe, type INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { AppModule } from '../../src/app.module';

/** sharing e2e (gerçek DB) — archetype sonucundan paylaşım kartı. Cross-module. */
describe('Sharing e2e (HTTP)', () => {
  let app: INestApplication;

  const token = async (): Promise<string> => {
    const res = await request(app.getHttpServer())
      .post('/v1/auth/device')
      .send({
        fingerprint: `share-e2e-${Date.now()}-${Math.round(process.hrtime()[1])}`,
        platform: 'ios',
      })
      .expect(201);
    return res.body.accessToken;
  };

  const allB = { q1: 'q1b', q2: 'q2b', q3: 'q3b', q4: 'q4b', q5: 'q5b', q6: 'q6b' };

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

  it('token olmadan 401', async () => {
    await request(app.getHttpServer()).get('/v1/sharing/archetype').expect(401);
  });

  it('sonuç yokken → 404 no_result', async () => {
    const t = await token();
    const res = await request(app.getHttpServer())
      .get('/v1/sharing/archetype')
      .set('Authorization', `Bearer ${t}`)
      .expect(404);
    expect(res.body.code).toBe('no_result');
  });

  it('archetype testi sonrası → paylaşım kartı (web + deep link)', async () => {
    const t = await token();
    const submit = await request(app.getHttpServer())
      .post('/v1/archetype/answers')
      .set('Authorization', `Bearer ${t}`)
      .send({ version: 1, answers: allB })
      .expect(201);
    const slug = submit.body.archetypeSlug;

    const res = await request(app.getHttpServer())
      .get('/v1/sharing/archetype')
      .set('Authorization', `Bearer ${t}`)
      .expect(200);

    expect(res.body.archetypeSlug).toBe(slug);
    expect(res.body.webUrl).toContain(`/a/${slug}`);
    expect(res.body.deepLink).toBe(`nocta://a/${slug}`);
    expect(res.body.title).toContain('sleep identity');
  });
});
