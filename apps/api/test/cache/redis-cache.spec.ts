import { RedisCache, type RedisClient } from '../../src/shared/cache/redis-cache';

/**
 * Gerçek Redis olmadan RedisCache MANTIĞINI doğrular (JSON serileştirme, SCAN
 * sayfalaması). Gerçek Redis'e karşı doğrulama ayrıca elle yapıldı (bkz. PR notu);
 * CI'da Redis servisi yok, o yüzden burada sahte client.
 */
class FakeRedis implements RedisClient {
  readonly store = new Map<string, string>();
  setCalls: Array<{ key: string; ttl: number }> = [];
  // Küçük sayfa: delByPrefix'in SCAN döngüsünü (çok sayfa) ZORLAR.
  private readonly pageSize = 2;

  async get(key: string): Promise<string | null> {
    return this.store.get(key) ?? null;
  }

  async set(key: string, value: string, _mode: 'EX', ttlSeconds: number): Promise<unknown> {
    this.store.set(key, value);
    this.setCalls.push({ key, ttl: ttlSeconds });
    return 'OK';
  }

  async del(...keys: string[]): Promise<number> {
    let n = 0;
    for (const k of keys) if (this.store.delete(k)) n++;
    return n;
  }

  async scan(
    cursor: string,
    _m: 'MATCH',
    pattern: string,
    _c: 'COUNT',
    _count: number,
  ): Promise<[string, string[]]> {
    const prefix = pattern.replace(/\*$/, '');
    const all = [...this.store.keys()].filter((k) => k.startsWith(prefix));
    const start = Number(cursor);
    const page = all.slice(start, start + this.pageSize);
    const next = start + this.pageSize >= all.length ? '0' : String(start + this.pageSize);
    return [next, page];
  }

  quitCalls = 0;
  async quit(): Promise<unknown> {
    this.quitCalls++;
    return 'OK';
  }
}

describe('RedisCache', () => {
  it('ÇEKİRDEK: set→get JSON roundtrip + TTL iletilir', async () => {
    const redis = new FakeRedis();
    const cache = new RedisCache(redis);
    await cache.set('k', { a: 1, list: [2, 3] }, 300);
    expect(await cache.get('k')).toEqual({ a: 1, list: [2, 3] });
    expect(redis.setCalls).toEqual([{ key: 'k', ttl: 300 }]);
  });

  it('olmayan anahtar null döner (Redis nil)', async () => {
    expect(await new RedisCache(new FakeRedis()).get('yok')).toBeNull();
  });

  it('del anahtarı siler', async () => {
    const cache = new RedisCache(new FakeRedis());
    await cache.set('k', 1, 60);
    await cache.del('k');
    expect(await cache.get('k')).toBeNull();
  });

  it('ÇEKİRDEK: onModuleDestroy bağlantıyı KAPATIR (jest asılmasın / zarif kapanış)', async () => {
    // Bu hook yoksa açık Redis soketi event loop'u canlı tutar ve test süiti çıkamaz.
    const redis = new FakeRedis();
    await new RedisCache(redis).onModuleDestroy();
    expect(redis.quitCalls).toBe(1);
  });

  it('ÇEKİRDEK: delByPrefix ÇOK SAYFALI SCAN ile eşleşen tümünü siler, ötekilere dokunmaz', async () => {
    const redis = new FakeRedis();
    const cache = new RedisCache(redis);
    // 5 feed anahtarı (sayfa boyutu 2 → 3 SCAN turu) + alakasız bir anahtar.
    for (let i = 0; i < 5; i++) await cache.set(`content:feed:arch${i}`, i, 300);
    await cache.set('content:soundscape:x', 'keep', 300);

    await cache.delByPrefix('content:feed:');

    for (let i = 0; i < 5; i++) expect(await cache.get(`content:feed:arch${i}`)).toBeNull();
    expect(await cache.get('content:soundscape:x')).toBe('keep'); // ön ek dışı korunur
  });
});
