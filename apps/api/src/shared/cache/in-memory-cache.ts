import { Injectable } from '@nestjs/common';
import type { Cache } from './cache.port';

interface Entry {
  value: unknown;
  expiresAt: number;
}

/**
 * TTL'li in-memory cache (tek instance). Süresi geçen anahtar okumada elenir.
 * Çok-instance / dağıtık için Redis adaptörü B4'te bu port'un arkasına takılır.
 * `now` enjekte edilebilir (test determinizmi).
 */
@Injectable()
export class InMemoryCache implements Cache {
  private readonly store = new Map<string, Entry>();

  constructor(private readonly now: () => number = () => Date.now()) {}

  async get<T>(key: string): Promise<T | null> {
    const entry = this.store.get(key);
    if (!entry) return null;
    if (entry.expiresAt <= this.now()) {
      this.store.delete(key);
      return null;
    }
    return entry.value as T;
  }

  async set<T>(key: string, value: T, ttlSeconds: number): Promise<void> {
    this.store.set(key, { value, expiresAt: this.now() + ttlSeconds * 1000 });
  }

  async del(key: string): Promise<void> {
    this.store.delete(key);
  }
}
