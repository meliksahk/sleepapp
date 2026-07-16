import { statsFromAggregate, type SleepStats } from '../domain/stats';
import type { SleepSessionRepository } from '../domain/ports';

/**
 * Kullanıcının TÜM kayıtları üzerinden uyku istatistikleri.
 * Eskiden son 100 oturumla sınırlıydı → 100+ gecesi olanda sessizce kısmi veri.
 */
export class GetSleepStatsUseCase {
  constructor(private readonly repo: SleepSessionRepository) {}

  async execute(userId: string): Promise<SleepStats> {
    return statsFromAggregate(await this.repo.aggregateFor(userId));
  }
}
