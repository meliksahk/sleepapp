import { randomUUID } from 'node:crypto';
import { PrismaClient } from '@prisma/client';
import { PrismaService } from '../../src/shared/infra/prisma.service';
import { PrismaUserRepository } from '../../src/modules/identity/infrastructure/prisma/prisma-user.repository';
import { PrismaRefreshTokenRepository } from '../../src/modules/identity/infrastructure/prisma/prisma-refresh-token.repository';
import type { RefreshTokenRecord, User } from '../../src/modules/identity/domain/user.entity';

/**
 * Prisma adaptörleri GERÇEK Postgres'e karşı (docs/02 §6 integration). DATABASE_URL
 * gerekir (lokal: docker compose + .env; CI: postgres service). Oluşturulan satırlar
 * afterAll'da temizlenir (users silme → auth_devices/refresh_tokens kaskad).
 */
describe('Prisma repositories (gerçek Postgres)', () => {
  const prisma = new PrismaService();
  const users = new PrismaUserRepository(prisma);
  const refreshTokens = new PrismaRefreshTokenRepository(prisma);
  const createdUserIds: string[] = [];

  const mkUser = (): User => {
    const u: User = { id: randomUUID(), kind: 'anonymous', roles: [], createdAt: new Date() };
    createdUserIds.push(u.id);
    return u;
  };
  const mkToken = (userId: string, familyId: string, hash: string): RefreshTokenRecord => ({
    id: randomUUID(),
    userId,
    tokenHash: hash,
    familyId,
    expiresAt: new Date(Date.now() + 3_600_000),
    revokedAt: null,
    createdAt: new Date(),
  });

  beforeAll(async () => {
    await prisma.$connect();
  });

  afterAll(async () => {
    if (createdUserIds.length > 0) {
      await (prisma as unknown as PrismaClient).users.deleteMany({
        where: { id: { in: createdUserIds } },
      });
    }
    await prisma.$disconnect();
  });

  it('createWithDevice sonra findById ve findByDeviceFingerprint çalışır', async () => {
    const user = mkUser();
    const fingerprint = `it-${user.id}`;
    await users.createWithDevice(user, { fingerprint, platform: 'ios' });

    const byId = await users.findById(user.id);
    expect(byId?.id).toBe(user.id);
    expect(byId?.kind).toBe('anonymous');

    const byFp = await users.findByDeviceFingerprint(fingerprint);
    expect(byFp?.id).toBe(user.id);

    expect(await users.findByDeviceFingerprint('yok-boyle-cihaz')).toBeNull();
  });

  it('refresh token save/findByHash/markRevoked/revokeFamily', async () => {
    const user = mkUser();
    await users.createWithDevice(user, { fingerprint: `it-${user.id}`, platform: 'ios' });

    const familyId = randomUUID();
    const t1 = mkToken(user.id, familyId, `hash-${randomUUID()}`);
    await refreshTokens.save(t1);

    const found = await refreshTokens.findByHash(t1.tokenHash);
    expect(found?.userId).toBe(user.id);
    expect(found?.revokedAt).toBeNull();

    await refreshTokens.markRevoked(t1.id, new Date());
    expect((await refreshTokens.findByHash(t1.tokenHash))?.revokedAt).not.toBeNull();

    // Aynı aileye ikinci aktif token, sonra aile düşür.
    const t2 = mkToken(user.id, familyId, `hash-${randomUUID()}`);
    await refreshTokens.save(t2);
    await refreshTokens.revokeFamily(familyId, new Date());
    expect((await refreshTokens.findByHash(t2.tokenHash))?.revokedAt).not.toBeNull();
  });

  it("izolasyon: A'nın ailesini düşürmek B'nin token'ını etkilemez", async () => {
    const a = mkUser();
    const b = mkUser();
    await users.createWithDevice(a, { fingerprint: `it-${a.id}`, platform: 'ios' });
    await users.createWithDevice(b, { fingerprint: `it-${b.id}`, platform: 'ios' });

    const famA = randomUUID();
    const famB = randomUUID();
    const tokenA = mkToken(a.id, famA, `hash-${randomUUID()}`);
    const tokenB = mkToken(b.id, famB, `hash-${randomUUID()}`);
    await refreshTokens.save(tokenA);
    await refreshTokens.save(tokenB);

    await refreshTokens.revokeFamily(famA, new Date());

    expect((await refreshTokens.findByHash(tokenA.tokenHash))?.revokedAt).not.toBeNull();
    // B'nin token'ı hâlâ aktif — A'nın işlemi B'yi etkilemedi.
    expect((await refreshTokens.findByHash(tokenB.tokenHash))?.revokedAt).toBeNull();
  });
});
