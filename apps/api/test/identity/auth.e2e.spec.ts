import 'reflect-metadata';
import { ValidationPipe, type INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { AppModule } from '../../src/app.module';

/**
 * Uçtan uca HTTP kanıtı (docker'sız — in-memory repo). Kickoff çıkış kriteri:
 * "anonim kayıt → token → yetkili istek" zinciri (docs/09 Adım 4/6).
 */
describe('Auth e2e (HTTP)', () => {
  let app: INestApplication;

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

  it('GET /health → 200', async () => {
    const res = await request(app.getHttpServer()).get('/health').expect(200);
    expect(res.body.status).toBe('ok');
  });

  it('anonim kayıt → token → yetkili /v1/auth/me zinciri', async () => {
    // Gerçek DB'ye yazılıyor → benzersiz fingerprint (tekrarlı koşumda çakışma yok).
    const fingerprint = `e2e-device-${Date.now()}`;
    const reg = await request(app.getHttpServer())
      .post('/v1/auth/device')
      .send({ fingerprint, platform: 'ios' })
      .expect(201);

    expect(reg.body.accessToken).toBeTruthy();
    const { accessToken, userId } = reg.body;

    // Token'sız istek reddedilir.
    await request(app.getHttpServer()).get('/v1/auth/me').expect(401);

    // Token'lı istek kendi kimliğini döndürür.
    const me = await request(app.getHttpServer())
      .get('/v1/auth/me')
      .set('Authorization', `Bearer ${accessToken}`)
      .expect(200);
    expect(me.body.userId).toBe(userId);
  });

  it('geçersiz payload 400 (whitelist + validation)', async () => {
    await request(app.getHttpServer())
      .post('/v1/auth/device')
      .send({ fingerprint: 'short', platform: 'ios', hacker: true })
      .expect(400);
  });

  describe('GET /v1/auth/sessions', () => {
    it('token olmadan 401', async () => {
      await request(app.getHttpServer()).get('/v1/auth/sessions').expect(401);
    });

    it('kayıt sonrası aktif oturumu listeler (token dışa verilmez)', async () => {
      const reg = await request(app.getHttpServer())
        .post('/v1/auth/device')
        .send({
          fingerprint: `sessions-e2e-${Date.now()}-${Math.round(process.hrtime()[1])}`,
          platform: 'ios',
        })
        .expect(201);

      const res = await request(app.getHttpServer())
        .get('/v1/auth/sessions')
        .set('Authorization', `Bearer ${reg.body.accessToken}`)
        .expect(200);
      expect(res.body.length).toBeGreaterThanOrEqual(1);
      expect(res.body[0].familyId).toBeTruthy();
      expect(res.body[0].createdAt).toBeTruthy();
      // ham token/hash sızmaz
      expect(JSON.stringify(res.body)).not.toContain(reg.body.refreshToken);
    });
  });

  describe('POST /v1/auth/sessions/revoke-others', () => {
    it('token olmadan 401', async () => {
      await request(app.getHttpServer())
        .post('/v1/auth/sessions/revoke-others')
        .send({ refreshToken: 'x'.repeat(20) })
        .expect(401);
    });

    it('geçerli oturumda diğer oturum yoksa → 200 revoked:0', async () => {
      const reg = await request(app.getHttpServer())
        .post('/v1/auth/device')
        .send({
          fingerprint: `revoke-e2e-${Date.now()}-${Math.round(process.hrtime()[1])}`,
          platform: 'ios',
        })
        .expect(201);
      const { accessToken, refreshToken } = reg.body;

      const res = await request(app.getHttpServer())
        .post('/v1/auth/sessions/revoke-others')
        .set('Authorization', `Bearer ${accessToken}`)
        .send({ refreshToken })
        .expect(200);
      expect(res.body.revoked).toBe(0);
    });

    it('geçersiz refresh token → 401', async () => {
      const reg = await request(app.getHttpServer())
        .post('/v1/auth/device')
        .send({
          fingerprint: `revoke-bad-${Date.now()}-${Math.round(process.hrtime()[1])}`,
          platform: 'ios',
        })
        .expect(201);
      await request(app.getHttpServer())
        .post('/v1/auth/sessions/revoke-others')
        .set('Authorization', `Bearer ${reg.body.accessToken}`)
        .send({ refreshToken: 'invalid-token-not-real-xxxxx' })
        .expect(401);
    });
  });
});
