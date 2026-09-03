import 'reflect-metadata';
import { ValidationPipe, type INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { PrismaClient } from '@prisma/client';
import { AppModule } from '../../src/app.module';
import { CACHE } from '../../src/shared/cache/cache.port';
import { InMemoryCache } from '../../src/shared/cache/in-memory-cache';
import { USER_SOUND_STORAGE, type UserSoundStorage } from '../../src/modules/community';
import { resetThrottleCounters } from '../support/reset-throttle';

/**
 * Topluluk sesleri e2e (HTTP) — gerçek DB + SAHTE depolama.
 *
 * ## Neden sahte storage
 *
 * S3/MinIO erişimi bu spec'in konusu DEĞİL (o canlı doğrulama ayrıdır); konu
 * yetki ve durum makinesidir. `USER_SOUND_STORAGE` portu override edilir:
 * presigned URL sahte üretilir, HEAD bellekteki nesneye bakar.
 *
 * ## Yetkilendirme testleri neyi kanıtlıyor (CLAUDE.md §6)
 *
 * - **Sahiplik izolasyonu:** kullanıcı B, A'nın sesine `uploaded` çağıramaz.
 *   Yanıt 404'tür — 403 DEĞİL; "böyle bir id var ve başkasına ait" ifşası yapılmaz.
 * - **Rol kapısı:** moderasyon uçları owner/editor dışına 403 verir (analyst
 *   salt-okunurdur, sıradan cihaz kullanıcısı hiçbir rol taşımaz).
 * - **Moderasyon = katalog kapısı:** onaylanmamış ses `/v1/content/audio-assets`
 *   listesinde ASLA görünmez; onaylanınca GÖRÜNÜR (köprü testi).
 */
class FakeUserSoundStorage implements UserSoundStorage {
  objects = new Map<string, number>();

  async presignedPutUrl(bucket: string, key: string): Promise<string> {
    return `https://minio.test/${bucket}/${encodeURIComponent(key)}?sig=fake`;
  }

  async headObject(_bucket: string, key: string): Promise<{ sizeBytes: number } | null> {
    const size = this.objects.get(key);
    return size === undefined ? null : { sizeBytes: size };
  }

  async presignedGetUrl(bucket: string, key: string): Promise<string> {
    return `https://minio.test/get/${bucket}/${encodeURIComponent(key)}?sig=fake`;
  }

  async listKeys(_bucket: string, prefix: string) {
    return [...this.objects.keys()]
      .filter((k) => k.startsWith(prefix))
      .map((k) => ({ key: k, lastModified: new Date() }));
  }

  async removeObject(_bucket: string, key: string): Promise<void> {
    this.objects.delete(key);
  }
}

describe('Community sounds e2e (HTTP)', () => {
  let app: INestApplication;
  const prisma = new PrismaClient();
  const fake = new FakeUserSoundStorage();
  const soundIds: string[] = [];
  const userIds: string[] = [];

  /** Sıradan cihaz token'ı. */
  const deviceToken = async (): Promise<{ token: string; userId: string }> => {
    const res = await request(app.getHttpServer())
      .post('/v1/auth/device')
      .send({
        fingerprint: `community-e2e-${Date.now()}-${Math.round(process.hrtime()[1])}`,
        platform: 'android',
      })
      .expect(201);
    userIds.push(res.body.userId);
    return { token: res.body.accessToken as string, userId: res.body.userId as string };
  };

  /** Rol verilmiş admin token'ı (device → DB rolü → refresh ile yeni claim). */
  const adminToken = async (roles: string[]): Promise<string> => {
    const reg = await request(app.getHttpServer())
      .post('/v1/auth/device')
      .send({
        fingerprint: `community-admin-${Date.now()}-${Math.round(process.hrtime()[1])}`,
        platform: 'ios',
      })
      .expect(201);
    userIds.push(reg.body.userId);
    await prisma.users.update({
      where: { id: reg.body.userId },
      data: { kind: 'admin', roles },
    });
    const refreshed = await request(app.getHttpServer())
      .post('/v1/auth/refresh')
      .send({ refreshToken: reg.body.refreshToken })
      .expect(200);
    return refreshed.body.accessToken as string;
  };

  const createSound = (token: string, body: Record<string, unknown>) =>
    request(app.getHttpServer())
      .post('/v1/me/sounds')
      .set('Authorization', `Bearer ${token}`)
      .send(body as object);

  // Slot açma ucunda @Throttle(10/saat) VARDIR (spam freni). Testler tek IP'den
  // koştuğu için sayaçlar her testten önce sıfırlanır — reset-throttle.ts'teki
  // "üçüncü kez düşmeyelim" kuralının uygulanışı.
  beforeEach(resetThrottleCounters);

  beforeAll(async () => {
    await prisma.$connect();
    const moduleRef = await Test.createTestingModule({ imports: [AppModule] })
      .overrideProvider(CACHE)
      .useValue(new InMemoryCache())
      .overrideProvider(USER_SOUND_STORAGE)
      .useValue(fake)
      .compile();
    app = moduleRef.createNestApplication();
    app.setGlobalPrefix('v1', { exclude: ['health'] });
    app.useGlobalPipes(
      new ValidationPipe({ whitelist: true, forbidNonWhitelisted: true, transform: true }),
    );
    await app.init();
  });

  afterAll(async () => {
    await prisma.user_sounds.deleteMany({ where: { id: { in: soundIds } } });
    await prisma.$disconnect();
    await app.close();
  });

  it('token olmadan 401 (oluşturma ve listeleme)', async () => {
    await request(app.getHttpServer())
      .post('/v1/me/sounds')
      .send({ title: 'x', durationSeconds: 10 })
      .expect(401);
    await request(app.getHttpServer()).get('/v1/me/sounds').expect(401);
  });

  it('yükleme slotu açılır: pending kayıt + community/ prefixli anahtar + imzalı PUT URL', async () => {
    const { token } = await deviceToken();

    const res = await createSound(token, { title: 'Gece ormanı', durationSeconds: 600 }).expect(
      201,
    );

    expect(res.body.id).toBeTruthy();
    expect(res.body.uploadUrl).toContain('minio.test');
    expect(res.body.uploadUrl).toContain('community%2F');
    expect(res.body.expiresIn).toBeGreaterThan(0);

    const row = await prisma.user_sounds.findUnique({ where: { id: res.body.id } });
    expect(row).not.toBeNull();
    expect(row!.status).toBe('pending');
    expect(row!.storage_key.startsWith('community/')).toBe(true);
    soundIds.push(row!.id);
  });

  it.each([
    ['başlık boş', { title: '', durationSeconds: 10 }],
    ['başlık eksik', { durationSeconds: 10 }],
    ['süre sıfır', { title: 'x', durationSeconds: 0 }],
    ['süre çok uzun (>2h)', { title: 'x', durationSeconds: 8000 }],
  ])('%s → 400', async (_name, body) => {
    const { token } = await deviceToken();
    await createSound(token, body).expect(400);
  });

  it('uploaded: dosya depodayken doğrulanır, boyut yazılır, status pending KALIR', async () => {
    const { token } = await deviceToken();
    const slot = await createSound(token, { title: 'Dere', durationSeconds: 300 }).expect(201);
    soundIds.push(slot.body.id);
    const key = `community/${slot.body.userId ?? ''}`; // gerçek anahtar DB'den okunur
    const row = await prisma.user_sounds.findUnique({ where: { id: slot.body.id } });
    fake.objects.set(row!.storage_key, 2048 * 1024);

    await request(app.getHttpServer())
      .post(`/v1/me/sounds/${slot.body.id}/uploaded`)
      .set('Authorization', `Bearer ${token}`)
      .expect(200, { ok: true });

    const updated = await prisma.user_sounds.findUnique({ where: { id: slot.body.id } });
    expect(Number(updated!.byte_size)).toBe(2048 * 1024);
    expect(updated!.status).toBe('pending');
    void key;
  });

  it('uploaded: dosya YOKSA 422 (istemciye güvenilmez)', async () => {
    const { token } = await deviceToken();
    const slot = await createSound(token, { title: 'Yarım yükleme', durationSeconds: 60 }).expect(
      201,
    );
    soundIds.push(slot.body.id);
    await request(app.getHttpServer())
      .post(`/v1/me/sounds/${slot.body.id}/uploaded`)
      .set('Authorization', `Bearer ${token}`)
      .expect(422);
  });

  it('SAHİPLİK: B, A’nın sesine uploaded çağıramaz → 404 (varlık ifşa edilmez)', async () => {
    const a = await deviceToken();
    const b = await deviceToken();
    const slot = await createSound(a.token, { title: 'A’nın sesi', durationSeconds: 60 }).expect(
      201,
    );
    soundIds.push(slot.body.id);
    const row = await prisma.user_sounds.findUnique({ where: { id: slot.body.id } });
    fake.objects.set(row!.storage_key, 4096);

    await request(app.getHttpServer())
      .post(`/v1/me/sounds/${slot.body.id}/uploaded`)
      .set('Authorization', `Bearer ${b.token}`)
      .expect(404);
  });

  it('liste SADECE kendi satırlarını döner', async () => {
    const a = await deviceToken();
    const b = await deviceToken();
    const s1 = await createSound(a.token, { title: 'A-only', durationSeconds: 30 }).expect(201);
    soundIds.push(s1.body.id);
    const s2 = await createSound(b.token, { title: 'B-only', durationSeconds: 30 }).expect(201);
    soundIds.push(s2.body.id);

    const mineA = await request(app.getHttpServer())
      .get('/v1/me/sounds')
      .set('Authorization', `Bearer ${a.token}`)
      .expect(200);
    const titlesA = (mineA.body as Array<{ title: string }>).map((r) => r.title);
    expect(titlesA).toContain('A-only');
    expect(titlesA).not.toContain('B-only');
  });

  describe('moderasyon (admin)', () => {
    let editorToken = '';
    let pendingId = '';

    beforeAll(async () => {
      editorToken = await adminToken(['editor']);
      const owner = await deviceToken();
      const slot = await createSound(owner.token, {
        title: 'Onay adayı',
        durationSeconds: 45,
      }).expect(201);
      pendingId = slot.body.id;
      soundIds.push(pendingId);
      const row = await prisma.user_sounds.findUnique({ where: { id: pendingId } });
      // SOUND_MIN_BYTES (10 KB) ÜSTÜ olmalı — altı "boyut sınır dışı" 422 döner.
      fake.objects.set(row!.storage_key, 64 * 1024);
      await request(app.getHttpServer())
        .post(`/v1/me/sounds/${pendingId}/uploaded`)
        .set('Authorization', `Bearer ${owner.token}`)
        .expect(200);
    });

    it('sıradan cihaz token’ı 403 alır (rol yok)', async () => {
      const { token } = await deviceToken();
      await request(app.getHttpServer())
        .get('/v1/admin/community-sounds')
        .set('Authorization', `Bearer ${token}`)
        .expect(403);
    });

    it('analyst 403 alır (salt-okunur rol moderasyon yapamaz/göremez)', async () => {
      const analyst = await adminToken(['analyst']);
      await request(app.getHttpServer())
        .get('/v1/admin/community-sounds')
        .set('Authorization', `Bearer ${analyst}`)
        .expect(403);
    });

    it('editor bekleyenleri görür', async () => {
      const res = await request(app.getHttpServer())
        .get('/v1/admin/community-sounds?status=pending')
        .set('Authorization', `Bearer ${editorToken}`)
        .expect(200);
      const ids = (res.body as Array<{ id: string }>).map((r) => r.id);
      expect(ids).toContain(pendingId);
    });

    it('ÖNİZLEME: editor kısa ömürlü dinleme URL’i alır (3b)', async () => {
      const res = await request(app.getHttpServer())
        .get(`/v1/admin/community-sounds/${pendingId}/file`)
        .set('Authorization', `Bearer ${editorToken}`)
        .expect(200);
      expect(res.body.url).toContain('minio.test');
      // URL'de imza var (presigned): sorgu dizgisi boş olamaz.
      expect(res.body.url.includes('?')).toBe(true);
      expect(res.body.expiresIn).toBeGreaterThan(0);

      // Olmayan id → 404 (aynı mesaj, varlık ifşası yok).
      await request(app.getHttpServer())
        .get('/v1/admin/community-sounds/ffffffff-ffff-4000-8000-ffffffffffff/file')
        .set('Authorization', `Bearer ${editorToken}`)
        .expect(404);
    });

    it('ONAY: status approved olur ve katalogda GÖRÜNÜR (köprü kanıtı)', async () => {
      await request(app.getHttpServer())
        .post(`/v1/admin/community-sounds/${pendingId}/moderate`)
        .set('Authorization', `Bearer ${editorToken}`)
        .send({ decision: 'approve' })
        .expect(200);

      const row = await prisma.user_sounds.findUnique({ where: { id: pendingId } });
      expect(row!.status).toBe('approved');

      // Köprü: onaylı satır audio-assets kataloğunda listelenir VE detayı çözülür.
      const viewer = await deviceToken();
      const catalog = await request(app.getHttpServer())
        .get('/v1/content/audio-assets')
        .set('Authorization', `Bearer ${viewer.token}`)
        .expect(200);
      const entry = (catalog.body as Array<{ id: string; genre: string; license: string }>).find(
        (a) => a.id === pendingId,
      );
      expect(entry).toBeDefined();
      expect(entry!.genre).toBe('community');
      expect(entry!.license).toBe('user-upload');

      await request(app.getHttpServer())
        .get(`/v1/content/audio-assets/${pendingId}`)
        .set('Authorization', `Bearer ${viewer.token}`)
        .expect(200);
    });

    it('aynı kararı ikinci kez uygulamak 409 (audit izi bulanıklaşmaz)', async () => {
      await request(app.getHttpServer())
        .post(`/v1/admin/community-sounds/${pendingId}/moderate`)
        .set('Authorization', `Bearer ${editorToken}`)
        .send({ decision: 'approve' })
        .expect(409);
    });

    it('RED: gerekçesiz 400; gerekçeyle 200; red gerekçesi kullanıcıya görünür', async () => {
      const owner = await deviceToken();
      const slot = await createSound(owner.token, {
        title: 'Red adayı',
        durationSeconds: 20,
      }).expect(201);
      soundIds.push(slot.body.id);

      // Henüz dosya yüklenmemiş olsa da red edilebilir: pending her hâlde moderasyondadır.
      await request(app.getHttpServer())
        .post(`/v1/admin/community-sounds/${slot.body.id}/moderate`)
        .set('Authorization', `Bearer ${editorToken}`)
        .send({ decision: 'reject' })
        .expect(400);

      await request(app.getHttpServer())
        .post(`/v1/admin/community-sounds/${slot.body.id}/moderate`)
        .set('Authorization', `Bearer ${editorToken}`)
        .send({ decision: 'reject', rejectionReason: 'Telif belgesi eksik' })
        .expect(200);

      // Onaysız içerik katalogda ASLA görünmez (negatif kontrol).
      const viewer = await deviceToken();
      const catalog = await request(app.getHttpServer())
        .get('/v1/content/audio-assets')
        .set('Authorization', `Bearer ${viewer.token}`)
        .expect(200);
      expect((catalog.body as Array<{ id: string }>).some((a) => a.id === slot.body.id)).toBe(
        false,
      );

      // Red gerekçesi SADECE sahibine gösterilir.
      const mine = await request(app.getHttpServer())
        .get('/v1/me/sounds')
        .set('Authorization', `Bearer ${owner.token}`)
        .expect(200);
      const mineRow = (mine.body as Array<{ id: string; rejectionReason: string | null }>).find(
        (r) => r.id === slot.body.id,
      );
      expect(mineRow!.rejectionReason).toBe('Telif belgesi eksik');
    });
  });
});
