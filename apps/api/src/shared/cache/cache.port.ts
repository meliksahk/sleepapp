/**
 * TTL'li anahtar-değer cache portu (docs/02 B4). Uygulama katmanı bu arayüze
 * bağlanır; in-memory adaptör tek instance için, Redis adaptörü dağıtık için
 * (B4) aynı port'un arkasına takılır — kod değişmeden.
 */
export interface Cache {
  get<T>(key: string): Promise<T | null>;
  set<T>(key: string, value: T, ttlSeconds: number): Promise<void>;
  del(key: string): Promise<void>;
}

export const CACHE = Symbol('CACHE');
