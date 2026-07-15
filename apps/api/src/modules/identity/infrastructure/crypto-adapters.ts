import { createHash, randomBytes, randomUUID } from 'node:crypto';
import type { Clock, IdGenerator, OpaqueTokenGenerator, TokenHasher } from '../domain/ports';

export class SystemClock implements Clock {
  now(): Date {
    return new Date();
  }
}

export class UuidIdGenerator implements IdGenerator {
  uuid(): string {
    return randomUUID();
  }
}

/** 256-bit yüksek entropili opak refresh token. */
export class RandomOpaqueTokenGenerator implements OpaqueTokenGenerator {
  generate(): string {
    return randomBytes(32).toString('base64url');
  }
}

/** Deterministik SHA-256 — refresh token'ı DB'de aramak için (bkz. ports.ts notu). */
export class Sha256TokenHasher implements TokenHasher {
  hash(raw: string): string {
    return createHash('sha256').update(raw).digest('hex');
  }
}
