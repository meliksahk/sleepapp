import 'reflect-metadata';
import { type INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { AppModule } from '../../src/app.module';

/** x-request-id correlation header (docs/07). Middleware AppModule'den uygulanır. */
describe('RequestId middleware e2e', () => {
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

  it('x-request-id header üretir', async () => {
    const res = await request(app.getHttpServer()).get('/health').expect(200);
    expect(res.headers['x-request-id']).toBeTruthy();
  });

  it('verilen x-request-id echo edilir', async () => {
    const id = 'corr-12345';
    const res = await request(app.getHttpServer())
      .get('/health')
      .set('x-request-id', id)
      .expect(200);
    expect(res.headers['x-request-id']).toBe(id);
  });

  it('guard reddinde (401) bile x-request-id bulunur', async () => {
    const res = await request(app.getHttpServer()).get('/v1/auth/me').expect(401);
    expect(res.headers['x-request-id']).toBeTruthy();
  });
});
