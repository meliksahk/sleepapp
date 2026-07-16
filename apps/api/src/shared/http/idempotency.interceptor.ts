import { CallHandler, ExecutionContext, Injectable, NestInterceptor } from '@nestjs/common';
import type { Request } from 'express';
import { Observable, of, tap } from 'rxjs';

interface CacheEntry {
  body: unknown;
  expiresAt: number;
}

/**
 * Idempotency-Key desteği (docs/02 §4). Aynı anahtarla tekrar edilen POST, ilk
 * yanıtı döndürür (yeni işlem yapılmaz) — mobil offline kuyruğunun retry güvenliği.
 * In-memory (tek instance); dağıtık Redis cache B4'te.
 *
 * ⚠️ ANAHTAR KAPSAMI (güvenlik): cache anahtarı ÇAĞIRANI içermek ZORUNDA.
 * Eskiden yalnızca `url:key` idi → aynı Idempotency-Key'i kullanan İKİ FARKLI
 * kullanıcıdan ikincisi, birincinin yanıtını alıyordu (başkasının userId'si +
 * skorları) ve kendi işlemi hiç yapılmıyordu. Anahtarlar gizli değil ve naif bir
 * istemci (sayaç/timestamp) çakışmayı olası kılar. CLAUDE.md §6'nın "her şey
 * çağıranın kimliğiyle kapsamlanır" kuralı burada da geçerli.
 */
@Injectable()
export class IdempotencyInterceptor implements NestInterceptor {
  private readonly cache = new Map<string, CacheEntry>();
  private readonly ttlMs = 5 * 60 * 1000;
  private readonly maxEntries = 10_000;

  intercept(context: ExecutionContext, next: CallHandler): Observable<unknown> {
    const req = context.switchToHttp().getRequest<Request>();
    const header = req.headers['idempotency-key'];
    const key = typeof header === 'string' ? header : undefined;
    if (!key || req.method !== 'POST') {
      return next.handle();
    }

    const cacheKey = `${callerScope(req)}:${req.originalUrl}:${key}`;
    const now = Date.now();
    const cached = this.cache.get(cacheKey);
    if (cached && cached.expiresAt > now) {
      return of(cached.body); // Handler'ı ATLA — yeni işlem yok.
    }

    return next.handle().pipe(
      tap((body: unknown) => {
        if (this.cache.size >= this.maxEntries) this.evictExpired(now);
        this.cache.set(cacheKey, { body, expiresAt: now + this.ttlMs });
      }),
    );
  }

  private evictExpired(now: number): void {
    for (const [k, v] of this.cache) {
      if (v.expiresAt <= now) this.cache.delete(k);
    }
  }
}

/**
 * Cache anahtarının çağıran-kapsamı: kimlik doğrulanmışsa kullanıcı, değilse IP.
 *
 * Neden IP fallback (kimliksizde cache'i tamamen kapatmak yerine): public uçlar
 * (`/v1/archetype/web`, `/v1/waitlist`) da retry güvenliğinden yararlanıyor.
 * IP mükemmel bir kimlik değil (NAT), ama rastgele anahtarlarla çakışma pratikte
 * yok ve "herkes tek havuz"dan kat kat iyi.
 *
 * `req.user` yapısal olarak okunuyor — `identity`'den tip import etmek
 * shared→modül sınırını ihlal ederdi (boundary lint).
 */
function callerScope(req: Request): string {
  const user = (req as Request & { user?: { sub?: unknown } }).user;
  const sub = user?.sub;
  return typeof sub === 'string' && sub.length > 0 ? `u:${sub}` : `ip:${req.ip ?? 'unknown'}`;
}
