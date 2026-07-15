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

    const cacheKey = `${req.originalUrl}:${key}`;
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
