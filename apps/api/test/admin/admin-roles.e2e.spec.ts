import 'reflect-metadata';
import { ValidationPipe, type INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { PrismaClient } from '@prisma/client';
import { AppModule } from '../../src/app.module';

/**
 * Admin rol kapısı e2e (gerçek DB).
 *
 * NEDEN BU TEST: roller şimdiye dek JWT'ye basılıyor ve request'e ekleniyordu ama
 * hiçbir yerde KONTROL EDİLMİYORDU. Bu dosyanın çekirdek iddiası "rolsüz kullanıcı
 * admin ucuna GİREMEZ" — RolesGuard eklenmeden önce bu test KIRMIZI idi (rolsüz
 * kullanıcı 200 alıyordu), kanıt PR açıklamasında.
 *
 * Rol atama akışı gerçekçi: cihaz kaydı → DB'de rol ver → REFRESH → yeni token'da
 * rol var. Token'lar kısa ömürlü olduğu için rol değişimi refresh'te yürürlüğe
 * girer; test bunu da örtük olarak sabitler.
 */
describe('Admin rol kapısı e2e (HTTP)', () => {
  let app: INestApplication;
  const prisma = new PrismaClient();
  const created: string[] = [];

  /** Cihaz kaydı → { userId, accessToken, refreshToken }. */
  const registerDevice = async (): Promise<{
    userId: string;
    accessToken: string;
    refreshToken: string;
  }> => {
    const res = await request(app.getHttpServer())
      .post('/v1/auth/device')
      .send({
        fingerprint: `admin-e2e-${Date.now()}-${Math.round(process.hrtime()[1])}`,
        platform: 'ios',
      })
      .expect(201);
    created.push(res.body.userId);
    return res.body;
  };

  /**
   * Kullanıcıya rol verip refresh ile rolleri taşıyan yeni token çifti alır.
   * DİKKAT: refresh token ROTASYONLUDUR — eski token tüketilir. Bu yüzden çağıran
   * daima DÖNEN refreshToken ile devam etmelidir (aksi halde 401 alır).
   */
  const promoteAndRefresh = async (
    userId: string,
    refreshToken: string,
    roles: string[],
  ): Promise<{ accessToken: string; refreshToken: string }> => {
    await prisma.users.update({ where: { id: userId }, data: { roles } });
    const res = await request(app.getHttpServer())
      .post('/v1/auth/refresh')
      .send({ refreshToken })
      .expect(200);
    return { accessToken: res.body.accessToken, refreshToken: res.body.refreshToken };
  };

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

  it('token yok → 401 (rol kapısı auth kapısının yerine geçmez)', async () => {
    await request(app.getHttpServer()).get('/v1/admin/me').expect(401);
  });

  it('ÇEKİRDEK İDDİA: rolsüz normal kullanıcı → 403 (guard olmadan 200 alıyordu)', async () => {
    const { accessToken } = await registerDevice();
    await request(app.getHttpServer())
      .get('/v1/admin/me')
      .set('Authorization', `Bearer ${accessToken}`)
      .expect(403);
  });

  it('admin olmayan bir rol (uydurma) → 403 (rol adı eşleşmesi gerçek)', async () => {
    const { userId, refreshToken } = await registerDevice();
    const { accessToken: token } = await promoteAndRefresh(userId, refreshToken, [
      'not-a-real-role',
    ]);
    await request(app.getHttpServer())
      .get('/v1/admin/me')
      .set('Authorization', `Bearer ${token}`)
      .expect(403);
  });

  it('owner rolü → 200 + rolleri döner', async () => {
    const { userId, refreshToken } = await registerDevice();
    const { accessToken: token } = await promoteAndRefresh(userId, refreshToken, ['owner']);
    const res = await request(app.getHttpServer())
      .get('/v1/admin/me')
      .set('Authorization', `Bearer ${token}`)
      .expect(200);
    expect(res.body).toEqual({ userId, roles: ['owner'] });
  });

  it('analyst rolü de girer (rollerden HERHANGİ biri yeter)', async () => {
    const { userId, refreshToken } = await registerDevice();
    const { accessToken: token } = await promoteAndRefresh(userId, refreshToken, ['analyst']);
    await request(app.getHttpServer())
      .get('/v1/admin/me')
      .set('Authorization', `Bearer ${token}`)
      .expect(200);
  });

  it('tanınmayan rol adı yanıta SIZMAZ (panel yetki mantığı çöp rol görmez)', async () => {
    const { userId, refreshToken } = await registerDevice();
    const { accessToken: token } = await promoteAndRefresh(userId, refreshToken, [
      'owner',
      'superuser-hack',
    ]);
    const res = await request(app.getHttpServer())
      .get('/v1/admin/me')
      .set('Authorization', `Bearer ${token}`)
      .expect(200);
    expect(res.body.roles).toEqual(['owner']);
  });

  it('rol geri alınınca erişim biter (refresh sonrası)', async () => {
    const { userId, refreshToken } = await registerDevice();
    const granted = await promoteAndRefresh(userId, refreshToken, ['owner']);
    await request(app.getHttpServer())
      .get('/v1/admin/me')
      .set('Authorization', `Bearer ${granted.accessToken}`)
      .expect(200);

    // Rol geri alındı → bir sonraki refresh'ten gelen token artık giremez.
    await prisma.users.update({ where: { id: userId }, data: { roles: [] } });
    const after = await request(app.getHttpServer())
      .post('/v1/auth/refresh')
      .send({ refreshToken: granted.refreshToken })
      .expect(200);
    await request(app.getHttpServer())
      .get('/v1/admin/me')
      .set('Authorization', `Bearer ${after.body.accessToken}`)
      .expect(403);
  });
});
