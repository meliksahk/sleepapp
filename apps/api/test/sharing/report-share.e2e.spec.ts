import 'reflect-metadata';
import { ValidationPipe, type INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { AppModule } from '../../src/app.module';

/** sharing gece raporu kartı e2e (gerçek DB). Cross-module: sharing → sleep. */
describe('Sharing report card e2e (HTTP)', () => {
  let app: INestApplication;

  const token = async (): Promise<string> => {
    const res = await request(app.getHttpServer())
      .post('/v1/auth/device')
      .send({
        fingerprint: `share-report-e2e-${Date.now()}-${Math.round(process.hrtime()[1])}`,
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

  it('rapor yokken 404 no_report', async () => {
    const t = await token();
    const res = await request(app.getHttpServer())
      .get('/v1/sharing/report?night=2000-01-01')
      .set('Authorization', `Bearer ${t}`)
      .expect(404);
    expect(res.body.code).toBe('no_report');
  });

  it('geçersiz night → 400 invalid_night', async () => {
    const t = await token();
    const res = await request(app.getHttpServer())
      .get('/v1/sharing/report?night=bad')
      .set('Authorization', `Bearer ${t}`)
      .expect(400);
    expect(res.body.code).toBe('invalid_night');
  });

  it('uyku kaydından sonra → gece raporu paylaşım kartı', async () => {
    const t = await token();
    await request(app.getHttpServer())
      .patch('/v1/profile')
      .set('Authorization', `Bearer ${t}`)
      .send({ timezone: 'UTC' })
      .expect(200);
    // 2026-04-10 22:00 → 2026-04-11 05:30 UTC = gece 2026-04-10, 450 dk
    await request(app.getHttpServer())
      .post('/v1/sleep/sessions')
      .set('Authorization', `Bearer ${t}`)
      .send({
        startedAt: '2026-04-10T22:00:00.000Z',
        endedAt: '2026-04-11T05:30:00.000Z',
        movementEvents: 3,
        soundEvents: 1,
      })
      .expect(201);

    const res = await request(app.getHttpServer())
      .get('/v1/sharing/report?night=2026-04-10')
      .set('Authorization', `Bearer ${t}`)
      .expect(200);
    expect(res.body.nightDate).toBe('2026-04-10');
    expect(res.body.durationText).toBe('7h 30m');
    expect(res.body.title).toBe('My night: 7h 30m');
    expect(res.body.deepLink).toBe('nocta://report/2026-04-10');
    expect(typeof res.body.calmScore).toBe('number');
  });
});
