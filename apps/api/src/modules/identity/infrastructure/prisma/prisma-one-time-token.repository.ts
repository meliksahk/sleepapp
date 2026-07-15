import type { OneTimeTokenRecord, OttPurpose } from '../../domain/user.entity';
import type { OneTimeTokenRepository } from '../../domain/ports';
import type { PrismaService } from '../../../../shared/infra/prisma.service';

export class PrismaOneTimeTokenRepository implements OneTimeTokenRepository {
  constructor(private readonly prisma: PrismaService) {}

  async save(record: OneTimeTokenRecord): Promise<void> {
    await this.prisma.one_time_tokens.create({
      data: {
        id: record.id,
        user_id: record.userId,
        email: record.email,
        purpose: record.purpose,
        token_hash: record.tokenHash,
        expires_at: record.expiresAt,
        used_at: record.usedAt,
      },
    });
  }

  async findByHash(tokenHash: string): Promise<OneTimeTokenRecord | null> {
    const row = await this.prisma.one_time_tokens.findUnique({ where: { token_hash: tokenHash } });
    if (!row) return null;
    return {
      id: row.id,
      userId: row.user_id,
      email: row.email,
      purpose: row.purpose as OttPurpose,
      tokenHash: row.token_hash,
      expiresAt: row.expires_at,
      usedAt: row.used_at,
    };
  }

  async markUsed(id: string, usedAt: Date): Promise<void> {
    await this.prisma.one_time_tokens.updateMany({
      where: { id, used_at: null },
      data: { used_at: usedAt },
    });
  }
}
