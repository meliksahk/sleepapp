import { aggregateStats, type SleepStats } from '../domain/stats';
import type { SleepSessionRepository } from '../domain/ports';

/** Kullanıcının son oturumlarından uyku istatistikleri (en fazla son 100 oturum). */
export class GetSleepStatsUseCase {
  private static readonly WINDOW = 100;

  constructor(private readonly repo: SleepSessionRepository) {}

  async execute(userId: string): Promise<SleepStats> {
    const sessions = await this.repo.listRecentByUser(userId, GetSleepStatsUseCase.WINDOW);
    return aggregateStats(sessions);
  }
}
