import { Global, Module } from '@nestjs/common';
import Redis from 'ioredis';

import { loadEnv } from '../config/env';
import { CACHE, type Cache } from './cache.port';
import { InMemoryCache } from './in-memory-cache';
import { RedisCache, type RedisClient } from './redis-cache';

/**
 * Global cache sağlayıcı. **`REDIS_URL` varsa Redis** (dağıtık, çok-instance), yoksa
 * in-memory (tek instance). Tüketiciler `CACHE` port'una bağlı — hangi adaptör olduğunu
 * bilmez. Bu seçim, Dockerfile (#151) çok-instance deploy'u mümkün kıldıktan sonra
 * gerçek bir ihtiyaç oldu: her instance kendi belleğinde cache tutarsa aynı içerik N
 * kez DB'den okunur ve invalidasyon instance'lar arası sızmaz.
 */
@Global()
@Module({
  providers: [
    {
      provide: CACHE,
      useFactory: (): Cache => {
        const { REDIS_URL } = loadEnv();
        if (!REDIS_URL) return new InMemoryCache();
        // lazyConnect kullanılmaz: ioredis bağlantıyı arka planda kurar/yeniden dener,
        // Redis geç gelirse boot PATLAMAZ. maxRetriesPerRequest sınırlı: Redis düşerse
        // istek sonsuza kadar asılı kalmaz — hata olur (yutulmaz).
        const client = new Redis(REDIS_URL, { maxRetriesPerRequest: 3 });
        return new RedisCache(client as unknown as RedisClient);
      },
    },
  ],
  exports: [CACHE],
})
export class CacheModule {}
