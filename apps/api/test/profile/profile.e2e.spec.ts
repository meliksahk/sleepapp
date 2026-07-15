import 'reflect-metadata';
import { ValidationPipe, type INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { AppModule } from '../../src/app.module';

/** profile modülü uçtan uca (gerçek DB). AuthGuard identity'den; scope = token sub. */
describe('Profile e2e (HTTP)', () => {
  let app: INestApplication;

  const registerAndToken = async (): Promise<{ token: string; userId: string }> => {
    const res = await request(app.getHttpServer())
      .post('/v1/auth/device')
      .send({
        fingerprint: `profile-e2e-${Date.now()}-${Math.round(process.hrtime()[1])}`,
        platform: 'ios',
      })
      .expect(201);
    return { token: res.body.accessToken, userId: res.body.userId };
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

  it('token olmadan 401', async () => {
    await request(app.getHttpServer()).get('/v1/profile').expect(401);
  });

  it('yeni kullanıcı için varsayılan profil döner (satır yok)', async () => {
    const { token, userId } = await registerAndToken();
    const res = await request(app.getHttpServer())
      .get('/v1/profile')
      .set('Authorization', `Bearer ${token}`)
      .expect(200);
    expect(res.body).toMatchObject({
      userId,
      displayName: null,
      chronotype: null,
      locale: 'en',
      timezone: 'UTC',
    });
  });

  it('PATCH upsert eder ve sonraki GET kalıcı değeri döner', async () => {
    const { token, userId } = await registerAndToken();
    const patched = await request(app.getHttpServer())
      .patch('/v1/profile')
      .set('Authorization', `Bearer ${token}`)
      .send({ displayName: 'Gece Kuşu', chronotype: 'wolf', timezone: 'Europe/Istanbul' })
      .expect(200);
    expect(patched.body).toMatchObject({
      userId,
      displayName: 'Gece Kuşu',
      chronotype: 'wolf',
      locale: 'en',
      timezone: 'Europe/Istanbul',
    });

    const after = await request(app.getHttpServer())
      .get('/v1/profile')
      .set('Authorization', `Bearer ${token}`)
      .expect(200);
    expect(after.body.displayName).toBe('Gece Kuşu');
    expect(after.body.timezone).toBe('Europe/Istanbul');
  });

  it('geçersiz chronotype 400', async () => {
    const { token } = await registerAndToken();
    await request(app.getHttpServer())
      .patch('/v1/profile')
      .set('Authorization', `Bearer ${token}`)
      .send({ chronotype: 'dragon' })
      .expect(400);
  });

  it('geçersiz timezone 400 (IANA doğrulama)', async () => {
    const { token } = await registerAndToken();
    await request(app.getHttpServer())
      .patch('/v1/profile')
      .set('Authorization', `Bearer ${token}`)
      .send({ timezone: 'Nowhere/Void' })
      .expect(400);
  });

  it('geçersiz locale 400 (BCP-47 doğrulama)', async () => {
    const { token } = await registerAndToken();
    await request(app.getHttpServer())
      .patch('/v1/profile')
      .set('Authorization', `Bearer ${token}`)
      .send({ locale: '!!' })
      .expect(400);
  });

  it('geçerli locale (tr) kalıcı olur', async () => {
    const { token } = await registerAndToken();
    const res = await request(app.getHttpServer())
      .patch('/v1/profile')
      .set('Authorization', `Bearer ${token}`)
      .send({ locale: 'tr', timezone: 'Europe/Istanbul' })
      .expect(200);
    expect(res.body.locale).toBe('tr');
    expect(res.body.timezone).toBe('Europe/Istanbul');
  });

  it("izolasyon: A'nın token'ı yalnızca A'nın profilini döndürür/günceller", async () => {
    const a = await registerAndToken();
    const b = await registerAndToken();

    await request(app.getHttpServer())
      .patch('/v1/profile')
      .set('Authorization', `Bearer ${a.token}`)
      .send({ displayName: 'A-name' })
      .expect(200);

    // B kendi token'ıyla A'nın değerini GÖREMEZ.
    const bProfile = await request(app.getHttpServer())
      .get('/v1/profile')
      .set('Authorization', `Bearer ${b.token}`)
      .expect(200);
    expect(bProfile.body.userId).toBe(b.userId);
    expect(bProfile.body.displayName).toBeNull();
  });
});
