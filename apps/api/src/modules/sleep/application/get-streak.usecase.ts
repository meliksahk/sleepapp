import { nightDateOf } from '../../../shared/time/night';
import { computeStreak, type StreakStats } from '../domain/streak';
import type { Clock, ProfileTimezoneReader, SleepSessionRepository } from '../domain/ports';

/**
 * Kullanıcının uyku serisi (streak). "Bugün" kullanıcının saat dilimine göre
 * gece etiketiyle belirlenir (nightDateOf); seri bugün/dün'e kadar sürüyorsa canlı.
 */
export class GetStreakUseCase {
  constructor(
    private readonly repo: SleepSessionRepository,
    private readonly timezones: ProfileTimezoneReader,
    private readonly now: Clock,
  ) {}

  async execute(userId: string): Promise<StreakStats> {
    const timezone = await this.timezones.timezoneFor(userId);
    const today = nightDateOf(this.now(), timezone);
    const nightDates = await this.repo.listNightDates(userId);
    return computeStreak(nightDates, today);
  }
}
