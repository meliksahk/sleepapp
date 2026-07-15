import 'reflect-metadata';
import { ValidationPipe, type INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { PrismaClient } from '@prisma/client';
import { AppModule } from '../../src/app.module';

/** Magic link e-posta yükseltme uçtan uca (gerçek DB, log-mailer, dev token). */
describe('Magic link e2e (HTTP)', () => {
  let app: INestApplication;
  const prisma = new PrismaClient();
  const emails: string[] = [];

  const registerToken = async (): Promise<{ token: string; userId: string }> => {
    const res = await request(app.getHttpServer())
      .post('/v1/auth/device')
      .send({
        fingerprint: `ml-e2e-${Date.now()}-${Math.round(process.hrtime()[1])}`,
        platform: 'ios',
      })
      .expect(201);
    return { token: res.body.accessToken, userId: res.body.userId };
  };
  const uniqueEmail = (): string => {
    const e = `ml-${Date.now()}-${Math.round(process.hrtime()[1])}@example.com`;
    emails.push(e);
    return e;
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
    if (emails.length) await prisma.users.deleteMany({ where: { email: { in: emails } } });
    await prisma.$disconnect();
    await app.close();
  });

  it('request (dev token) → verify → kullanıcı registered + email set', async () => {
    const { token, userId } = await registerToken();
    const email = uniqueEmail();

    const req = await request(app.getHttpServer())
      .post('/v1/auth/email/request')
      .set('Authorization', `Bearer ${token}`)
      .send({ email })
      .expect(202);
    expect(req.body.status).toBe('sent');
    expect(req.body.devMagicToken).toBeTruthy(); // dev'de ham token dönüyor

    const ver = await request(app.getHttpServer())
      .post('/v1/auth/email/verify')
      .send({ token: req.body.devMagicToken })
      .expect(200);
    expect(ver.body.userId).toBe(userId);
    expect(ver.body.email).toBe(email);

    const row = await prisma.users.findUnique({ where: { id: userId } });
    expect(row?.email).toBe(email);
    expect(row?.kind).toBe('registered');
    expect(row?.email_verified_at).not.toBeNull();
  });

  it('kullanılmış token → 401', async () => {
    const { token } = await registerToken();
    const email = uniqueEmail();
    const req = await request(app.getHttpServer())
      .post('/v1/auth/email/request')
      .set('Authorization', `Bearer ${token}`)
      .send({ email })
      .expect(202);
    const magic = req.body.devMagicToken;
    await request(app.getHttpServer())
      .post('/v1/auth/email/verify')
      .send({ token: magic })
      .expect(200);
    await request(app.getHttpServer())
      .post('/v1/auth/email/verify')
      .send({ token: magic })
      .expect(401);
  });

  it('token olmadan request 401; geçersiz e-posta 400', async () => {
    await request(app.getHttpServer())
      .post('/v1/auth/email/request')
      .send({ email: uniqueEmail() })
      .expect(401);
    const { token } = await registerToken();
    await request(app.getHttpServer())
      .post('/v1/auth/email/request')
      .set('Authorization', `Bearer ${token}`)
      .send({ email: 'not-an-email' })
      .expect(400);
  });

  it('başka hesabın e-postası → 409', async () => {
    const a = await registerToken();
    const email = uniqueEmail();
    const req = await request(app.getHttpServer())
      .post('/v1/auth/email/request')
      .set('Authorization', `Bearer ${a.token}`)
      .send({ email })
      .expect(202);
    await request(app.getHttpServer())
      .post('/v1/auth/email/verify')
      .send({ token: req.body.devMagicToken })
      .expect(200);

    const b = await registerToken();
    await request(app.getHttpServer())
      .post('/v1/auth/email/request')
      .set('Authorization', `Bearer ${b.token}`)
      .send({ email })
      .expect(409);
  });
});
