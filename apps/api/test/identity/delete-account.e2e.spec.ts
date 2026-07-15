import 'reflect-metadata';
import { ValidationPipe, type INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { PrismaClient } from '@prisma/client';
import { AppModule } from '../../src/app.module';

/** Hesap silme kaskadı (App Store / GDPR). Kullanıcı + tüm ilişkili veri gitmeli. */
describe('Delete account e2e (cascade)', () => {
  let app: INestApplication;
  const prisma = new PrismaClient();

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
    await prisma.$disconnect();
    await app.close();
  });

  it('token olmadan 401', async () => {
    await request(app.getHttpServer()).delete('/v1/auth/me').expect(401);
  });

  it('DELETE /v1/auth/me → kullanıcı + ilişkili tüm satırlar kaskadla silinir', async () => {
    // Kayıt + ilişkili veri üret
    const reg = await request(app.getHttpServer())
      .post('/v1/auth/device')
      .send({
        fingerprint: `del-e2e-${Date.now()}-${Math.round(process.hrtime()[1])}`,
        platform: 'ios',
      })
      .expect(201);
    const { accessToken, userId } = reg.body;

    await request(app.getHttpServer())
      .patch('/v1/profile')
      .set('Authorization', `Bearer ${accessToken}`)
      .send({ displayName: 'To Delete' })
      .expect(200);
    await request(app.getHttpServer())
      .post('/v1/archetype/answers')
      .set('Authorization', `Bearer ${accessToken}`)
      .send({
        version: 1,
        answers: { q1: 'q1a', q2: 'q2a', q3: 'q3a', q4: 'q4a', q5: 'q5a', q6: 'q6a' },
      })
      .expect(201);

    // Silmeden önce ilişkili veri VAR
    const before = {
      users: await prisma.users.count({ where: { id: userId } }),
      devices: await prisma.auth_devices.count({ where: { user_id: userId } }),
      refresh: await prisma.refresh_tokens.count({ where: { user_id: userId } }),
      profiles: await prisma.profiles.count({ where: { id: userId } }),
      archetype: await prisma.archetype_results.count({ where: { user_id: userId } }),
    };
    expect(before).toEqual({ users: 1, devices: 1, refresh: 1, profiles: 1, archetype: 1 });

    await request(app.getHttpServer())
      .delete('/v1/auth/me')
      .set('Authorization', `Bearer ${accessToken}`)
      .expect(204);

    // Silmeden sonra HEPSİ 0
    const after = {
      users: await prisma.users.count({ where: { id: userId } }),
      devices: await prisma.auth_devices.count({ where: { user_id: userId } }),
      refresh: await prisma.refresh_tokens.count({ where: { user_id: userId } }),
      profiles: await prisma.profiles.count({ where: { id: userId } }),
      archetype: await prisma.archetype_results.count({ where: { user_id: userId } }),
    };
    expect(after).toEqual({ users: 0, devices: 0, refresh: 0, profiles: 0, archetype: 0 });
  });
});
