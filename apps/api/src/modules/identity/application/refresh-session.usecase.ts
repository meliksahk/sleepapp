import { audienceForKind } from '../domain/user.entity';
import type { IssuedSession } from '../domain/user.entity';
import { InvalidRefreshTokenError, RefreshTokenReuseError } from '../domain/errors';
import type { Clock, RefreshTokenRepository, TokenHasher, UserRepository } from '../domain/ports';
import type { SessionMinter } from './session-minter';

/**
 * Refresh akışı — rotation + reuse-detection (docs/02 §2.1):
 * - Token bulunamazsa → geçersiz.
 * - Token zaten iptal edilmişse (rotasyona uğramış) → REUSE: aile komple düşürülür.
 * - Süresi dolmuşsa → geçersiz.
 * - Aksi halde: mevcut token iptal edilir, AYNI aile içinde yeni çift üretilir.
 */
export class RefreshSessionUseCase {
  constructor(
    private readonly refreshTokens: RefreshTokenRepository,
    private readonly users: UserRepository,
    private readonly hasher: TokenHasher,
    private readonly clock: Clock,
    private readonly sessions: SessionMinter,
  ) {}

  async execute(rawRefreshToken: string): Promise<IssuedSession> {
    const hash = this.hasher.hash(rawRefreshToken);
    const record = await this.refreshTokens.findByHash(hash);
    if (!record) {
      throw new InvalidRefreshTokenError();
    }

    const now = this.clock.now();

    if (record.revokedAt !== null) {
      // İptal edilmiş token yeniden kullanıldı → çalıntı; tüm aileyi düşür.
      await this.refreshTokens.revokeFamily(record.familyId, now);
      throw new RefreshTokenReuseError();
    }

    if (record.expiresAt.getTime() <= now.getTime()) {
      throw new InvalidRefreshTokenError();
    }

    const user = await this.users.findById(record.userId);
    if (!user) {
      throw new InvalidRefreshTokenError();
    }

    // Rotasyon: mevcut token'ı iptal et, aynı aile altında yenisini üret.
    await this.refreshTokens.markRevoked(record.id, now);
    return this.sessions.mint({
      userId: user.id,
      roles: user.roles,
      familyId: record.familyId,
      // Rol/tür değişimi refresh'te yürürlüğe girer: admin yapılan hesap bir sonraki
      // refresh'te 'admin' audience'ı alır, geri alınan da kaybeder.
      aud: audienceForKind(user.kind),
    });
  }
}
