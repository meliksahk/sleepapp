import 'reflect-metadata';
import { ValidationPipe, type INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { PrismaClient } from '@prisma/client';
import { AppModule } from '../../src/app.module';

/** Push token kaydı e2e (gerçek DB). */
describe('Notification token e2e (HTTP)', () => {
  let app: INestApplication;
  const prisma = new PrismaClient();
  const tokens: string[] = [];
  const mkToken = (): string => {
    const t = `push-${Date.now()}-${Math.round(process.hrtime()[1])}`;
    tokens.push(t);
    return t;
  };
  const auth = async (): Promise<{ token: string; userId: string }> => {
    const res = await request(app.getHttpServer())
      .post('/v1/auth/device')
      .send({
        fingerprint: `notif-${Date.now()}-${Math.round(process.hrtime()[1])}`,
        platform: 'ios',
      })
      .expect(201);
    return { token: res.body.accessToken, userId: res.body.userId };
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
    if (tokens.length) await prisma.device_tokens.deleteMany({ where: { token: { in: tokens } } });
    await prisma.$disconnect();
    await app.close();
  });

  it('token olmadan 401', async () => {
    await request(app.getHttpServer())
      .post('/v1/notifications/token')
      .send({ token: mkToken(), platform: 'ios' })
      .expect(401);
  });

  it("kayıt 204 + DB'ye yazılır; idempotent (tek satır)", async () => {
    const { token: jwt, userId } = await auth();
    const push = mkToken();
    for (let i = 0; i < 2; i++) {
      await request(app.getHttpServer())
        .post('/v1/notifications/token')
        .set('Authorization', `Bearer ${jwt}`)
        .send({ token: push, platform: 'ios' })
        .expect(204);
    }
    const rows = await prisma.device_tokens.findMany({ where: { token: push } });
    expect(rows).toHaveLength(1);
    expect(rows[0]?.user_id).toBe(userId);
  });

  it('cihaz hesap değiştirince token yeni kullanıcıya atanır', async () => {
    const a = await auth();
    const b = await auth();
    const push = mkToken();
    await request(app.getHttpServer())
      .post('/v1/notifications/token')
      .set('Authorization', `Bearer ${a.token}`)
      .send({ token: push, platform: 'android' })
      .expect(204);
    await request(app.getHttpServer())
      .post('/v1/notifications/token')
      .set('Authorization', `Bearer ${b.token}`)
      .send({ token: push, platform: 'android' })
      .expect(204);
    const row = await prisma.device_tokens.findUnique({ where: { token: push } });
    expect(row?.user_id).toBe(b.userId);
  });

  it('geçersiz platform → 400', async () => {
    const { token: jwt } = await auth();
    await request(app.getHttpServer())
      .post('/v1/notifications/token')
      .set('Authorization', `Bearer ${jwt}`)
      .send({ token: mkToken(), platform: 'windows' })
      .expect(400);
  });

  describe('POST /v1/notifications/test (fan-out)', () => {
    it('token olmadan 401', async () => {
      await request(app.getHttpServer())
        .post('/v1/notifications/test')
        .send({ title: 'T', body: 'B' })
        .expect(401);
    });

    it('cihaz yokken → 200 sent:0 failed:0', async () => {
      const { token: jwt } = await auth();
      const res = await request(app.getHttpServer())
        .post('/v1/notifications/test')
        .set('Authorization', `Bearer ${jwt}`)
        .send({ title: 'Test', body: 'Merhaba' })
        .expect(200);
      expect(res.body).toEqual({ sent: 0, failed: 0 });
    });

    it('kayıtlı 2 cihaz → sent:2 (log-adaptörü)', async () => {
      const { token: jwt } = await auth();
      for (const platform of ['ios', 'android']) {
        await request(app.getHttpServer())
          .post('/v1/notifications/token')
          .set('Authorization', `Bearer ${jwt}`)
          .send({ token: mkToken(), platform })
          .expect(204);
      }
      const res = await request(app.getHttpServer())
        .post('/v1/notifications/test')
        .set('Authorization', `Bearer ${jwt}`)
        .send({ title: 'Test', body: 'İki cihaz' })
        .expect(200);
      expect(res.body.sent).toBe(2);
      expect(res.body.failed).toBe(0);
    });

    it('opt-out: profil notificationsEnabled=false ise cihaz olsa da sent:0', async () => {
      const { token: jwt } = await auth();
      // Cihaz kaydet (aksi halde zaten 0 olurdu — anlamlı test için önce token ekle).
      await request(app.getHttpServer())
        .post('/v1/notifications/token')
        .set('Authorization', `Bearer ${jwt}`)
        .send({ token: mkToken(), platform: 'ios' })
        .expect(204);
      // Bildirimleri kapat.
      await request(app.getHttpServer())
        .patch('/v1/profile')
        .set('Authorization', `Bearer ${jwt}`)
        .send({ notificationsEnabled: false })
        .expect(200);

      const res = await request(app.getHttpServer())
        .post('/v1/notifications/test')
        .set('Authorization', `Bearer ${jwt}`)
        .send({ title: 'Test', body: 'Kapalı' })
        .expect(200);
      expect(res.body).toEqual({ sent: 0, failed: 0 });
    });

    it('boş başlık → 400 (validasyon)', async () => {
      const { token: jwt } = await auth();
      await request(app.getHttpServer())
        .post('/v1/notifications/test')
        .set('Authorization', `Bearer ${jwt}`)
        .send({ title: '', body: 'B' })
        .expect(400);
    });
  });
});
