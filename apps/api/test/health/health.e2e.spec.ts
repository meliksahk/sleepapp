import 'reflect-metadata';
import { type INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { AppModule } from '../../src/app.module';

/** Health uçları (gerçek DB). Liveness prefix'siz, readiness DB kontrol eder. */
describe('Health e2e (HTTP)', () => {
  let app: INestApplication;

  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({ imports: [AppModule] }).compile();
    app = moduleRef.createNestApplication();
    app.setGlobalPrefix('v1', { exclude: ['health'] });
    await app.init();
  });

  afterAll(async () => {
    await app.close();
  });

  it("GET /health (liveness, prefix'siz) → 200 ok", async () => {
    const res = await request(app.getHttpServer()).get('/health').expect(200);
    expect(res.body.status).toBe('ok');
  });

  it('GET /v1/health/ready (readiness) → 200 db up', async () => {
    const res = await request(app.getHttpServer()).get('/v1/health/ready').expect(200);
    expect(res.body).toEqual({ status: 'ok', db: 'up' });
  });
});
