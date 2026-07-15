import { EmailAlreadyTakenError } from '../domain/errors';
import type {
  Clock,
  IdGenerator,
  Mailer,
  OneTimeTokenRepository,
  OpaqueTokenGenerator,
  TokenHasher,
  UserRepository,
} from '../domain/ports';

export interface MagicLinkConfig {
  readonly ttlSeconds: number;
  readonly baseUrl: string;
}

/**
 * E-posta ile hesaba yükseltme talebi (magic link). Anonim kullanıcı e-posta verir;
 * tek kullanımlık token üretilir ve mailer ile gönderilir. Ham token dev'de test için
 * geri döner (controller prod'da gizler).
 */
export class RequestEmailUpgradeUseCase {
  constructor(
    private readonly users: UserRepository,
    private readonly ott: OneTimeTokenRepository,
    private readonly mailer: Mailer,
    private readonly ids: IdGenerator,
    private readonly clock: Clock,
    private readonly hasher: TokenHasher,
    private readonly opaque: OpaqueTokenGenerator,
    private readonly config: MagicLinkConfig,
  ) {}

  async execute(userId: string, email: string): Promise<string> {
    const normalized = email.trim().toLowerCase();
    const existing = await this.users.findByEmail(normalized);
    if (existing && existing.id !== userId) {
      throw new EmailAlreadyTakenError();
    }

    const raw = this.opaque.generate();
    const now = this.clock.now();
    await this.ott.save({
      id: this.ids.uuid(),
      userId,
      email: normalized,
      purpose: 'magic_link',
      tokenHash: this.hasher.hash(raw),
      expiresAt: new Date(now.getTime() + this.config.ttlSeconds * 1000),
      usedAt: null,
    });

    await this.mailer.sendMagicLink(normalized, `${this.config.baseUrl}?token=${raw}`);
    return raw;
  }
}
