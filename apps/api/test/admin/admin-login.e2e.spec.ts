import 'reflect-metadata';
import { ValidationPipe, type INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { PrismaClient } from '@prisma/client';
import { Algorithm, hash } from '@node-rs/argon2';
import { AppModule } from '../../src/app.module';

/**
 * Admin parola girişi e2e (gerçek DB + gerçek argon2id).
 *
 * Bu akış #112 (rol kapısı) ve #113 (audience) ile birlikte tamamlanır: buraya
 * kadar admin token'ı ancak DB'yi elle kurcalayarak alınabiliyordu.
 */
describe('Admin girişi e2e (HTTP)', () => {
  let app: INestApplication;
  const prisma = new PrismaClient();
  const created: string[] = [];

  const PASSWORD = 'correct-horse-battery';
  const email = `admin-login-${Date.now()}@nocta.test`;

  const makeUser = async (data: {
    email: string;
    kind: 'admin' | 'registered';
    password?: string;
    roles?: string[];
  }): Promise<string> => {
    const row = await prisma.users.create({
      data: {
        email: data.email,
        kind: data.kind,
        roles: data.roles ?? ['owner'],
        password_hash: data.password
          ? await hash(data.password, {
              algorithm: Algorithm.Argon2id,
              memoryCost: 19456,
              timeCost: 2,
              parallelism: 1,
            })
          : null,
      },
    });
    created.push(row.id);
    return row.id;
  };

  const login = (body: Record<string, unknown>) =>
    request(app.getHttpServer()).post('/v1/auth/admin/login').send(body);

  const originalLoginLimit = process.env.ADMIN_LOGIN_LIMIT;

  beforeAll(async () => {
    // Bu dosya KİMLİK DOĞRULAMAYI test eder, limiti değil: 5/dk'lık gerçek limit
    // burada 429 üretirdi. Limitin KENDİSİ kendi e2e'sinde test edilir
    // (admin-login-throttle.e2e.spec.ts) → kapsam dışı kalmıyor.
    process.env.ADMIN_LOGIN_LIMIT = '100000';
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
    process.env.ADMIN_LOGIN_LIMIT = originalLoginLimit;
    if (created.length > 0) {
      await prisma.users.deleteMany({ where: { id: { in: created } } });
    }
    await prisma.$disconnect();
    await app.close();
  });

  it('doğru parola → oturum açılır ve token PANELE girer (uçtan uca)', async () => {
    const userId = await makeUser({ email, kind: 'admin', password: PASSWORD });
    const res = await login({ email, password: PASSWORD }).expect(200);
    expect(res.body.userId).toBe(userId);

    // Asıl iddia: bu token gerçekten panel anahtarı — DB kurcalamadan.
    const me = await request(app.getHttpServer())
      .get('/v1/admin/me')
      .set('Authorization', `Bearer ${res.body.accessToken}`)
      .expect(200);
    expect(me.body).toEqual({ userId, roles: ['owner'] });
  });

  it('yanlış parola → 401', async () => {
    await login({ email, password: 'wrong-password-x' }).expect(401);
  });

  it('e-posta büyük/küçük harf duyarsız (kullanıcı ADMIN@ yazınca kilitlenmez)', async () => {
    await login({ email: email.toUpperCase(), password: PASSWORD }).expect(200);
  });

  it('olmayan hesap → 401 (var olan hesabın yanlış parolasıyla AYNI yanıt)', async () => {
    const missing = await login({ email: `yok-${Date.now()}@nocta.test`, password: PASSWORD });
    const wrongPass = await login({ email, password: 'wrong-password-x' });
    expect(missing.status).toBe(401);
    // Kullanıcı sayımı: iki yol ayırt EDİLEMEMELİ.
    expect(missing.body).toEqual(wrongPass.body);
  });

  it('admin OLMAYAN hesap doğru parolayla bile giremez', async () => {
    const other = `notadmin-${Date.now()}@nocta.test`;
    await makeUser({ email: other, kind: 'registered', password: PASSWORD });
    await login({ email: other, password: PASSWORD }).expect(401);
  });

  it('parolası kurulmamış admin giremez (davetli ama henüz kurmamış hesap)', async () => {
    const pending = `pending-${Date.now()}@nocta.test`;
    await makeUser({ email: pending, kind: 'admin' });
    await login({ email: pending, password: PASSWORD }).expect(401);
  });

  it('silinmiş admin giremez (kaskad silme öncesi pencere)', async () => {
    const gone = `gone-${Date.now()}@nocta.test`;
    const id = await makeUser({ email: gone, kind: 'admin', password: PASSWORD });
    await prisma.users.update({ where: { id }, data: { deleted_at: new Date() } });
    await login({ email: gone, password: PASSWORD }).expect(401);
  });

  it('kısa parola DTO düzeyinde reddedilir (400, argon2 maliyeti ödenmez)', async () => {
    await login({ email, password: 'kisa' }).expect(400);
  });

  it('parola HİÇBİR yanıtta geri dönmez', async () => {
    const res = await login({ email, password: PASSWORD }).expect(200);
    expect(JSON.stringify(res.body)).not.toContain(PASSWORD);
    expect(JSON.stringify(res.body)).not.toContain('argon2');
  });
});
