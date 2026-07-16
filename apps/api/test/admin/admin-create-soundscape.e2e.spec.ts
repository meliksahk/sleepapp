import 'reflect-metadata';
import { ValidationPipe, type INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { PrismaClient } from '@prisma/client';
import { AppModule } from '../../src/app.module';

/**
 * Taslak oluşturma + ROL DARALTMASI e2e (gerçek DB).
 *
 * ÇEKİRDEK İDDİA: `analyst` SALT OKUNUR bir roldür (CLAUDE.md §3.3) — içeriği
 * görebilir ama YAZAMAZ. #119'a kadar admin uçlarının hepsi sınıf düzeyinde tüm
 * panel rollerine açıktı; ilk yazma ucu bunu daraltmak zorundaydı.
 */
describe('Admin taslak oluşturma e2e (HTTP)', () => {
  let app: INestApplication;
  const prisma = new PrismaClient();
  const prefix = `new${Date.now()}`;
  const createdUsers: string[] = [];

  /** Belirli rollerle admin hesabı + panel (aud=admin) token'ı. */
  const accountFor = async (roles: string[]): Promise<{ token: string; userId: string }> => {
    const reg = await request(app.getHttpServer())
      .post('/v1/auth/device')
      .send({
        fingerprint: `crt-${Date.now()}-${Math.round(process.hrtime()[1])}`,
        platform: 'ios',
      })
      .expect(201);
    createdUsers.push(reg.body.userId);
    await prisma.users.update({ where: { id: reg.body.userId }, data: { kind: 'admin', roles } });
    const refreshed = await request(app.getHttpServer())
      .post('/v1/auth/refresh')
      .send({ refreshToken: reg.body.refreshToken })
      .expect(200);
    return { token: refreshed.body.accessToken, userId: reg.body.userId };
  };

  const tokenFor = async (roles: string[]): Promise<string> => (await accountFor(roles)).token;

  const create = (token: string, body: Record<string, unknown>) =>
    request(app.getHttpServer())
      .post('/v1/admin/soundscapes')
      .set('Authorization', `Bearer ${token}`)
      .send(body);

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
    await prisma.soundscapes.deleteMany({ where: { slug: { startsWith: prefix } } });
    if (createdUsers.length > 0) {
      await prisma.users.deleteMany({ where: { id: { in: createdUsers } } });
    }
    await prisma.$disconnect();
    await app.close();
  });

  it('editor oluşturabilir → 201, durum DRAFT, denetim izi ÇAĞIRANIN kendisi', async () => {
    const { token, userId } = await accountFor(['editor']);
    const res = await create(token, {
      slug: `${prefix}-editor`,
      titleEn: 'Editor Made This',
      archetypeAffinity: ['deep-ocean'],
    }).expect(201);

    expect(res.body.status).toBe('draft'); // yayınlamak AYRI ve bilinçli bir adım
    expect(res.body.title).toBe('Editor Made This');
    expect(res.body.archetypeAffinity).toEqual(['deep-ocean']);

    // Denetim izi TOKEN'dan gelmeli, gövdeden değil: istemcinin "ben şuyum" demesine
    // güvenmek izi işe yaramaz kılardı. Bu yüzden çağıranın gerçek id'siyle eşleşmeli.
    const row = await prisma.soundscapes.findUnique({ where: { slug: `${prefix}-editor` } });
    expect(row?.created_by).toBe(userId);
  });

  it('owner oluşturabilir → 201', async () => {
    const token = await tokenFor(['owner']);
    await create(token, { slug: `${prefix}-owner`, titleEn: 'Owner Made This' }).expect(201);
  });

  it('ÇEKİRDEK İDDİA: analyst YAZAMAZ → 403 (salt okunur rol)', async () => {
    const token = await tokenFor(['analyst']);
    await create(token, { slug: `${prefix}-analyst`, titleEn: 'Should Not Exist' }).expect(403);

    const row = await prisma.soundscapes.findUnique({ where: { slug: `${prefix}-analyst` } });
    expect(row).toBeNull(); // 403 döndü ama yazdıysa faciadır — DB'den doğrula
  });

  it('analyst yine de OKUYABİLİR (daraltma yalnızca yazmada)', async () => {
    const token = await tokenFor(['analyst']);
    await request(app.getHttpServer())
      .get('/v1/admin/soundscapes')
      .set('Authorization', `Bearer ${token}`)
      .expect(200);
  });

  it('support da yazamaz → 403 (içerik editörü değil)', async () => {
    const token = await tokenFor(['support']);
    await create(token, { slug: `${prefix}-support`, titleEn: 'Nope' }).expect(403);
  });

  it('mobil (cihaz) token → 403', async () => {
    const reg = await request(app.getHttpServer())
      .post('/v1/auth/device')
      .send({ fingerprint: `mob-${Date.now()}`, platform: 'ios' })
      .expect(201);
    createdUsers.push(reg.body.userId);
    await create(reg.body.accessToken, { slug: `${prefix}-mob`, titleEn: 'Nope' }).expect(403);
  });

  it('aynı slug ikinci kez → 409 (ilk kayıt bozulmaz)', async () => {
    const token = await tokenFor(['editor']);
    await create(token, { slug: `${prefix}-dup`, titleEn: 'First' }).expect(201);
    const res = await create(token, { slug: `${prefix}-dup`, titleEn: 'Second' }).expect(409);
    expect(res.body.code).toBe('slug_taken');

    const row = await prisma.soundscapes.findUnique({ where: { slug: `${prefix}-dup` } });
    expect((row?.title_i18n as { en: string }).en).toBe('First');
  });

  it('geçersiz slug → 400 (URL güvenliği)', async () => {
    const token = await tokenFor(['editor']);
    // Slug derin linkte yaşar (`/a/{slug}`, `/library/{slug}`) → kaçış gerektiren
    // hiçbir şey giremez. Büyük harf İSTİSNA: küçültmesi belirsiz değil, o yüzden
    // reddetmek yerine normalize ediliyor (aşağıdaki test). Boşluk/simge öyle değil.
    await create(token, { slug: `${prefix} Bad Slug`, titleEn: 'x' }).expect(400);
    await create(token, { slug: `${prefix}_alt_cizgi`, titleEn: 'x' }).expect(400);
    await create(token, { slug: `${prefix}/yol`, titleEn: 'x' }).expect(400);
  });

  it('slug NORMALİZE edilir: baştaki/sondaki boşluk kırpılır, büyük harf küçültülür', async () => {
    const token = await tokenFor(['editor']);
    const res = await create(token, {
      slug: `  ${prefix}-TRIMMED  `,
      titleEn: 'Trimmed',
    }).expect(201);
    expect(res.body.slug).toBe(`${prefix}-trimmed`);
  });

  it('bilinmeyen alan reddedilir (whitelist) — ör. status enjekte edilemez', async () => {
    // "status: published" gövdeden geçebilseydi, taslak zorunluluğu delinirdi.
    const token = await tokenFor(['editor']);
    await create(token, {
      slug: `${prefix}-inject`,
      titleEn: 'Inject',
      status: 'published',
    }).expect(400);
  });
});
