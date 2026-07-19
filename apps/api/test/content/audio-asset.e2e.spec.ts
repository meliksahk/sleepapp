import 'reflect-metadata';
import { ValidationPipe, type INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { PrismaClient } from '@prisma/client';
import { AppModule } from '../../src/app.module';
import { CACHE } from '../../src/shared/cache/cache.port';
import { InMemoryCache } from '../../src/shared/cache/in-memory-cache';

/**
 * audio_assets uçları — gerçek DB.
 *
 * ## Yetkilendirme testi neyi kanıtlıyor (ve neyi kanıtlamıyor)
 *
 * CLAUDE.md §6 "kullanıcı A, B'nin verisini okuyamaz" testi ister. `audio_assets`
 * KATALOG tablosudur (soundscapes gibi): satırların sahibi yok, herkes aynı
 * listeyi görür. Yani kapsamlanacak bir kullanıcı sınırı YOKTUR ve "A, B'nin
 * verisini okuyamaz" testi burada anlamsızdır — yazsaydık yanlış bir güvenlik
 * hissi üretirdi.
 *
 * Burada kanıtlanan iki gerçek kural:
 *  1. Uç KİMLİK DOĞRULAMA ister (token yoksa 401) — anonim katalog dökümü yok.
 *  2. İç depolama anahtarı (`key`) tele SIZMAZ.
 */
describe('Audio assets e2e (HTTP)', () => {
  let app: INestApplication;
  const prisma = new PrismaClient();
  const prefix = `aa${Date.now()}`;
  const keys = {
    calm: `${prefix}-calm/one.wav`,
    focus: `${prefix}-focus/two.wav`,
  };
  let calmId = '';

  const token = async (): Promise<string> => {
    const res = await request(app.getHttpServer())
      .post('/v1/auth/device')
      .send({
        fingerprint: `audio-asset-e2e-${Date.now()}-${Math.round(process.hrtime()[1])}`,
        platform: 'ios',
      })
      .expect(201);
    return res.body.accessToken;
  };

  beforeAll(async () => {
    await prisma.$connect();
    const calm = await prisma.audio_assets.create({
      data: {
        key: keys.calm,
        title: `${prefix} Calm One`,
        genre: 'ambient',
        mood: ['calm', 'sleep'],
        duration_seconds: 10,
        license: 'self-produced',
        source: 'NOCTA audio engine',
      },
    });
    calmId = calm.id;
    await prisma.audio_assets.create({
      data: {
        key: keys.focus,
        title: `${prefix} Focus Two`,
        genre: 'noise',
        mood: ['focus'],
        duration_seconds: 20,
        license: 'CC0',
        source: 'test fixture',
      },
    });

    const moduleRef = await Test.createTestingModule({ imports: [AppModule] })
      .overrideProvider(CACHE)
      .useValue(new InMemoryCache())
      .compile();
    app = moduleRef.createNestApplication();
    app.setGlobalPrefix('v1', { exclude: ['health'] });
    app.useGlobalPipes(
      new ValidationPipe({ whitelist: true, forbidNonWhitelisted: true, transform: true }),
    );
    await app.init();
  });

  afterAll(async () => {
    await prisma.audio_assets.deleteMany({ where: { key: { in: Object.values(keys) } } });
    await prisma.$disconnect();
    await app.close();
  });

  it('token olmadan 401 (liste)', async () => {
    await request(app.getHttpServer()).get('/v1/content/audio-assets').expect(401);
  });

  it('token olmadan 401 (tekil)', async () => {
    await request(app.getHttpServer()).get(`/v1/content/audio-assets/${calmId}`).expect(401);
  });

  it('liste kataloğu döner ve depolama anahtarını SIZDIRMAZ', async () => {
    const t = await token();
    const res = await request(app.getHttpServer())
      .get('/v1/content/audio-assets')
      .set('Authorization', `Bearer ${t}`)
      .expect(200);
    const mine = res.body.filter((x: { title: string }) => x.title.startsWith(prefix));
    expect(mine).toHaveLength(2);
    for (const row of mine) {
      expect(row).not.toHaveProperty('key');
      expect(row.license).toBeTruthy(); // lisans her zaman dolu (DB CHECK)
    }
  });

  it('genre filtresi', async () => {
    const t = await token();
    const res = await request(app.getHttpServer())
      .get('/v1/content/audio-assets?genre=noise')
      .set('Authorization', `Bearer ${t}`)
      .expect(200);
    const mine = res.body.filter((x: { title: string }) => x.title.startsWith(prefix));
    expect(mine).toHaveLength(1);
    expect(mine[0].genre).toBe('noise');
  });

  it('mood filtresi ÖRTÜŞME semantiği taşır (herhangi biri eşleşsin)', async () => {
    const t = await token();
    const res = await request(app.getHttpServer())
      .get('/v1/content/audio-assets?mood=sleep,focus')
      .set('Authorization', `Bearer ${t}`)
      .expect(200);
    const mine = res.body.filter((x: { title: string }) => x.title.startsWith(prefix));
    // 'sleep' calm satırında, 'focus' diğerinde → örtüşmede İKİSİ de döner.
    // `hasEvery` (VE) olsaydı hiçbiri dönmezdi.
    expect(mine).toHaveLength(2);
  });

  it('tekil uç presigned URL döner, key alanı yok', async () => {
    const t = await token();
    const res = await request(app.getHttpServer())
      .get(`/v1/content/audio-assets/${calmId}`)
      .set('Authorization', `Bearer ${t}`)
      .expect(200);
    expect(res.body.asset.id).toBe(calmId);
    expect(res.body.asset).not.toHaveProperty('key');
    expect(res.body.url).toContain(keys.calm);
    expect(res.body.url).toMatch(/X-Amz-Signature=/);
    expect(res.body.expiresInSeconds).toBeGreaterThan(0);
  });

  it('bilinmeyen id → 404', async () => {
    const t = await token();
    await request(app.getHttpServer())
      .get('/v1/content/audio-assets/00000000-0000-0000-0000-000000000000')
      .set('Authorization', `Bearer ${t}`)
      .expect(404);
  });

  it('uuid OLMAYAN id → 500 DEĞİL 404 (Prisma P2023 kapısı)', async () => {
    const t = await token();
    await request(app.getHttpServer())
      .get('/v1/content/audio-assets/not-a-uuid')
      .set('Authorization', `Bearer ${t}`)
      .expect(404);
  });
});
