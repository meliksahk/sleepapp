import 'reflect-metadata';
import { ValidationPipe, type INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { AppModule } from '../../src/app.module';
import { ProblemDetailsFilter } from '../../src/shared/http/problem-details.filter';

/** RFC 7807 problem+json hata sözleşmesi (docs/02 §4). */
describe('ProblemDetails filter e2e', () => {
  let app: INestApplication;

  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({ imports: [AppModule] }).compile();
    app = moduleRef.createNestApplication();
    app.setGlobalPrefix('v1', { exclude: ['health'] });
    app.useGlobalPipes(
      new ValidationPipe({ whitelist: true, forbidNonWhitelisted: true, transform: true }),
    );
    app.useGlobalFilters(new ProblemDetailsFilter());
    await app.init();
  });

  afterAll(async () => {
    await app.close();
  });

  it('401 → application/problem+json gövdesi', async () => {
    const res = await request(app.getHttpServer()).get('/v1/auth/me').expect(401);
    expect(res.headers['content-type']).toContain('application/problem+json');
    expect(res.body).toMatchObject({ type: 'about:blank', title: 'Unauthorized', status: 401 });
  });

  it('400 validasyon → title Bad Request + detail', async () => {
    const res = await request(app.getHttpServer())
      .post('/v1/auth/device')
      .send({ fingerprint: 'short', platform: 'ios' })
      .expect(400);
    expect(res.body.title).toBe('Bad Request');
    expect(res.body.detail).toBeTruthy();
  });

  it('domain hata kodu korunur (refresh reuse → code)', async () => {
    const reg = await request(app.getHttpServer())
      .post('/v1/auth/device')
      .send({ fingerprint: `pd-${Date.now()}-${Math.round(process.hrtime()[1])}`, platform: 'ios' })
      .expect(201);
    const oldRefresh = reg.body.refreshToken;
    await request(app.getHttpServer())
      .post('/v1/auth/refresh')
      .send({ refreshToken: oldRefresh })
      .expect(200);
    const res = await request(app.getHttpServer())
      .post('/v1/auth/refresh')
      .send({ refreshToken: oldRefresh })
      .expect(401);
    expect(res.body.code).toBe('refresh_token_reuse');
  });
});
