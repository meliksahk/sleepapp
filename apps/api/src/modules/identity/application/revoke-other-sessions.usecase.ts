import { InvalidRefreshTokenError } from '../domain/errors';
import type { Clock, RefreshTokenRepository, TokenHasher } from '../domain/ports';

/**
 * "Diğer cihazlardan çık" — kullanıcı mevcut refresh token'ını sunar; o token'ın
 * ailesi HARİÇ kullanıcının tüm aktif oturumları iptal edilir (hesap güvenliği).
 * Token geçersiz/iptal/süresi-dolmuş ya da BAŞKA kullanıcıya aitse → geçersiz.
 */
export class RevokeOtherSessionsUseCase {
  constructor(
    private readonly refreshTokens: RefreshTokenRepository,
    private readonly hasher: TokenHasher,
    private readonly clock: Clock,
  ) {}

  async execute(userId: string, rawRefreshToken: string): Promise<number> {
    const record = await this.refreshTokens.findByHash(this.hasher.hash(rawRefreshToken));
    const now = this.clock.now();

    if (
      !record ||
      record.revokedAt !== null ||
      record.expiresAt.getTime() <= now.getTime() ||
      record.userId !== userId // access token sahibi bu refresh token'ın sahibi olmalı
    ) {
      throw new InvalidRefreshTokenError();
    }

    return this.refreshTokens.revokeAllExceptFamily(userId, record.familyId, now);
  }
}
