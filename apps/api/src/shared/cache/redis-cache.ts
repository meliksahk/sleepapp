import type { OnModuleDestroy } from '@nestjs/common';

import type { Cache } from './cache.port';

/**
 * ioredis'in bu adaptörün KULLANDIĞI dar yüzeyi. Neden ayrı arayüz: birim testte
 * sahte bir client enjekte edip mantığı (JSON serileştirme, SCAN sayfalaması) gerçek
 * Redis olmadan doğrulayabilmek için — codebase'in port deseniyle aynı.
 */
export interface RedisClient {
  get(key: string): Promise<string | null>;
  set(key: string, value: string, mode: 'EX', ttlSeconds: number): Promise<unknown>;
  del(...keys: string[]): Promise<number>;
  scan(
    cursor: string,
    matchToken: 'MATCH',
    pattern: string,
    countToken: 'COUNT',
    count: number,
  ): Promise<[string, string[]]>;
  /** Bağlantıyı zarifçe kapatır (uygulama kapanışında + testte process'in çıkması için). */
  quit(): Promise<unknown>;
}

/**
 * Dağıtık (çok-instance) cache adaptörü (docs/02 B4). In-memory adaptörle AYNI `Cache`
 * port'unun arkasına takılır — tüketiciler değişmez. Dockerfile (#151) çok-instance
 * deploy'u mümkün kıldığı için bu artık gerçek bir ihtiyaç: her instance kendi
 * belleğinde cache tutarsa aynı içerik N kez DB'den okunur ve invalidasyon instance'lar
 * arası sızar.
 *
 * Değerler JSON olarak saklanır (feed = Soundscape[] gibi düz veri). TTL Redis'in
 * kendi süre dolumuna (`SET ... EX`) bırakılır — süre kontrolü uygulamada tutulmaz.
 */
export class RedisCache implements Cache, OnModuleDestroy {
  constructor(private readonly redis: RedisClient) {}

  /**
   * **Uygulama kapanışında bağlantıyı kapat.** Yoksa açık soket event loop'u canlı
   * tutar: `app.close()` sonrası jest ÇIKMAZ (asılı kalır) ve production'da zarif
   * kapanış olmaz. Nest, useFactory ile üretilen instance'ta da bu hook'u çağırır.
   */
  async onModuleDestroy(): Promise<void> {
    await this.redis.quit();
  }

  async get<T>(key: string): Promise<T | null> {
    const raw = await this.redis.get(key);
    if (raw === null) return null;
    return JSON.parse(raw) as T;
  }

  async set<T>(key: string, value: T, ttlSeconds: number): Promise<void> {
    await this.redis.set(key, JSON.stringify(value), 'EX', ttlSeconds);
  }

  async del(key: string): Promise<void> {
    await this.redis.del(key);
  }

  /**
   * Ön ekle eşleşen tüm anahtarları siler (feed archetype başına cache'lenir).
   *
   * **SCAN, KEYS DEĞİL:** `KEYS prefix*` tüm Redis sunucusunu tarama boyunca BLOKLAR —
   * production'da yasak. SCAN kürsörle sayfalar.
   *
   * **Önce TOPLA, sonra SİL** (tarama sırasında silme): tarama sürerken anahtar silmek,
   * kürsörün üzerinde durduğu veri kümesini değiştirir. Tüm eşleşenleri toplayıp tek
   * `DEL` ile silmek bu tuzağı tümden ortadan kaldırır. Feed ~9 anahtar; toplamak ucuz.
   */
  async delByPrefix(prefix: string): Promise<void> {
    const keys: string[] = [];
    let cursor = '0';
    do {
      const [next, page] = await this.redis.scan(cursor, 'MATCH', `${prefix}*`, 'COUNT', 100);
      cursor = next;
      keys.push(...page);
    } while (cursor !== '0');
    if (keys.length > 0) await this.redis.del(...keys);
  }
}
