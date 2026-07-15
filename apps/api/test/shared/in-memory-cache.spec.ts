import { InMemoryCache } from '../../src/shared/cache/in-memory-cache';

describe('InMemoryCache (TTL)', () => {
  it('set sonrası get değeri döner', async () => {
    const cache = new InMemoryCache();
    await cache.set('k', { a: 1 }, 300);
    expect(await cache.get<{ a: number }>('k')).toEqual({ a: 1 });
  });

  it('olmayan anahtar → null', async () => {
    const cache = new InMemoryCache();
    expect(await cache.get('yok')).toBeNull();
  });

  it('TTL geçince null döner ve elenir', async () => {
    let now = 1_000;
    const cache = new InMemoryCache(() => now);
    await cache.set('k', 'v', 5); // expiresAt = 1000 + 5000 = 6000
    now = 5_999;
    expect(await cache.get('k')).toBe('v'); // henüz geçerli
    now = 6_000;
    expect(await cache.get('k')).toBeNull(); // süre doldu (<=)
    now = 10_000;
    expect(await cache.get('k')).toBeNull(); // elendi
  });

  it('del anahtarı kaldırır', async () => {
    const cache = new InMemoryCache();
    await cache.set('k', 'v', 300);
    await cache.del('k');
    expect(await cache.get('k')).toBeNull();
  });
});
