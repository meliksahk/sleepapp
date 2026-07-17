import 'reflect-metadata';
import { ValidationPipe, type INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';

import { AppModule } from '../../src/app.module';

/**
 * entitlement modülü uçtan uca (gerçek DB). `GET /v1/me/entitlement` — AuthGuard
 * identity'den; scope = token sub. Bugün stub premium döner (docs/02 B1).
 */
describe('Entitlement e2e (HTTP)', () => {
  let app: INestApplication;

  const registerAndToken = async (): Promise<string> => {
    const res = await request(app.getHttpServer())
      .post('/v1/auth/device')
      .send({
        fingerprint: `ent-e2e-${Date.now()}-${Math.round(process.hrtime()[1])}`,
        platform: 'ios',
      })
      .expect(201);
    return res.body.accessToken;
  };

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

  it('token olmadan 401 (premium durumu korumalı)', async () => {
    await request(app.getHttpServer()).get('/v1/me/entitlement').expect(401);
  });

  it('ÇEKİRDEK: kimliği doğrulanmış kullanıcı premium döner (dev stub)', async () => {
    const token = await registerAndToken();
    const res = await request(app.getHttpServer())
      .get('/v1/me/entitlement')
      .set('Authorization', `Bearer ${token}`)
      .expect(200);
    // Stub herkese premium verir; premium bayrağı tier'dan TÜRETİLİR.
    expect(res.body).toEqual({ tier: 'plus', premium: true });
  });
});
