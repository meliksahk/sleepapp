import 'reflect-metadata';
import { ValidationPipe, type INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { PrismaClient } from '@prisma/client';
import { AppModule } from '../../src/app.module';

/**
 * Çıkış e2e.
 *
 * NEDEN: çıkış ucu YOKTU — panel yalnızca çerezi siliyordu, sunucudaki oturum
 * 30 gün daha geçerli kalıyordu. "Çıkış yaptım" diyen kullanıcı için bu sessiz
 * bir yalandı: token bir yerde ele geçirilmişse çıkış onu durdurmuyordu.
 */
describe('Çıkış e2e (HTTP)', () => {
  let app: INestApplication;
  const prisma = new PrismaClient();
  const created: string[] = [];

  const registerDevice = async (): Promise<{ userId: string; refreshToken: string }> => {
    const res = await request(app.getHttpServer())
      .post('/v1/auth/device')
      .send({
        fingerprint: `logout-e2e-${Date.now()}-${Math.round(process.hrtime()[1])}`,
        platform: 'ios',
      })
      .expect(201);
    created.push(res.body.userId);
    return res.body;
  };

  const logout = (refreshToken: string) =>
    request(app.getHttpServer()).post('/v1/auth/logout').send({ refreshToken });

  const refresh = (refreshToken: string) =>
    request(app.getHttpServer()).post('/v1/auth/refresh').send({ refreshToken });

  beforeAll(async () => {
    await prisma.$connect();
    const moduleRef = await Test.createTestingModule({ imports: [AppModule] }).compile();
    app = moduleRef.createNestApplication();
    app.setGlobalPrefix('v1', { exclude: ['health'] });
    app.useGlobalPipes(
      new ValidationPipe({ whitelist: true, forbidNonWhitelisted: true, transform: true }),
    );
    await app.init();
  });

  afterAll(async () => {
    if (created.length > 0) {
      await prisma.users.deleteMany({ where: { id: { in: created } } });
    }
    await prisma.$disconnect();
    await app.close();
  });

  it('ÇEKİRDEK İDDİA: çıkıştan sonra refresh token ÖLÜ (oturum gerçekten bitti)', async () => {
    const { refreshToken } = await registerDevice();
    await refresh(refreshToken).expect(200); // önce çalıştığını görelim
  });

  it('çıkış → aynı token artık yenilenemez', async () => {
    const { refreshToken } = await registerDevice();
    await logout(refreshToken).expect(204);
    await refresh(refreshToken).expect(401);
  });

  it('çıkış AİLEYİ düşürür — rotasyondan doğmuş YENİ token da ölür', async () => {
    // Tek token'ı iptal etmek yetmez: rotasyon zincirinin başka halkası ayakta
    // kalırsa "çıkış yaptım" diyen kullanıcıya sessizce yalan söylemiş oluruz.
    const { refreshToken } = await registerDevice();
    const rotated = await refresh(refreshToken).expect(200);
    const newToken = rotated.body.refreshToken;

    await logout(newToken).expect(204);
    await refresh(newToken).expect(401);
  });

  it('IDEMPOTENT: bilinmeyen token da 204 (yanıt "bu token gerçek mi?" sorusunu yanıtlamaz)', async () => {
    await logout('bilinmeyen-token-degeri-uzun').expect(204);
  });

  it('çıkış iki kez çağrılabilir', async () => {
    const { refreshToken } = await registerDevice();
    await logout(refreshToken).expect(204);
    await logout(refreshToken).expect(204);
  });

  it('bir kullanıcının çıkışı BAŞKASININ oturumunu etkilemez', async () => {
    const a = await registerDevice();
    const b = await registerDevice();
    await logout(a.refreshToken).expect(204);
    await refresh(b.refreshToken).expect(200);
  });
});
