import 'reflect-metadata';
import { ValidationPipe, type INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';

import { AppModule } from '../../src/app.module';

/**
 * privacy modülü uçtan uca (gerçek DB). `GET /v1/me/export` — GDPR taşınabilirliği
 * (D-7). AuthGuard identity'den; scope = token sub.
 */
describe('Privacy export e2e (HTTP)', () => {
  let app: INestApplication;

  const registerAndToken = async (): Promise<string> => {
    const res = await request(app.getHttpServer())
      .post('/v1/auth/device')
      .send({
        fingerprint: `priv-e2e-${Date.now()}-${Math.round(process.hrtime()[1])}`,
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

  it('token olmadan 401 (kişisel veri korunmalı)', async () => {
    await request(app.getHttpServer()).get('/v1/me/export').expect(401);
  });

  it('ÇEKİRDEK: kullanıcı kendi verisini indirilebilir JSON olarak alır', async () => {
    const token = await registerAndToken();
    const res = await request(app.getHttpServer())
      .get('/v1/me/export')
      .set('Authorization', `Bearer ${token}`)
      .expect(200);

    // Tüm bölümler mevcut ve doğru tipte.
    expect(typeof res.body.exportedAt).toBe('string');
    expect(res.body).toHaveProperty('profile');
    expect(Array.isArray(res.body.archetypeResults)).toBe(true);
    expect(Array.isArray(res.body.sleepSessions)).toBe(true);
    expect(Array.isArray(res.body.account.sessions)).toBe(true);
    // "İndir" davranışı: dosya olarak iner, sayfada açılmaz.
    expect(res.headers['content-disposition']).toContain('attachment');
    expect(res.headers['content-disposition']).toContain('nocta-data-export.json');
  });

  it("ÇEKİRDEK izolasyon: A, B'nin verisini export EDEMEZ", async () => {
    const aToken = await registerAndToken();
    const bToken = await registerAndToken();

    // A kendi profiline bir ad yazar.
    await request(app.getHttpServer())
      .patch('/v1/profile')
      .set('Authorization', `Bearer ${aToken}`)
      .send({ displayName: 'A-gizli' })
      .expect(200);

    // B'nin export'u A'nın adını İÇERMEZ.
    const bExport = await request(app.getHttpServer())
      .get('/v1/me/export')
      .set('Authorization', `Bearer ${bToken}`)
      .expect(200);
    expect(JSON.stringify(bExport.body)).not.toContain('A-gizli');
    expect(bExport.body.profile.displayName).toBeNull();

    // A'nın export'u kendi adını İÇERİR (export gerçekten veriyi topluyor).
    const aExport = await request(app.getHttpServer())
      .get('/v1/me/export')
      .set('Authorization', `Bearer ${aToken}`)
      .expect(200);
    expect(aExport.body.profile.displayName).toBe('A-gizli');
  });
});
