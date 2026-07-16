import 'reflect-metadata';
import { ValidationPipe, type INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { PrismaClient } from '@prisma/client';
import { AppModule } from '../../src/app.module';

/**
 * Panel denetim izi e2e (gerçek DB).
 *
 * NEDEN: içerik yayınlanıyor/geri çekiliyor/tarifi değişiyordu ama KİMİN yaptığının
 * izi yoktu. Yanlış içerik canlıya çıktığında kimse hesap veremezdi — ve bu sonradan
 * eklenemeyen bir şey, çünkü GEÇMİŞ GERİ GELMEZ.
 */
describe('Admin denetim izi e2e (HTTP)', () => {
  let app: INestApplication;
  const prisma = new PrismaClient();
  const prefix = `adt${Date.now()}`;
  const createdUsers: string[] = [];

  const account = async (
    roles: string[],
  ): Promise<{ token: string; userId: string; email: string }> => {
    const email = `${prefix}-${Math.round(process.hrtime()[1])}@nocta.test`;
    const reg = await request(app.getHttpServer())
      .post('/v1/auth/device')
      .send({
        fingerprint: `adt-${Date.now()}-${Math.round(process.hrtime()[1])}`,
        platform: 'ios',
      })
      .expect(201);
    createdUsers.push(reg.body.userId);
    await prisma.users.update({
      where: { id: reg.body.userId },
      data: { kind: 'admin', roles, email },
    });
    const refreshed = await request(app.getHttpServer())
      .post('/v1/auth/refresh')
      .send({ refreshToken: reg.body.refreshToken })
      .expect(200);
    return { token: refreshed.body.accessToken, userId: reg.body.userId, email };
  };

  const auditFor = async (token: string, target: string) => {
    const res = await request(app.getHttpServer())
      .get('/v1/admin/audit')
      .set('Authorization', `Bearer ${token}`)
      .expect(200);
    return res.body.filter((e: { target: string }) => e.target === target);
  };

  const seed = async (
    slug: string,
    opts?: { recipe?: boolean; status?: string },
  ): Promise<void> => {
    await prisma.soundscapes.create({
      data: {
        slug,
        title_i18n: { en: slug },
        engine_params: opts?.recipe
          ? { schemaVersion: 1, layers: [{ id: 'a', type: 'pink', gain: 0.5 }] }
          : {},
        layer_defs: [],
        status: (opts?.status ?? 'draft') as 'draft' | 'published',
      },
    });
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
    await prisma.admin_audit_log.deleteMany({ where: { target: { startsWith: prefix } } });
    await prisma.soundscapes.deleteMany({ where: { slug: { startsWith: prefix } } });
    if (createdUsers.length > 0) {
      await prisma.users.deleteMany({ where: { id: { in: createdUsers } } });
    }
    await prisma.$disconnect();
    await app.close();
  });

  it('oluşturma ize yazılır — KİM, NE, NEYE', async () => {
    const { token, email } = await account(['editor']);
    const slug = `${prefix}-create`;

    await request(app.getHttpServer())
      .post('/v1/admin/soundscapes')
      .set('Authorization', `Bearer ${token}`)
      .send({ slug, titleEn: 'Audited' })
      .expect(201);

    const entries = await auditFor(token, slug);
    expect(entries).toHaveLength(1);
    expect(entries[0].action).toBe('soundscape.create');
    expect(entries[0].actorEmail).toBe(email);
  });

  it('yayınlama ve geri çekme AYRI kayıtlar (zincir okunabilir)', async () => {
    const { token } = await account(['owner']);
    const slug = `${prefix}-chain`;
    await seed(slug, { recipe: true });

    await request(app.getHttpServer())
      .post(`/v1/admin/soundscapes/${slug}/publish`)
      .set('Authorization', `Bearer ${token}`)
      .expect(200);
    await request(app.getHttpServer())
      .post(`/v1/admin/soundscapes/${slug}/unpublish`)
      .set('Authorization', `Bearer ${token}`)
      .expect(200);

    const actions = (await auditFor(token, slug)).map((e: { action: string }) => e.action);
    // En yeniden eskiye.
    expect(actions).toEqual(['soundscape.unpublish', 'soundscape.publish']);
  });

  it('ÇEKİRDEK: REDDEDİLEN işlem ize YAZILMAZ (yalandan beter olurdu)', async () => {
    // Boş tarifli kayıt yayınlanamaz (409). "Yayınladı" diye kaydetmek, izi
    // güvenilmez kılardı — iz varsa doğru olmalı.
    const { token } = await account(['editor']);
    const slug = `${prefix}-rejected`;
    await seed(slug); // tarif YOK

    await request(app.getHttpServer())
      .post(`/v1/admin/soundscapes/${slug}/publish`)
      .set('Authorization', `Bearer ${token}`)
      .expect(409);

    expect(await auditFor(token, slug)).toHaveLength(0);
  });

  it('YETKİSİZ işlem de ize yazılmaz (analyst 403)', async () => {
    const { token: analystToken } = await account(['analyst']);
    const { token: ownerToken } = await account(['owner']);
    const slug = `${prefix}-forbidden`;
    await seed(slug, { recipe: true });

    await request(app.getHttpServer())
      .post(`/v1/admin/soundscapes/${slug}/publish`)
      .set('Authorization', `Bearer ${analystToken}`)
      .expect(403);

    expect(await auditFor(ownerToken, slug)).toHaveLength(0);
  });

  it('tarif değişikliği ize yazılır (NE değişti, değerler DEĞİL)', async () => {
    const { token } = await account(['editor']);
    const slug = `${prefix}-recipe`;
    await seed(slug);

    await request(app.getHttpServer())
      .put(`/v1/admin/soundscapes/${slug}/recipe`)
      .set('Authorization', `Bearer ${token}`)
      .send({ schemaVersion: 1, layers: [{ id: 'a', type: 'pink', gain: 0.5 }] })
      .expect(200);

    const entries = await auditFor(token, slug);
    expect(entries[0].action).toBe('soundscape.recipe');
    expect(entries[0].details).toEqual({ layers: 1 });
  });

  it('güncelleme izinde NE değişti yazar, DEĞERLER yazmaz', async () => {
    const { token } = await account(['editor']);
    const slug = `${prefix}-update`;
    await seed(slug);

    await request(app.getHttpServer())
      .patch(`/v1/admin/soundscapes/${slug}`)
      .set('Authorization', `Bearer ${token}`)
      .send({ titleEn: 'Gizli Başlık' })
      .expect(200);

    const entries = await auditFor(token, slug);
    expect(entries[0].details).toEqual({ changed: ['title'] });
    expect(JSON.stringify(entries[0])).not.toContain('Gizli Başlık');
  });

  it('ÇEKİRDEK: aktör hesabı SİLİNSE de iz kalır (denetim izinin bütün anlamı)', async () => {
    const { token, userId, email } = await account(['editor']);
    const slug = `${prefix}-ghost`;

    await request(app.getHttpServer())
      .post('/v1/admin/soundscapes')
      .set('Authorization', `Bearer ${token}`)
      .send({ slug, titleEn: 'Ghost' })
      .expect(201);

    await prisma.users.delete({ where: { id: userId } });
    createdUsers.splice(createdUsers.indexOf(userId), 1);

    // FK ON DELETE SET NULL + actor_email dondurulmuş → "kim yaptı" hâlâ okunur.
    const { token: other } = await account(['owner']);
    const entries = await auditFor(other, slug);
    expect(entries).toHaveLength(1);
    expect(entries[0].actorEmail).toBe(email);
  });

  it('analyst izi OKUYABİLİR ("ne oldu?" salt okunurluğa aykırı değil)', async () => {
    const { token } = await account(['analyst']);
    await request(app.getHttpServer())
      .get('/v1/admin/audit')
      .set('Authorization', `Bearer ${token}`)
      .expect(200);
  });

  it('mobil token → 403; token yok → 401', async () => {
    const dev = await request(app.getHttpServer())
      .post('/v1/auth/device')
      .send({ fingerprint: `adt-dev-${Date.now()}`, platform: 'ios' })
      .expect(201);
    createdUsers.push(dev.body.userId);
    await request(app.getHttpServer())
      .get('/v1/admin/audit')
      .set('Authorization', `Bearer ${dev.body.accessToken}`)
      .expect(403);
    await request(app.getHttpServer()).get('/v1/admin/audit').expect(401);
  });

  it('createdAt ISO 8601 UTC (CLAUDE.md §4)', async () => {
    const { token } = await account(['editor']);
    const slug = `${prefix}-time`;
    await request(app.getHttpServer())
      .post('/v1/admin/soundscapes')
      .set('Authorization', `Bearer ${token}`)
      .send({ slug, titleEn: 'Time' })
      .expect(201);

    const entries = await auditFor(token, slug);
    expect(entries[0].createdAt).toMatch(/^\d{4}-\d{2}-\d{2}T.*Z$/);
  });
});
