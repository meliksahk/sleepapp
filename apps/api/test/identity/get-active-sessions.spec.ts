import { GetActiveSessionsUseCase } from '../../src/modules/identity/application/get-active-sessions.usecase';
import { InMemoryRefreshTokenRepository } from '../../src/modules/identity/infrastructure/in-memory.repositories';
import type { RefreshTokenRecord } from '../../src/modules/identity/domain/user.entity';

const NOW = new Date('2026-01-01T00:00:00.000Z');
const clock = { now: () => NOW };
const FUTURE = new Date('2030-01-01T00:00:00.000Z');
const PAST = new Date('2020-01-01T00:00:00.000Z');

let seq = 0;
function rec(
  userId: string,
  familyId: string,
  over: Partial<Pick<RefreshTokenRecord, 'revokedAt' | 'expiresAt' | 'createdAt'>> = {},
): RefreshTokenRecord {
  seq += 1;
  return {
    id: `id-${seq}`,
    userId,
    tokenHash: `hash-${seq}`,
    familyId,
    expiresAt: over.expiresAt ?? FUTURE,
    revokedAt: over.revokedAt ?? null,
    createdAt: over.createdAt ?? new Date('2025-06-01T00:00:00.000Z'),
  };
}

describe('GetActiveSessionsUseCase', () => {
  it('yalnızca aktif (iptal edilmemiş + süresi geçmemiş) oturumları döner, token yok', async () => {
    const repo = new InMemoryRefreshTokenRepository();
    await repo.save(rec('u1', 'famA')); // aktif
    await repo.save(rec('u1', 'famB', { revokedAt: NOW })); // iptal → hariç
    await repo.save(rec('u1', 'famC', { expiresAt: PAST })); // süresi dolmuş → hariç
    await repo.save(rec('u2', 'famD')); // BAŞKA kullanıcı → hariç

    const list = await new GetActiveSessionsUseCase(repo, clock).execute('u1');

    expect(list).toHaveLength(1);
    expect(list[0]?.familyId).toBe('famA');
    // token/hash dışa verilmez
    expect(JSON.stringify(list)).not.toContain('hash-');
  });

  it('createdAt azalan sıralı', async () => {
    const repo = new InMemoryRefreshTokenRepository();
    await repo.save(rec('u1', 'old', { createdAt: new Date('2025-01-01T00:00:00Z') }));
    await repo.save(rec('u1', 'new', { createdAt: new Date('2025-12-01T00:00:00Z') }));
    const list = await new GetActiveSessionsUseCase(repo, clock).execute('u1');
    expect(list.map((s) => s.familyId)).toEqual(['new', 'old']);
  });

  it('oturum yoksa boş dizi', async () => {
    const repo = new InMemoryRefreshTokenRepository();
    expect(await new GetActiveSessionsUseCase(repo, clock).execute('u1')).toEqual([]);
  });
});
