import 'reflect-metadata';
import { ValidationPipe, type INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { PrismaClient } from '@prisma/client';
import { AppModule } from '../../src/app.module';
import { hash } from '@node-rs/argon2';
import { totpCode, totpCounter, TOTP_STEP_SECONDS } from '../../src/modules/identity/domain/totp';

/**
 * Admin 2FA e2e — GERÇEK HTTP + GERÇEK DB.
 *
 * NEDEN BİRİM TESTİ YETMEZ: bu projede iki kez, birim testleri YEŞİLKEN sistem
 * bozuktu (#118 refresh yarışı, #122 bayat önbellek). 2FA'da yanlış giden şey
 * sessizdir: korumanın KAPALI olması da 200 döner. Buradaki soru "kod doğrulanıyor
 * mu" değil, "2FA'sız giriş GERÇEKTEN reddediliyor mu".
 */
describe('Admin TOTP 2FA e2e (HTTP)', () => {
  let app: INestApplication;
  const prisma = new PrismaClient();
  const prefix = `totp${Date.now()}`;
  const createdUsers: string[] = [];
  const PASSWORD = 'correct-horse-battery-staple';

  /** 2FA'sı olmayan, parolası kurulu admin hesabı. */
  const adminAccount = async (): Promise<{ email: string; userId: string; token: string }> => {
    const email = `${prefix}-${Math.round(process.hrtime()[1])}@nocta.test`;
    const reg = await request(app.getHttpServer())
      .post('/v1/auth/device')
      .send({ fingerprint: `${prefix}-${Math.round(process.hrtime()[1])}`, platform: 'ios' })
      .expect(201);
    createdUsers.push(reg.body.userId);
    await prisma.users.update({
      where: { id: reg.body.userId },
      data: {
        kind: 'admin',
        roles: ['owner'],
        email,
        password_hash: await hash(PASSWORD, { memoryCost: 19456, timeCost: 2, parallelism: 1 }),
      },
    });
    const login = await request(app.getHttpServer())
      .post('/v1/auth/admin/login')
      .send({ email, password: PASSWORD })
      .expect(200);
    return { email, userId: reg.body.userId, token: login.body.accessToken };
  };

  /**
   * Kurulumu tamamlanmış (onaylanmış) 2FA.
   *
   * ONAY BİR ÖNCEKİ ADIMIN KODUYLA yapılır (now - 30 sn). Sebebi tekrar kapısının
   * KENDİSİ: onay, kullandığı sayacı yakar. Şimdiki kodla onaylasaydık, ardından
   * şimdiki kodla yapılan giriş "tekrar" sayılıp reddedilirdi ve testler 2FA'yı
   * değil kendi kurdukları tuzağı ölçerdi. Bir önceki adım (±1 pencere içinde)
   * kabul edilir ve şimdiki sayacı giriş için serbest bırakır.
   *
   * Bu aynı zamanda gerçek bir ÜRÜN davranışı: 2FA'yı onaylayan kullanıcı o kodla
   * hemen giriş yapamaz — ama zaten oturumu vardır, yeniden girmesi gerekmez.
   */
  const enrolledAccount = async () => {
    const acc = await adminAccount();
    const enroll = await request(app.getHttpServer())
      .post('/v1/auth/admin/totp/enroll')
      .set('Authorization', `Bearer ${acc.token}`)
      .expect(200);
    const secret: string = enroll.body.secret;

    await request(app.getHttpServer())
      .post('/v1/auth/admin/totp/confirm')
      .set('Authorization', `Bearer ${acc.token}`)
      .send({ code: totpCode(secret, Date.now() - TOTP_STEP_SECONDS * 1000) })
      .expect(204);
    return { ...acc, secret };
  };

  const login = (email: string, body: Record<string, unknown> = {}) =>
    request(app.getHttpServer())
      .post('/v1/auth/admin/login')
      .send({ email, password: PASSWORD, ...body });

  const originalLoginLimit = process.env.ADMIN_LOGIN_LIMIT;

  beforeAll(async () => {
    // Admin girişi 5/dk ile sınırlı (#115) — DOĞRU bir üretim davranışı, ama bu dosya
    // tek bir IP'den onlarca giriş yapıyor ve 429'a takılıyordu. Limiti test için
    // yükseltiyoruz; ölçtüğümüz şey 2FA, kaba kuvvet limiti DEĞİL (onun kendi testi var).
    //
    // Değer `process.env`den İSTEK ANINDA okunur (Resolvable, bkz. auth.controller.ts) —
    // bu yüzden burada set etmek yeterli ve test kendi kendine yeter: CI'da ek env
    // gerekmez. Süreç geneline sızmasın diye afterAll'da geri alınır.
    process.env.ADMIN_LOGIN_LIMIT = '500';

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
    if (originalLoginLimit === undefined) {
      delete process.env.ADMIN_LOGIN_LIMIT;
    } else {
      process.env.ADMIN_LOGIN_LIMIT = originalLoginLimit;
    }
    if (createdUsers.length > 0) {
      await prisma.users.deleteMany({ where: { id: { in: createdUsers } } });
    }
    await prisma.$disconnect();
    await app.close();
  });

  it('kurulum otpauth URI + anahtar döner; 2FA HENÜZ zorunlu değil', async () => {
    const acc = await adminAccount();
    const res = await request(app.getHttpServer())
      .post('/v1/auth/admin/totp/enroll')
      .set('Authorization', `Bearer ${acc.token}`)
      .expect(200);

    expect(res.body.secret).toMatch(/^[A-Z2-7]{32}$/);
    expect(res.body.otpauthUri).toContain(`secret=${res.body.secret}`);
    // Etiket TOKEN'daki hesabın e-postası — istemcinin verdiği değil.
    expect(res.body.otpauthUri).toContain(encodeURIComponent(acc.email));

    // ÇEKİRDEK: onaylanmadan zorunlu OLMAMALI — yoksa kurulumu yarıda bırakan
    // kullanıcı kendini kalıcı kilitlerdi.
    await login(acc.email).expect(200);
  });

  it('ÇEKİRDEK: 2FA onaylandıktan sonra KODSUZ giriş REDDEDİLİR', async () => {
    const acc = await enrolledAccount();
    // Parola DOĞRU. Koruma çalışmıyorsa burası 200 döner ve 2FA sessizce kapalıdır.
    const res = await login(acc.email).expect(401);
    expect(res.body.code).toBe('totp_required');
  });

  it('doğru kodla giriş 200', async () => {
    const acc = await enrolledAccount();
    const res = await login(acc.email, { totpCode: totpCode(acc.secret, Date.now()) }).expect(200);
    expect(res.body.accessToken).toBeTruthy();
  });

  it('yanlış kod 401 (parola doğru olsa bile)', async () => {
    const acc = await enrolledAccount();
    const wrong = totpCode(acc.secret, Date.now()) === '000000' ? '111111' : '000000';
    const res = await login(acc.email, { totpCode: wrong }).expect(401);
    expect(res.body.code).toBe('invalid_totp');
  });

  it('ÇEKİRDEK: aynı kod İKİNCİ KEZ kullanılamaz (RFC 6238 §5.2 tekrar saldırısı)', async () => {
    const acc = await enrolledAccount();
    const code = totpCode(acc.secret, Date.now());

    await login(acc.email, { totpCode: code }).expect(200);
    // Kodu omuz üstünden gören biri 30 sn içinde aynısıyla girebilirdi.
    const replay = await login(acc.email, { totpCode: code }).expect(401);
    expect(replay.body.code).toBe('invalid_totp');
  });

  it("tekrar kapısı sayacı DB'ye yazar (süreç yeniden başlasa da korunur)", async () => {
    const acc = await enrolledAccount();
    const at = Date.now();
    await login(acc.email, { totpCode: totpCode(acc.secret, at) }).expect(200);

    // Bellekte değil DB'de: sayaç yalnızca RAM'de tutulsaydı yeniden başlatma
    // tekrar saldırısı penceresini geri açardı.
    const row = await prisma.users.findUnique({ where: { id: acc.userId } });
    expect(Number(row?.totp_last_counter)).toBe(totpCounter(at));
  });

  it('BAŞARISIZ kod denemesi sayacı İLERLETMEZ (meşru kod yanmaz)', async () => {
    const acc = await enrolledAccount();
    const before = await prisma.users.findUnique({ where: { id: acc.userId } });

    await login(acc.email, { totpCode: '000000' }).expect(401);

    const after = await prisma.users.findUnique({ where: { id: acc.userId } });
    expect(after?.totp_last_counter).toEqual(before?.totp_last_counter);
  });

  it("onaylı 2FA yeniden KURULAMAZ (409) — saldırgan 2FA'yı devralamaz", async () => {
    const acc = await enrolledAccount();
    const res = await request(app.getHttpServer())
      .post('/v1/auth/admin/totp/enroll')
      .set('Authorization', `Bearer ${acc.token}`)
      .expect(409);
    expect(res.body.code).toBe('totp_already_enabled');
  });

  it("yanlış onay kodu 2FA'yı ETKİNLEŞTİRMEZ (kilitlenme önlemi)", async () => {
    const acc = await adminAccount();
    await request(app.getHttpServer())
      .post('/v1/auth/admin/totp/enroll')
      .set('Authorization', `Bearer ${acc.token}`)
      .expect(200);

    await request(app.getHttpServer())
      .post('/v1/auth/admin/totp/confirm')
      .set('Authorization', `Bearer ${acc.token}`)
      .send({ code: '000000' })
      .expect(401);

    const row = await prisma.users.findUnique({ where: { id: acc.userId } });
    expect(row?.totp_confirmed_at).toBeNull();
    // Kod tutmadıysa giriş eskisi gibi çalışmalı: kullanıcı kilitlenmemeli.
    await login(acc.email).expect(200);
  });

  it('onay kodu girişte TEKRAR kullanılamaz (onay sayacı yazılır)', async () => {
    const acc = await adminAccount();
    const enroll = await request(app.getHttpServer())
      .post('/v1/auth/admin/totp/enroll')
      .set('Authorization', `Bearer ${acc.token}`)
      .expect(200);
    const code = totpCode(enroll.body.secret, Date.now());

    await request(app.getHttpServer())
      .post('/v1/auth/admin/totp/confirm')
      .set('Authorization', `Bearer ${acc.token}`)
      .send({ code })
      .expect(204);

    // Onay ile sayaç ATOMİK yazılmasaydı bu kod bir kez daha geçerdi.
    const res = await login(acc.email, { totpCode: code }).expect(401);
    expect(res.body.code).toBe('invalid_totp');
  });

  it('yeni kurulum eski sayacı SIFIRLAR (yoksa yeni anahtar kurulamazdı)', async () => {
    const acc = await adminAccount();
    // Yarıda kalmış kurulum + ileri bir sayaç izi bırak.
    await request(app.getHttpServer())
      .post('/v1/auth/admin/totp/enroll')
      .set('Authorization', `Bearer ${acc.token}`)
      .expect(200);
    await prisma.users.update({
      where: { id: acc.userId },
      data: { totp_last_counter: BigInt(totpCounter(Date.now()) + 500) },
    });

    const second = await request(app.getHttpServer())
      .post('/v1/auth/admin/totp/enroll')
      .set('Authorization', `Bearer ${acc.token}`)
      .expect(200);

    const row = await prisma.users.findUnique({ where: { id: acc.userId } });
    expect(row?.totp_last_counter).toBeNull();

    // Sayaç sıfırlanmasaydı yeni anahtarın kodları "kullanılmış" sayılırdı.
    await request(app.getHttpServer())
      .post('/v1/auth/admin/totp/confirm')
      .set('Authorization', `Bearer ${acc.token}`)
      .send({ code: totpCode(second.body.secret, Date.now()) })
      .expect(204);
  });

  describe('durum ucu (panel rozeti)', () => {
    const status = (token: string) =>
      request(app.getHttpServer())
        .get('/v1/auth/admin/totp')
        .set('Authorization', `Bearer ${token}`);

    it('kurulum yapılmamış → enabled:false, pending:false', async () => {
      const acc = await adminAccount();
      const res = await status(acc.token).expect(200);
      expect(res.body).toEqual({ enabled: false, pending: false });
    });

    it('ÇEKİRDEK: yarıda kalmış kurulum → pending, enabled DEĞİL', async () => {
      // "Anahtar var" ile "2FA etkin" AYNI ŞEY DEĞİL. Bunları birleştirmek, kod
      // üretemeyen kullanıcıyı "korunuyor" göstermek olurdu — yalan.
      const acc = await adminAccount();
      await request(app.getHttpServer())
        .post('/v1/auth/admin/totp/enroll')
        .set('Authorization', `Bearer ${acc.token}`)
        .expect(200);

      const res = await status(acc.token).expect(200);
      expect(res.body).toEqual({ enabled: false, pending: true });
    });

    it('onaylanmış kurulum → enabled', async () => {
      const acc = await enrolledAccount();
      const res = await status(acc.token).expect(200);
      expect(res.body).toEqual({ enabled: true, pending: false });
    });

    it('durum GİZLİ ANAHTARI sızdırmaz (rozet için gerekli değil)', async () => {
      const acc = await enrolledAccount();
      const res = await status(acc.token).expect(200);
      expect(JSON.stringify(res.body)).not.toContain(acc.secret);
    });

    it('kimlik doğrulaması ister (401)', async () => {
      await request(app.getHttpServer()).get('/v1/auth/admin/totp').expect(401);
    });
  });

  it('biçimsiz kod doğrulama katmanında elenir (400)', async () => {
    const acc = await enrolledAccount();
    await login(acc.email, { totpCode: '12345' }).expect(400);
    await login(acc.email, { totpCode: 'abcdef' }).expect(400);
  });

  it('2FA kurulumu kimlik doğrulaması ister (401)', async () => {
    await request(app.getHttpServer()).post('/v1/auth/admin/totp/enroll').expect(401);
    await request(app.getHttpServer())
      .post('/v1/auth/admin/totp/confirm')
      .send({ code: '123456' })
      .expect(401);
  });

  it("ÇEKİRDEK: A kullanıcısı B'nin 2FA'sını kuramaz (CLAUDE.md §6)", async () => {
    const victim = await enrolledAccount();
    const attacker = await adminAccount();

    // Saldırgan kendi token'ıyla kurulum isteyince KENDİ hesabı etkilenir; kurban
    // dokunulmadan kalır. `sub` token'dan gelir — gövdeden alınsaydı devralınabilirdi.
    await request(app.getHttpServer())
      .post('/v1/auth/admin/totp/enroll')
      .set('Authorization', `Bearer ${attacker.token}`)
      .expect(200);

    const victimRow = await prisma.users.findUnique({ where: { id: victim.userId } });
    expect(victimRow?.totp_secret).toBe(victim.secret);
    expect(victimRow?.totp_confirmed_at).not.toBeNull();
  });

  it('saat kayması toleransı: BİR SONRAKİ adımın kodu kabul edilir', async () => {
    // İleri kayma yönü seçildi: geri yön (bir önceki adım) bu hesapta onay
    // tarafından zaten yakılmıştır (bkz. enrolledAccount) ve tekrar kapısına
    // takılırdı — yani "kabul edilmeli" beklentisi YANLIŞ olurdu.
    const acc = await enrolledAccount();
    await login(acc.email, {
      totpCode: totpCode(acc.secret, Date.now() + TOTP_STEP_SECONDS * 1000),
    }).expect(200);
  });
});
