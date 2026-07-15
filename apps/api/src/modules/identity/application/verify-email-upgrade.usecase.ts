import { EmailAlreadyTakenError, InvalidMagicLinkError } from '../domain/errors';
import type { Clock, OneTimeTokenRepository, TokenHasher, UserRepository } from '../domain/ports';

/**
 * Magic link doğrulama → anonim kullanıcıyı 'registered'a yükseltir. Token tek
 * kullanımlık + süreli; tüketildiğinde used_at işaretlenir.
 */
export class VerifyEmailUpgradeUseCase {
  constructor(
    private readonly users: UserRepository,
    private readonly ott: OneTimeTokenRepository,
    private readonly clock: Clock,
    private readonly hasher: TokenHasher,
  ) {}

  async execute(rawToken: string): Promise<{ userId: string; email: string }> {
    const record = await this.ott.findByHash(this.hasher.hash(rawToken));
    if (!record || record.purpose !== 'magic_link' || !record.email) {
      throw new InvalidMagicLinkError();
    }
    const now = this.clock.now();
    if (record.usedAt !== null || record.expiresAt.getTime() <= now.getTime()) {
      throw new InvalidMagicLinkError();
    }

    const taken = await this.users.findByEmail(record.email);
    if (taken && taken.id !== record.userId) {
      throw new EmailAlreadyTakenError();
    }

    await this.users.upgradeToEmail(record.userId, record.email, now);
    await this.ott.markUsed(record.id, now);
    return { userId: record.userId, email: record.email };
  }
}
