import { RevokeOtherSessionsUseCase } from '../../src/modules/identity/application/revoke-other-sessions.usecase';
import { InvalidRefreshTokenError } from '../../src/modules/identity/domain/errors';
import { InMemoryRefreshTokenRepository } from '../../src/modules/identity/infrastructure/in-memory.repositories';
import { Sha256TokenHasher } from '../../src/modules/identity/infrastructure/crypto-adapters';
import type { RefreshTokenRecord } from '../../src/modules/identity/domain/user.entity';

const hasher = new Sha256TokenHasher();
const NOW = new Date('2026-01-01T00:00:00.000Z');
const clock = { now: () => NOW };
const FUTURE = new Date('2030-01-01T00:00:00.000Z');

function rec(
  id: string,
  userId: string,
  familyId: string,
  rawToken: string,
  over: Partial<Pick<RefreshTokenRecord, 'revokedAt' | 'expiresAt'>> = {},
): RefreshTokenRecord {
  return {
    id,
    userId,
    tokenHash: hasher.hash(rawToken),
    familyId,
    expiresAt: over.expiresAt ?? FUTURE,
    revokedAt: over.revokedAt ?? null,
    createdAt: new Date('2025-01-01T00:00:00.000Z'),
  };
}

async function isRevoked(repo: InMemoryRefreshTokenRepository, raw: string): Promise<boolean> {
  const r = await repo.findByHash(hasher.hash(raw));
  return r?.revokedAt !== null && r !== null;
}

describe('RevokeOtherSessionsUseCase', () => {
  it('mevcut aile hariç kullanıcının diğer oturumlarını iptal eder; başkasına dokunmaz', async () => {
    const repo = new InMemoryRefreshTokenRepository();
    await repo.save(rec('1', 'u1', 'famA', 'tA')); // mevcut (korunur)
    await repo.save(rec('2', 'u1', 'famB', 'tB')); // diğer (iptal)
    await repo.save(rec('3', 'u2', 'famC', 'tC')); // BAŞKA kullanıcı (dokunulmaz)

    const revoked = await new RevokeOtherSessionsUseCase(repo, hasher, clock).execute('u1', 'tA');

    expect(revoked).toBe(1);
    expect(await isRevoked(repo, 'tA')).toBe(false); // mevcut korunur
    expect(await isRevoked(repo, 'tB')).toBe(true); // diğer iptal
    expect(await isRevoked(repo, 'tC')).toBe(false); // u2 izole
  });

  it('geçersiz (bilinmeyen) token → InvalidRefreshTokenError', async () => {
    const repo = new InMemoryRefreshTokenRepository();
    await expect(
      new RevokeOtherSessionsUseCase(repo, hasher, clock).execute('u1', 'yok'),
    ).rejects.toBeInstanceOf(InvalidRefreshTokenError);
  });

  it('token BAŞKA kullanıcıya aitse → InvalidRefreshTokenError (izolasyon)', async () => {
    const repo = new InMemoryRefreshTokenRepository();
    await repo.save(rec('1', 'u1', 'famA', 'tA'));
    await expect(
      new RevokeOtherSessionsUseCase(repo, hasher, clock).execute('u2', 'tA'),
    ).rejects.toBeInstanceOf(InvalidRefreshTokenError);
  });

  it('iptal edilmiş / süresi dolmuş token → InvalidRefreshTokenError', async () => {
    const repo = new InMemoryRefreshTokenRepository();
    await repo.save(rec('1', 'u1', 'famA', 'tRevoked', { revokedAt: NOW }));
    await repo.save(rec('2', 'u1', 'famB', 'tExpired', { expiresAt: new Date('2020-01-01') }));
    const uc = new RevokeOtherSessionsUseCase(repo, hasher, clock);
    await expect(uc.execute('u1', 'tRevoked')).rejects.toBeInstanceOf(InvalidRefreshTokenError);
    await expect(uc.execute('u1', 'tExpired')).rejects.toBeInstanceOf(InvalidRefreshTokenError);
  });
});
