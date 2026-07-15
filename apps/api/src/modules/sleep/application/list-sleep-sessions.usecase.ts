import type { SleepSession } from '../domain/sleep-session.entity';
import type { SleepSessionRepository } from '../domain/ports';

/** Kullanıcının en yeni uyku oturumları (rapor/streak için). */
export class ListSleepSessionsUseCase {
  private static readonly DEFAULT_LIMIT = 30;

  constructor(private readonly repo: SleepSessionRepository) {}

  execute(userId: string, limit?: number): Promise<SleepSession[]> {
    const capped = Math.min(Math.max(limit ?? ListSleepSessionsUseCase.DEFAULT_LIMIT, 1), 100);
    return this.repo.listRecentByUser(userId, capped);
  }
}
