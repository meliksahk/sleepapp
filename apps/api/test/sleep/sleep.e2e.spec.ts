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

  it('stats: gece sayısı + toplam/ortalama süre', async () => {
    const t = await token();
    await setTz(t, 'UTC');
    // İki gece: 2026-09-10 (300dk) ve 2026-09-11 (360dk)
    for (const [start, end] of [
      ['2026-09-10T22:00:00.000Z', '2026-09-11T03:00:00.000Z'],
      ['2026-09-11T22:00:00.000Z', '2026-09-12T04:00:00.000Z'],
    ]) {
      await request(app.getHttpServer())
        .post('/v1/sleep/sessions')
        .set('Authorization', `Bearer ${t}`)
        .send({ startedAt: start, endedAt: end, movementEvents: 0, soundEvents: 0 })
        .expect(201);
    }

    const res = await request(app.getHttpServer())
      .get('/v1/sleep/stats')
      .set('Authorization', `Bearer ${t}`)
      .expect(200);
    expect(res.body.nights).toBe(2);
    expect(res.body.totalDurationMinutes).toBe(660);
    expect(res.body.averageDurationMinutes).toBe(330);
  });

  it('stats: 100’den FAZLA oturumda pencere yok (regresyon: eskiden son 100 sayılırdı)', async () => {
    const t = await token();
    await setTz(t, 'UTC');
    // 120 ayrı gece × 60 dk. Eski kod son 100'ü sayardı → nights=100, total=6000.
    // Doğrusu: nights=120, total=7200. Bu test eski kodda KIRMIZI olurdu.
    const rows = Array.from({ length: 120 }, (_, i) => {
      const day = new Date(Date.UTC(2025, 0, 1 + i));
      const start = new Date(day.getTime() + 22 * 3600_000); // 22:00
      return {
        startedAt: start.toISOString(),
        endedAt: new Date(start.getTime() + 60 * 60_000).toISOString(), // 60 dk
      };
    });
    for (const r of rows) {
      await request(app.getHttpServer())
        .post('/v1/sleep/sessions')
        .set('Authorization', `Bearer ${t}`)
        .send({ startedAt: r.startedAt, endedAt: r.endedAt, movementEvents: 0, soundEvents: 0 })
        .expect(201);
    }

    const res = await request(app.getHttpServer())
      .get('/v1/sleep/stats')
      .set('Authorization', `Bearer ${t}`)
      .expect(200);
    expect(res.body.nights).toBe(120); // eskiden 100
    expect(res.body.totalDurationMinutes).toBe(7200); // eskiden 6000
    expect(res.body.averageDurationMinutes).toBe(60);
  });

  it('stats: kayıt yokken hepsi 0', async () => {
    const t = await token();
    const res = await request(app.getHttpServer())
      .get('/v1/sleep/stats')
      .set('Authorization', `Bearer ${t}`)
      .expect(200);
    expect(res.body).toEqual({ nights: 0, totalDurationMinutes: 0, averageDurationMinutes: 0 });
  });

  it('trend: kayıt yokken 7 gece 0 + eskiden yeniye sıralı', async () => {
    const t = await token();
    const res = await request(app.getHttpServer())
      .get('/v1/sleep/trend')
      .set('Authorization', `Bearer ${t}`)
      .expect(200);
    expect(res.body.nights).toHaveLength(7);
    expect(res.body.nights.every((n: { durationMinutes: number }) => n.durationMinutes === 0)).toBe(
      true,
    );
    expect(res.body.nightsWithData).toBe(0);
    expect(res.body.averageDurationMinutes).toBe(0);
    // eskiden yeniye artan sıra
    const dates = res.body.nights.map((n: { nightDate: string }) => n.nightDate);
    expect([...dates].sort()).toEqual(dates);
  });

  it('trend: bu geceki oturum pencere içindeki bir kovaya düşer', async () => {
    const t = await token();
    await setTz(t, 'UTC');
    const now = Date.now();
    await request(app.getHttpServer())
      .post('/v1/sleep/sessions')
      .set('Authorization', `Bearer ${t}`)
      .send({
        startedAt: new Date(now - 3 * 60 * 60 * 1000).toISOString(), // 3 saat = 180dk
        endedAt: new Date(now).toISOString(),
        movementEvents: 0,
        soundEvents: 0,
      })
      .expect(201);

    const res = await request(app.getHttpServer())
      .get('/v1/sleep/trend')
      .set('Authorization', `Bearer ${t}`)
      .expect(200);
    // 06:00 sınırı oturumu bugün/dün kovasına atabilir → kovayı sabitleme;
    // pencere içinde en az bir gece ~180dk taşımalı (sınır-bağımsız).
    expect(res.body.nights).toHaveLength(7);
    const maxNight = Math.max(
      ...res.body.nights.map((n: { durationMinutes: number }) => n.durationMinutes),
    );
    expect(maxNight).toBeGreaterThanOrEqual(180);
    expect(res.body.nightsWithData).toBeGreaterThanOrEqual(1);
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
