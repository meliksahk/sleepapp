import { nightDateOf } from '../../../shared/time/night';
import { SleepError } from '../domain/errors';
import {
  durationMinutes,
  isValidRange,
  type RecordSleepSessionInput,
  type SleepSession,
} from '../domain/sleep-session.entity';
import type { ProfileTimezoneReader, SleepSessionRepository } from '../domain/ports';

/**
 * Uyku oturumu kaydı. Gece etiketi kullanıcının saat dilimine göre türetilir
 * (nightDateOf, 06:00 sınırı); süre started/ended'den sunucuda hesaplanır.
 * Ham mikrofon verisi hiç uğramaz — yalnızca türetilmiş sayılar (CLAUDE.md §6).
 */
export class RecordSleepSessionUseCase {
  constructor(
    private readonly repo: SleepSessionRepository,
    private readonly timezones: ProfileTimezoneReader,
  ) {}

  async execute(userId: string, input: RecordSleepSessionInput): Promise<SleepSession> {
    if (!isValidRange(input.startedAt, input.endedAt)) {
      throw new SleepError('invalid_range', 'endedAt, startedAt sonrasında olmalı.');
    }
    const timezone = await this.timezones.timezoneFor(userId);
    const nightDate = nightDateOf(input.startedAt, timezone);

    return this.repo.save(userId, {
      startedAt: input.startedAt,
      endedAt: input.endedAt,
      nightDate,
      durationMinutes: durationMinutes(input.startedAt, input.endedAt),
      movementEvents: input.movementEvents,
      soundEvents: input.soundEvents,
    });
  }
}
