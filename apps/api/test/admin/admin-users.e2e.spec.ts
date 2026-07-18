import 'reflect-metadata';
import { ValidationPipe, type INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { PrismaClient } from '@prisma/client';

import { AppModule } from '../../src/app.module';

/**
 * `GET /v1/admin/users` — destek senaryosu kullanıcı araması (docs/02 §165).
 * Rol daraltması (owner/support) + PII gizliliği burada kilitlenir.
 */
describe('Admin users search e2e (HTTP)', () => {
  let app: INestApplication;
  const prisma = new PrismaClient();
  const createdUsers: string[] = [];
  const seedEmail = `usersearch-${Date.now()}@example.com`;
  let seedUserId = '';

  const register = async (): Promise<{
    userId: string;
    refreshToken: string;
    accessToken: string;
  }> => {
    const reg = await request(app.getHttpServer())
      .post('/v1/auth/device')
      .send({
        fingerprint: `usr-${Date.now()}-${Math.round(process.hrtime()[1])}`,
        platform: 'ios',
      })
      .expect(201);
    createdUsers.push(reg.body.userId);
    return reg.body;
  };

  const tokenFor = async (roles: string[]): Promise<string> => {
    const reg = await register();
    await prisma.users.update({
      where: { id: reg.userId },
      data: { kind: 'admin', roles },
    });
    const refreshed = await request(app.getHttpServer())
      .post('/v1/auth/refresh')
      .send({ refreshToken: reg.refreshToken })
      .expect(200);
    return refreshed.body.accessToken;
  };

  const search = (token: string, q: string) =>
    request(app.getHttpServer())
      .get(`/v1/admin/users?q=${encodeURIComponent(q)}`)
      .set('Authorization', `Bearer ${token}`);

  beforeAll(async () => {
    await prisma.$connect();
    const moduleRef = await Test.createTestingModule({ imports: [AppModule] }).compile();
    app = moduleRef.createNestApplication();
    app.setGlobalPrefix('v1', { exclude: ['health'] });
    app.useGlobalPipes(
      new ValidationPipe({ whitelist: true, forbidNonWhitelisted: true, transform: true }),
    );
    await app.init();

    // Aranabilir bir kullanıcı (bilinen e-posta ile) hazırla.
    const seed = await register();
    seedUserId = seed.userId;
    await prisma.users.update({
      where: { id: seedUserId },
      data: { kind: 'registered', email: seedEmail },
    });
  });

  afterAll(async () => {
    if (createdUsers.length > 0) {
      await prisma.users.deleteMany({ where: { id: { in: createdUsers } } });
    }
    await prisma.$disconnect();
    await app.close();
  });

  it('token olmadan 401', async () => {
    await request(app.getHttpServer()).get('/v1/admin/users?q=test').expect(401);
  });

  it('ÇEKİRDEK: owner e-posta ile kullanıcıyı bulur (id/tür/e-posta döner)', async () => {
    const token = await tokenFor(['owner']);
    const res = await search(token, seedEmail).expect(200);
    const hit = (res.body as Array<{ id: string; email: string; kind: string }>).find(
      (u) => u.id === seedUserId,
    );
    expect(hit).toBeDefined();
    expect(hit!.email).toBe(seedEmail);
    expect(hit!.kind).toBe('registered');
    // PII sızıntısı yok: parola/token/2FA alanı DÖNMEZ.
    expect(JSON.stringify(res.body)).not.toContain('password');
    expect(JSON.stringify(res.body)).not.toContain('totp');
  });

  it('ÇEKİRDEK: tam id ile de bulur', async () => {
    const token = await tokenFor(['owner']);
    const res = await search(token, seedUserId).expect(200);
    expect((res.body as Array<{ id: string }>).some((u) => u.id === seedUserId)).toBe(true);
  });

  it('ÇEKİRDEK ROL: analyst (PII göremez) 403 — sınıf rolü daraltıldı', async () => {
    const token = await tokenFor(['analyst']);
    await search(token, seedEmail).expect(403);
  });

  it('ÇEKİRDEK ROL: sıradan kullanıcı (admin değil) 403', async () => {
    const reg = await register();
    await search(reg.accessToken, seedEmail).expect(403);
  });

  it('kısa sorgu (<2 karakter) → boş liste (tüm tabanı dökmez)', async () => {
    const token = await tokenFor(['owner']);
    const res = await search(token, 'a').expect(200);
    expect(res.body).toEqual([]);
  });
});
