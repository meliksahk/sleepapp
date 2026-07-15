import { Global, Module } from '@nestjs/common';
import { CACHE } from './cache.port';
import { InMemoryCache } from './in-memory-cache';

/**
 * Global cache sağlayıcı. Şu an in-memory (tek instance); B4'te Redis adaptörü
 * yalnızca bu provider değiştirilerek takılır (tüketiciler CACHE port'una bağlı).
 */
@Global()
@Module({
  // useFactory: InMemoryCache constructor'ı enjekte edilebilir `now` alır; Nest'in
  // onu çözmeye çalışmaması için elle kurarız (varsayılan saat = Date.now).
  providers: [{ provide: CACHE, useFactory: (): InMemoryCache => new InMemoryCache() }],
  exports: [CACHE],
})
export class CacheModule {}
