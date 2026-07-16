import 'reflect-metadata';
import { ValidationPipe, type INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { AppModule } from '../../src/app.module';

/** sleep e2e (gerçek DB). Kayıt + gece gruplama + izolasyon. Cross-module timezone. */
describe('Sleep e2e (HTTP)', () => {
  let app: INestApplication;

  const token = async (): Promise<string> => {
    const res = await request(app.getHttpServer())
      .post('/v1/auth/device')
      .send({
        fingerprint: `sleep-e2e-${Date.now()}-${Math.round(process.hrtime()[1])}`,
        platform: 'ios',
      })
      .expect(201);
    return res.body.accessToken;
  };

  const setTz = async (t: string, timezone: string): Promise<void> => {
    await request(app.getHttpServer())
      .patch('/v1/profile')
      .set('Authorization', `Bearer ${t}`)
      .send({ timezone })
      .expect(200);
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
    await request(app.getHttpServer()).post('/v1/sleep/sessions').expect(401);
  });

  it('kayıt: süre + gece etiketi (kullanıcı tz) türetilir', async () => {
    const t = await token();
    await setTz(t, 'Europe/Istanbul');
    // 2026-01-11T02:00 Istanbul = 2026-01-10T23:00Z → gece 2026-01-10
    const res = await request(app.getHttpServer())
      .post('/v1/sleep/sessions')
      .set('Authorization', `Bearer ${t}`)
      .send({
        startedAt: '2026-01-10T23:00:00.000Z',
        endedAt: '2026-01-11T04:00:00.000Z', // 5 saat = 300 dk
        movementEvents: 12,
        soundEvents: 3,
      })
      .expect(201);
    expect(res.body.durationMinutes).toBe(300);
    expect(res.body.nightDate).toBe('2026-01-10');
    expect(res.body.movementEvents).toBe(12);
  });

  it('geçersiz aralık (ended <= started) → 400 invalid_range', async () => {
    const t = await token();
    const res = await request(app.getHttpServer())
      .post('/v1/sleep/sessions')
      .set('Authorization', `Bearer ${t}`)
      .send({
        startedAt: '2026-01-11T06:00:00.000Z',
        endedAt: '2026-01-10T23:00:00.000Z',
        movementEvents: 0,
        soundEvents: 0,
      })
      .expect(400);
    expect(res.body.code).toBe('invalid_range');
  });

  it('negatif olay sayısı → 400 (validasyon)', async () => {
    const t = await token();
    await request(app.getHttpServer())
      .post('/v1/sleep/sessions')
      .set('Authorization', `Bearer ${t}`)
      .send({
        startedAt: '2026-01-10T23:00:00.000Z',
        endedAt: '2026-01-11T04:00:00.000Z',
        movementEvents: -1,
        soundEvents: 0,
      })
      .expect(400);
  });

  it('gece raporu: o gecenin oturumlarını özetler', async () => {
    const t = await token();
    await setTz(t, 'UTC');
    // İki oturum aynı gece (UTC): 2026-03-10 22:00→2026-03-11 05:00 → gece 2026-03-10
    await request(app.getHttpServer())
      .post('/v1/sleep/sessions')
      .set('Authorization', `Bearer ${t}`)
      .send({
        startedAt: '2026-03-10T22:00:00.000Z',
        endedAt: '2026-03-11T04:00:00.000Z', // 360 dk
        movementEvents: 4,
        soundEvents: 2,
      })
      .expect(201);

    const res = await request(app.getHttpServer())
      .get('/v1/sleep/report?night=2026-03-10')
      .set('Authorization', `Bearer ${t}`)
      .expect(200);
    expect(res.body.nightDate).toBe('2026-03-10');
    expect(res.body.sessionCount).toBe(1);
    expect(res.body.totalDurationMinutes).toBe(360);
    expect(res.body.movementEvents).toBe(4);
    expect(typeof res.body.calmScore).toBe('number');
  });

  it('oturum olmayan gece → 404 no_report', async () => {
    const t = await token();
    const res = await request(app.getHttpServer())
      .get('/v1/sleep/report?night=2000-01-01')
      .set('Authorization', `Bearer ${t}`)
      .expect(404);
    expect(res.body.code).toBe('no_report');
  });

  it('geçersiz night parametresi → 400 invalid_night', async () => {
    const t = await token();
    const res = await request(app.getHttpServer())
      .get('/v1/sleep/report?night=15-07-2026')
      .set('Authorization', `Bearer ${t}`)
      .expect(400);
    expect(res.body.code).toBe('invalid_night');
  });

  it('streak: kayıt yokken hepsi 0', async () => {
    const t = await token();
    const res = await request(app.getHttpServer())
      .get('/v1/sleep/streak')
      .set('Authorization', `Bearer ${t}`)
      .expect(200);
    expect(res.body).toEqual({ current: 0, longest: 0, totalNights: 0 });
  });

  it('streak: bu geceki oturumdan sonra current >= 1 (canlı seri)', async () => {
    const t = await token();
    await setTz(t, 'UTC');
    const now = Date.now();
    await request(app.getHttpServer())
      .post('/v1/sleep/sessions')
      .set('Authorization', `Bearer ${t}`)
      .send({
        startedAt: new Date(now - 2 * 60 * 60 * 1000).toISOString(), // 2 saat önce
        endedAt: new Date(now).toISOString(),
        movementEvents: 1,
        soundEvents: 0,
      })
      .expect(201);

    const res = await request(app.getHttpServer())
      .get('/v1/sleep/streak')
      .set('Authorization', `Bearer ${t}`)
      .expect(200);
    expect(res.body.totalNights).toBeGreaterThanOrEqual(1);
    expect(res.body.current).toBeGreaterThanOrEqual(1); // bugün/dün → canlı
    expect(res.body.longest).toBeGreaterThanOrEqual(1);
  });

  it('gece aralığı filtresi (from+to) yalnızca aralıktaki oturumları döner', async () => {
    const t = await token();
    await setTz(t, 'UTC');
    // Gece 2026-06-10 (aralık içi) ve 2026-08-10 (aralık dışı)
    for (const [start, end] of [
      ['2026-06-10T22:00:00.000Z', '2026-06-11T04:00:00.000Z'],
      ['2026-08-10T22:00:00.000Z', '2026-08-11T04:00:00.000Z'],
    ]) {
      await request(app.getHttpServer())
        .post('/v1/sleep/sessions')
        .set('Authorization', `Bearer ${t}`)
        .send({ startedAt: start, endedAt: end, movementEvents: 1, soundEvents: 0 })
        .expect(201);
    }

    const res = await request(app.getHttpServer())
      .get('/v1/sleep/sessions?from=2026-06-01&to=2026-06-30')
      .set('Authorization', `Bearer ${t}`)
      .expect(200);
    const nights = res.body.map((s: { nightDate: string }) => s.nightDate);
    expect(nights).toContain('2026-06-10');
    expect(nights).not.toContain('2026-08-10');
  });

  it('geçersiz aralık parametreleri → 400 invalid_range', async () => {
    const t = await token();
    // yalnızca from
    await request(app.getHttpServer())
      .get('/v1/sleep/sessions?from=2026-06-01')
      .set('Authorization', `Bearer ${t}`)
      .expect(400);
    // from > to
    const res = await request(app.getHttpServer())
      .get('/v1/sleep/sessions?from=2026-07-31&to=2026-07-01')
      .set('Authorization', `Bearer ${t}`)
      .expect(400);
    expect(res.body.code).toBe('invalid_range');
  });

  it('liste yalnızca kendi oturumlarını döner (izolasyon)', async () => {
    const a = await token();
    const b = await token();
    await request(app.getHttpServer())
      .post('/v1/sleep/sessions')
      .set('Authorization', `Bearer ${a}`)
      .send({
        startedAt: '2026-02-01T22:00:00.000Z',
        endedAt: '2026-02-02T05:00:00.000Z',
        movementEvents: 1,
        soundEvents: 1,
      })
      .expect(201);

    const bList = await request(app.getHttpServer())
      .get('/v1/sleep/sessions')
      .set('Authorization', `Bearer ${b}`)
      .expect(200);
    expect(bList.body).toEqual([]); // B, A'nın oturumunu GÖREMEZ

    const aList = await request(app.getHttpServer())
      .get('/v1/sleep/sessions')
      .set('Authorization', `Bearer ${a}`)
      .expect(200);
    expect(aList.body.length).toBeGreaterThanOrEqual(1);
  });
});
