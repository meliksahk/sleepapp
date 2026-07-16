/**
 * TTL'li anahtar-değer cache portu (docs/02 B4). Uygulama katmanı bu arayüze
 * bağlanır; in-memory adaptör tek instance için, Redis adaptörü dağıtık için
 * (B4) aynı port'un arkasına takılır — kod değişmeden.
 */
export interface Cache {
  get<T>(key: string): Promise<T | null>;
  set<T>(key: string, value: T, ttlSeconds: number): Promise<void>;
  del(key: string): Promise<void>;
  /**
   * Ön ekle eşleşen TÜM anahtarları siler.
   *
   * NEDEN GEREKLİ: feed archetype BAŞINA cache'lenir (`content:feed:{archetype}`),
   * yani tek bir içerik değişimi ~9 anahtarı geçersiz kılar. Tek tek `del` çağırmak,
   * archetype listesini cache tüketicisine bildirmek demekti — orası bilmemeli.
   * Redis adaptörü (B4) bunu SCAN+DEL ile karşılar.
   */
  delByPrefix(prefix: string): Promise<void>;
}

export const CACHE = Symbol('CACHE');
