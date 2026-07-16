import { buildIdentityStack, MutableClock } from './harness';
import { RefreshTokenReuseError } from '../../src/modules/identity/domain/errors';

/**
 * Rotasyon yarışı toleransı (grace window).
 *
 * NEDEN: rotasyon, aynı token'la gelen ikinci isteği "çalıntı" sayıp AİLEYİ düşürür.
 * Ama iki sekmenin aynı anda yenilemesi meşrudur — sert kural meşru kullanıcıyı
 * sistemden atıyordu (#117'de fark edildi, panel middleware'i bu yüzden yenilemeyi
 * yalnızca gezintiyle sınırlamak zorunda kaldı).
 *
 * BU DOSYANIN ASIL BEKÇİLİĞİ: grace'in ÇIKIŞI BOZMADIĞI. Çıkış aileyi düşürür ve
 * tüm token'ların revokedAt'i "az önce" olur; naif bir grace, çıkıştan sonraki
 * 10sn içindeki refresh'i "yarış" sanıp YENİ OTURUM basardı → çıkış sessizce
 * çalışmaz olurdu. Aşağıdaki testler bunu sabitler.
 */
describe('Refresh grace window (yarış toleransı)', () => {
  const GRACE_MS = 10_000;

  it('YARIŞ: rotasyondan hemen sonra eski token → aile DÜŞMEZ, yeni oturum verilir', async () => {
    const s = await buildIdentityStack({ reuseGraceMs: GRACE_MS });
    const first = await s.registerDevice.execute({ fingerprint: 'race-1', platform: 'ios' });

    const tabA = await s.refreshSession.execute(first.refreshToken);
    // Sekme B aynı eski token'la geldi (yarış) — atılmamalı.
    const tabB = await s.refreshSession.execute(first.refreshToken);

    expect(tabB.userId).toBe(first.userId);
    expect(tabB.refreshToken).not.toBe(tabA.refreshToken);
    // A'nın token'ı da hâlâ yaşıyor: iki sekme de çalışmaya devam eder.
    await expect(s.refreshSession.execute(tabA.refreshToken)).resolves.toBeDefined();
  });

  it('PENCERE DIŞI: grace geçtikten sonra eski token → reuse, aile düşer', async () => {
    const clock = new MutableClock();
    const s = await buildIdentityStack({ reuseGraceMs: GRACE_MS, clock });
    const first = await s.registerDevice.execute({ fingerprint: 'race-2', platform: 'ios' });

    await s.refreshSession.execute(first.refreshToken);
    clock.advanceSeconds(11); // 10sn'lik pencere kapandı

    await expect(s.refreshSession.execute(first.refreshToken)).rejects.toBeInstanceOf(
      RefreshTokenReuseError,
    );
  });

  it('ÇIKIŞTAN SONRA grace UYGULANMAZ — aile ölü, yeni oturum verilmez', async () => {
    // Bu, grace'in en tehlikeli yan etkisi: uygulanmasaydı çıkış 10sn boyunca
    // etkisiz kalırdı. Ayrım "ailede hâlâ aktif token var mı?" sorusuna dayanır.
    const s = await buildIdentityStack({ reuseGraceMs: GRACE_MS });
    const first = await s.registerDevice.execute({ fingerprint: 'race-3', platform: 'ios' });

    const rotated = await s.refreshSession.execute(first.refreshToken);
    // Çıkış: aileyi düşür (LogoutUseCase'in yaptığı).
    await s.refreshTokens.revokeFamily(
      (await s.refreshTokens.findByHash(s.hasher.hash(rotated.refreshToken)))!.familyId,
      new Date(),
    );

    // Çıkıştan HEMEN sonra (grace penceresi içinde) — yine de girilemez.
    await expect(s.refreshSession.execute(rotated.refreshToken)).rejects.toBeInstanceOf(
      RefreshTokenReuseError,
    );
    await expect(s.refreshSession.execute(first.refreshToken)).rejects.toBeInstanceOf(
      RefreshTokenReuseError,
    );
  });

  it('REUSE SONRASI grace UYGULANMAZ — aile bir kez düştüyse geri dönüş yok', async () => {
    const clock = new MutableClock();
    const s = await buildIdentityStack({ reuseGraceMs: GRACE_MS, clock });
    const first = await s.registerDevice.execute({ fingerprint: 'race-4', platform: 'ios' });

    const rotated = await s.refreshSession.execute(first.refreshToken);
    clock.advanceSeconds(11);
    await expect(s.refreshSession.execute(first.refreshToken)).rejects.toBeInstanceOf(
      RefreshTokenReuseError,
    ); // aile düştü

    // Aile ölü: rotasyondan gelen token grace penceresinde bile diriltilemez.
    await expect(s.refreshSession.execute(rotated.refreshToken)).rejects.toBeInstanceOf(
      RefreshTokenReuseError,
    );
  });

  it('grace=0 KATI: aynı anda gelen ikinci istek bile reuse sayılır', async () => {
    // `<=` tek başına yazılsaydı fark=0 olduğu için katı modda da tolere edilirdi.
    const s = await buildIdentityStack({ reuseGraceMs: 0 });
    const first = await s.registerDevice.execute({ fingerprint: 'race-5', platform: 'ios' });

    await s.refreshSession.execute(first.refreshToken);
    await expect(s.refreshSession.execute(first.refreshToken)).rejects.toBeInstanceOf(
      RefreshTokenReuseError,
    );
  });

  it('SIRA: yeni token ESKİSİ İPTAL EDİLMEDEN ÖNCE kaydedilir', async () => {
    /**
     * Bu testin sebebi bir ÖLÇÜMDÜR, teori değil: gerçek eşzamanlı iki istekle
     * denendiğinde ters sıra (önce iptal, sonra bas) ailede bir an aktif token
     * bırakmıyor, o boşluğa düşen ikinci sekme yarışı REUSE sanıp aileyi düşürüyordu
     * → grace işlevsiz kalıyordu (ölçüldü: A=200, B=401). Sıra düzeltilince 5/5 turda
     * iki sekme de sağ kaldı.
     *
     * Sıralı birim testler bu boşluğu göremez; bu yüzden kararı ÇAĞRI SIRASINA
     * bakarak sabitliyoruz — yoksa ileride "daha mantıklı" diye ters çevrilir.
     */
    const s = await buildIdentityStack({ reuseGraceMs: GRACE_MS });
    const first = await s.registerDevice.execute({ fingerprint: 'order-1', platform: 'ios' });

    const calls: string[] = [];
    const realSave = s.refreshTokens.save.bind(s.refreshTokens);
    const realRevoke = s.refreshTokens.markRevoked.bind(s.refreshTokens);
    s.refreshTokens.save = async (r) => {
      calls.push('save');
      return realSave(r);
    };
    s.refreshTokens.markRevoked = async (id, at) => {
      calls.push('markRevoked');
      return realRevoke(id, at);
    };

    await s.refreshSession.execute(first.refreshToken);
    expect(calls).toEqual(['save', 'markRevoked']);
  });

  it('yarış toleransı oturumu UZATMAZ: süresi dolmuş aile diriltilemez', async () => {
    const clock = new MutableClock();
    const s = await buildIdentityStack({ reuseGraceMs: GRACE_MS, refreshTtl: 10, clock });
    const first = await s.registerDevice.execute({ fingerprint: 'race-6', platform: 'ios' });

    await s.refreshSession.execute(first.refreshToken);
    clock.advanceSeconds(11); // hem grace hem TTL geçti

    await expect(s.refreshSession.execute(first.refreshToken)).rejects.toBeInstanceOf(
      RefreshTokenReuseError,
    );
  });
});
