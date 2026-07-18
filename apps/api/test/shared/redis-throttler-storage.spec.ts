import { RedisThrottlerStorage } from '../../src/shared/throttler/redis-throttler-storage';

/**
 * GERÇEK Redis'e karşı dağıtık rate-limit deposu (#190 redis servisi + Postgres e2e deseni).
 *
 * Bu depo bir GÜVENLİK kontrolüdür (login brute-force limiti çok-instance'da tek sayılsın).
 * Sahte Redis "çağrıldı" der ama atomik sayaç + pencere semantiğini kanıtlamaz — burada
 * gerçek Redis üzerinde limit-aşımı blok, IP izolasyonu ve pencere sıfırlaması doğrulanır.
 * Redis yoksa (kasıtlı) başarısız — Postgres e2e'leriyle aynı sözleşme.
 */
const REDIS_URL = process.env.REDIS_TEST_URL ?? 'redis://127.0.0.1:6379';

describe('RedisThrottlerStorage (gerçek Redis, B4 dağıtık rate-limit)', () => {
  let storage: RedisThrottlerStorage;
  // Benzersiz prefix: paylaşımlı yerel Redis'te önceki koşular karışmasın.
  const prefix = `throttle-test-${Date.now()}`;

  beforeAll(() => {
    storage = new RedisThrottlerStorage(REDIS_URL, prefix);
  });
  afterAll(async () => {
    await storage.onModuleDestroy();
  });

  const hit = (key: string, ttl: number, limit: number) =>
    storage.increment(key, ttl, limit, 0, 'default');

  it('ÇEKİRDEK: limit aşılınca bloklar, öncesinde blok yok (dağıtık sayaç)', async () => {
    const key = 'ip-a';
    const limit = 3;
    const records = [];
    for (let i = 0; i < limit + 1; i++) records.push(await hit(key, 60_000, limit));

    expect(records.slice(0, limit).every((r) => !r.isBlocked)).toBe(true);
    expect(records[limit - 1]?.totalHits).toBe(limit);
    // limit+1'inci istek: sayaç aşıldı → BLOKLU.
    expect(records[limit]?.totalHits).toBe(limit + 1);
    expect(records[limit]?.isBlocked).toBe(true);
    // timeToExpire SANİYE (varsayılan depoyla aynı birim): 60s pencere → (0, 60].
    expect(records[limit]?.timeToExpire).toBeGreaterThan(0);
    expect(records[limit]?.timeToExpire).toBeLessThanOrEqual(60);
    expect(records[limit]?.timeToBlockExpire).toBeGreaterThan(0);
  });

  it('farklı anahtarlar bağımsız sayılır (IP izolasyonu)', async () => {
    const a = await hit('ip-b', 60_000, 1);
    const b = await hit('ip-c', 60_000, 1);
    expect(a.totalHits).toBe(1);
    expect(b.totalHits).toBe(1);
    expect(a.isBlocked).toBe(false);
    expect(b.isBlocked).toBe(false);
  });

  it('pencere dolunca sayaç sıfırlanır (kısa ttl)', async () => {
    const key = 'ip-d';
    expect((await hit(key, 300, 1)).totalHits).toBe(1);
    expect((await hit(key, 300, 1)).isBlocked).toBe(true); // 2. vuruş, limit 1 aşıldı
    await new Promise((r) => setTimeout(r, 400)); // pencere dolsun
    const third = await hit(key, 300, 1);
    expect(third.totalHits).toBe(1); // sıfırlandı
    expect(third.isBlocked).toBe(false);
  }, 10000);
});
