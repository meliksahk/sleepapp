import 'reflect-metadata';
import { ValidationPipe, type INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { PrismaClient } from '@prisma/client';
import { AppModule } from '../../src/app.module';

/** flags e2e (gerçek DB). Flag'ler prisma ile seed edilir; GET değerlendirmeyi doğrular. */
describe('Flags e2e (HTTP)', () => {
  let app: INestApplication;
  const prisma = new PrismaClient();
  const prefix = `t${Date.now()}`;
  const keys = {
    on: `${prefix}-on`,
    off: `${prefix}-off`,
    r0: `${prefix}-r0`,
    r100: `${prefix}-r100`,
    iosOnly: `${prefix}-ios`,
    minVer: `${prefix}-minver`,
  };

  const token = async (): Promise<string> => {
    const res = await request(app.getHttpServer())
      .post('/v1/auth/device')
      .send({
        fingerprint: `flags-e2e-${Date.now()}-${Math.round(process.hrtime()[1])}`,
        platform: 'ios',
      })
      .expect(201);
    return res.body.accessToken;
  };

  beforeAll(async () => {
    await prisma.$connect();
    await prisma.feature_flags.createMany({
      data: [
        { key: keys.on, rules: { enabled: true } },
        { key: keys.off, rules: { enabled: false } },
        { key: keys.r0, rules: { enabled: true, rolloutPercentage: 0 } },
        { key: keys.r100, rules: { enabled: true, rolloutPercentage: 100 } },
        { key: keys.iosOnly, rules: { enabled: true, platforms: ['ios'] } },
        { key: keys.minVer, rules: { enabled: true, minAppVersion: '1.4.0' } },
      ],
    });

    const moduleRef = await Test.createTestingModule({ imports: [AppModule] }).compile();
    app = moduleRef.createNestApplication();
    app.setGlobalPrefix('v1', { exclude: ['health'] });
    app.useGlobalPipes(
      new ValidationPipe({ whitelist: true, forbidNonWhitelisted: true, transform: true }),
    );
    await app.init();
  });

  afterAll(async () => {
    await prisma.feature_flags.deleteMany({ where: { key: { in: Object.values(keys) } } });
    await prisma.$disconnect();
    await app.close();
  });

  it('token olmadan 401', async () => {
    await request(app.getHttpServer()).get('/v1/flags').expect(401);
  });

  it('flag haritasını değerlendirir (enabled / rollout 0 / rollout 100)', async () => {
    const t = await token();
    const res = await request(app.getHttpServer())
      .get('/v1/flags')
      .set('Authorization', `Bearer ${t}`)
      .expect(200);
    expect(res.body[keys.on]).toBe(true);
    expect(res.body[keys.off]).toBe(false);
    expect(res.body[keys.r0]).toBe(false);
    expect(res.body[keys.r100]).toBe(true);
    // context yok → segment kapılı flag'ler fail-closed
    expect(res.body[keys.iosOnly]).toBe(false);
    expect(res.body[keys.minVer]).toBe(false);
  });

  it('segment context (platform + appVersion) query ile değerlendirilir', async () => {
    const t = await token();
    const ios = await request(app.getHttpServer())
      .get('/v1/flags?platform=ios&appVersion=1.5.0')
      .set('Authorization', `Bearer ${t}`)
      .expect(200);
    expect(ios.body[keys.iosOnly]).toBe(true); // ios eşleşti
    expect(ios.body[keys.minVer]).toBe(true); // 1.5.0 >= 1.4.0

    const android = await request(app.getHttpServer())
      .get('/v1/flags?platform=android&appVersion=1.3.0')
      .set('Authorization', `Bearer ${t}`)
      .expect(200);
    expect(android.body[keys.iosOnly]).toBe(false); // platform dışı
    expect(android.body[keys.minVer]).toBe(false); // 1.3.0 < 1.4.0
  });
});
