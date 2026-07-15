import type { WaitlistRepository } from '../domain/waitlist';

/** Bekleme listesine katıl — e-posta normalize edilir, idempotent kaydedilir. */
export class JoinWaitlistUseCase {
  constructor(private readonly waitlist: WaitlistRepository) {}

  async execute(email: string, source: string | null): Promise<void> {
    await this.waitlist.add(email.trim().toLowerCase(), source);
  }
}
