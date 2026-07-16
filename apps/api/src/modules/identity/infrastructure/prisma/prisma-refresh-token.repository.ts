import type { ActiveSessionInfo, RefreshTokenRecord } from '../../domain/user.entity';
import type { RefreshTokenRepository } from '../../domain/ports';
import type { PrismaService } from '../../../../shared/infra/prisma.service';

/** refresh_tokens erişimi (Prisma) — rotation + reuse-detection için. */
export class PrismaRefreshTokenRepository implements RefreshTokenRepository {
  constructor(private readonly prisma: PrismaService) {}

  async save(record: RefreshTokenRecord): Promise<void> {
    await this.prisma.refresh_tokens.create({
      data: {
        id: record.id,
        user_id: record.userId,
        token_hash: record.tokenHash,
        family_id: record.familyId,
        expires_at: record.expiresAt,
        revoked_at: record.revokedAt,
        created_at: record.createdAt,
      },
    });
  }

  async findByHash(tokenHash: string): Promise<RefreshTokenRecord | null> {
    const row = await this.prisma.refresh_tokens.findUnique({ where: { token_hash: tokenHash } });
    return row ? toRecord(row) : null;
  }

  async markRevoked(id: string, revokedAt: Date): Promise<void> {
    // revoked_at null koşulu: yalnızca aktif token iptal edilir (idempotent).
    await this.prisma.refresh_tokens.updateMany({
      where: { id, revoked_at: null },
      data: { revoked_at: revokedAt },
    });
  }

  async revokeFamily(familyId: string, revokedAt: Date): Promise<void> {
    await this.prisma.refresh_tokens.updateMany({
      where: { family_id: familyId, revoked_at: null },
      data: { revoked_at: revokedAt },
    });
  }

  async revokeAllExceptFamily(
    userId: string,
    keepFamilyId: string,
    revokedAt: Date,
  ): Promise<number> {
    const result = await this.prisma.refresh_tokens.updateMany({
      where: { user_id: userId, family_id: { not: keepFamilyId }, revoked_at: null },
      data: { revoked_at: revokedAt },
    });
    return result.count;
  }

  async listActiveByUser(userId: string, now: Date): Promise<ActiveSessionInfo[]> {
    const rows = await this.prisma.refresh_tokens.findMany({
      where: { user_id: userId, revoked_at: null, expires_at: { gt: now } },
      select: { family_id: true, created_at: true, expires_at: true },
      orderBy: { created_at: 'desc' },
    });
    return rows.map((r) => ({
      familyId: r.family_id,
      createdAt: r.created_at,
      expiresAt: r.expires_at,
    }));
  }
}

function toRecord(row: {
  id: string;
  user_id: string;
  token_hash: string;
  family_id: string;
  expires_at: Date;
  revoked_at: Date | null;
  created_at: Date;
}): RefreshTokenRecord {
  return {
    id: row.id,
    userId: row.user_id,
    tokenHash: row.token_hash,
    familyId: row.family_id,
    expiresAt: row.expires_at,
    revokedAt: row.revoked_at,
    createdAt: row.created_at,
  };
}
