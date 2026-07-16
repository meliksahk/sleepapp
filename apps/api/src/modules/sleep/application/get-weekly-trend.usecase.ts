import { nightDateOf } from '../../../shared/time/night';
import { weeklyTrend, type WeeklyTrend } from '../domain/trend';
import type { Clock, ProfileTimezoneReader, SleepSessionRepository } from '../domain/ports';

/**
 * Son 7 gecenin uyku trendi. "Bugün" kullanıcının saat dilimine göre gece
 * etiketiyle belirlenir; pencere [today-6 .. today] gece aralığından çekilir.
 */
export class GetWeeklyTrendUseCase {
  private static readonly DAYS = 7;

  constructor(
    private readonly repo: SleepSessionRepository,
    private readonly timezones: ProfileTimezoneReader,
    private readonly now: Clock,
  ) {}

  async execute(userId: string): Promise<WeeklyTrend> {
    const timezone = await this.timezones.timezoneFor(userId);
    const today = nightDateOf(this.now(), timezone);
    const from = shift(today, -(GetWeeklyTrendUseCase.DAYS - 1));
    const sessions = await this.repo.listByNightRange(userId, from, today);
    return weeklyTrend(sessions, today, GetWeeklyTrendUseCase.DAYS);
  }
}

function shift(nightDate: string, deltaDays: number): string {
  const d = new Date(`${nightDate}T00:00:00.000Z`);
  d.setUTCDate(d.getUTCDate() + deltaDays);
  const y = d.getUTCFullYear().toString().padStart(4, '0');
  const m = (d.getUTCMonth() + 1).toString().padStart(2, '0');
  const day = d.getUTCDate().toString().padStart(2, '0');
  return `${y}-${m}-${day}`;
}
