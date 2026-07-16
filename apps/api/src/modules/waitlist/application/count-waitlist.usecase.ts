import type { WaitlistRepository } from '../domain/waitlist';

/** Bekleme listesi kayıt sayısı (panel panosu). Waitlist'in PUBLIC servisi. */
export class CountWaitlistUseCase {
  constructor(private readonly repo: WaitlistRepository) {}

  async execute(): Promise<number> {
    return this.repo.count();
  }
}
