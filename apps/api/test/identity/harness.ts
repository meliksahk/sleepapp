import type { Clock } from '../../src/modules/identity/domain/ports';
import {
  RandomOpaqueTokenGenerator,
  Sha256TokenHasher,
  UuidIdGenerator,
} from '../../src/modules/identity/infrastructure/crypto-adapters';
import { JoseAccessTokenSigner } from '../../src/modules/identity/infrastructure/jose-access-token-signer';
import {
  InMemoryRefreshTokenRepository,
  InMemoryUserRepository,
} from '../../src/modules/identity/infrastructure/in-memory.repositories';
import { SessionMinter } from '../../src/modules/identity/application/session-minter';
import { RegisterDeviceUseCase } from '../../src/modules/identity/application/register-device.usecase';
import { RefreshSessionUseCase } from '../../src/modules/identity/application/refresh-session.usecase';
import { AuthorizeUseCase } from '../../src/modules/identity/application/authorize.usecase';

/** Kontrol edilebilir saat — reuse/expiry senaryoları için. */
export class MutableClock implements Clock {
  constructor(private current = new Date('2026-07-15T00:00:00.000Z')) {}
  now(): Date {
    return new Date(this.current);
  }
  advanceSeconds(seconds: number): void {
    this.current = new Date(this.current.getTime() + seconds * 1000);
  }
}

export async function buildIdentityStack(opts?: {
  accessTtl?: number;
  refreshTtl?: number;
  clock?: MutableClock;
}) {
  const clock = opts?.clock ?? new MutableClock();
  const ids = new UuidIdGenerator();
  const opaque = new RandomOpaqueTokenGenerator();
  const hasher = new Sha256TokenHasher();
  const users = new InMemoryUserRepository();
  const refreshTokens = new InMemoryRefreshTokenRepository();
  const signer = await JoseAccessTokenSigner.create({ allowEphemeral: true });
  const minter = new SessionMinter(signer, hasher, opaque, ids, clock, refreshTokens, {
    accessTokenTtl: opts?.accessTtl ?? 900,
    refreshTokenTtl: opts?.refreshTtl ?? 2_592_000,
  });
  return {
    clock,
    hasher,
    users,
    refreshTokens,
    signer,
    registerDevice: new RegisterDeviceUseCase(users, ids, clock, minter),
    refreshSession: new RefreshSessionUseCase(refreshTokens, users, hasher, clock, minter),
    authorize: new AuthorizeUseCase(signer),
  };
}
