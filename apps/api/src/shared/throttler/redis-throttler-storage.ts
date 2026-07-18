import type { OnModuleDestroy } from '@nestjs/common';
import type { ThrottlerStorage } from '@nestjs/throttler';
import Redis from 'ioredis';

/** ThrottlerStorage.increment'ın dönüş şekli — @nestjs/throttler bu tipi public export ETMEZ. */
interface ThrottlerStorageRecord {
  totalHits: number;
  timeToExpire: number;
  isBlocked: boolean;
  timeToBlockExpire: number;
}

/**
 * Dağıtık (Redis) rate-limit deposu (docs/02 B4 sertleşme).
 *
 * Neden: varsayılan `ThrottlerStorageService` sayaçları SÜREÇ BELLEĞİNDE tutar. Dockerfile
 * (#151) çok-instance deploy'u açtıktan sonra bu bir GÜVENLİK açığı oldu: admin login
 * brute-force limiti (auth.controller) her instance'ta AYRI sayılır → N instance = N kat
 * deneme hakkı. Redis deposu limiti tüm instance'larda TEK sayar. Cache'in #157'de Redis'e
 * taşınmasıyla birebir aynı gerekçe; aynı REDIS_URL-gate deseni (yoksa in-memory).
 *
 * Sabit pencere (fixed-window): tek atomik Lua betiği — INCR + ilk vuruşta PEXPIRE. Limit
 * aşılınca pencere sonuna kadar bloklu. `blockDuration` proje genelinde ayarlanmadığından
 * (hiçbir @Throttle set etmiyor) blok penceresi = vuruş penceresi. Birimler varsayılan depoyla
 * eşleşir: girdi ttl/blockDuration MİLİSANİYE, çıktı timeToExpire/timeToBlockExpire SANİYE.
 */
const INCREMENT_LUA = `
local hitsKey = KEYS[1]
local ttl = tonumber(ARGV[1])
local limit = tonumber(ARGV[2])

local totalHits = redis.call('INCR', hitsKey)
local pttl = redis.call('PTTL', hitsKey)
-- İlk vuruş (veya süresiz kalmış anahtar): pencereyi başlat.
if totalHits == 1 or pttl < 0 then
  redis.call('PEXPIRE', hitsKey, ttl)
  pttl = ttl
end

local timeToExpire = math.ceil(pttl / 1000)
local isBlocked = 0
local timeToBlockExpire = 0
if totalHits > limit then
  isBlocked = 1
  timeToBlockExpire = timeToExpire
end
return {totalHits, timeToExpire, isBlocked, timeToBlockExpire}
`;

export class RedisThrottlerStorage implements ThrottlerStorage, OnModuleDestroy {
  private readonly redis: Redis;

  constructor(
    redisUrl: string,
    private readonly prefix = 'throttle',
  ) {
    // Cache modülüyle aynı bağlantı politikası: arka planda yeniden dener (boot patlamaz),
    // ama istek sonsuza asılmasın diye retry sınırlı (Redis düşerse hata → yutulmaz).
    this.redis = new Redis(redisUrl, { maxRetriesPerRequest: 3 });
  }

  async increment(
    key: string,
    ttl: number,
    limit: number,
    _blockDuration: number,
    throttlerName: string,
  ): Promise<ThrottlerStorageRecord> {
    const hitsKey = `${this.prefix}:${throttlerName}:${key}`;
    const result = (await this.redis.eval(
      INCREMENT_LUA,
      1,
      hitsKey,
      String(ttl),
      String(limit),
    )) as [number, number, number, number];

    return {
      totalHits: result[0],
      timeToExpire: result[1],
      isBlocked: result[2] === 1,
      timeToBlockExpire: result[3],
    };
  }

  async onModuleDestroy(): Promise<void> {
    // Açık Redis soketi süreç/test event-loop'unu canlı tutar (RedisCache ile aynı gerekçe).
    await this.redis.quit();
  }
}
