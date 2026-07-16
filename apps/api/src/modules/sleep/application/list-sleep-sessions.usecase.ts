import type { SleepSession } from '../domain/sleep-session.entity';
import type { SleepSessionRepository } from '../domain/ports';

export interface ListSleepSessionsOptions {
  readonly limit?: number;
  /** Gece aralığı (YYYY-MM-DD). from+to birlikte verilirse aralık sorgusu. */
  readonly from?: string;
  readonly to?: string;
}

/** Kullanıcının uyku oturumları — en yeni N veya gece-aralığı (from+to). */
export class ListSleepSessionsUseCase {
  private static readonly DEFAULT_LIMIT = 30;

  constructor(private readonly repo: SleepSessionRepository) {}

  execute(userId: string, opts: ListSleepSessionsOptions = {}): Promise<SleepSession[]> {
    if (opts.from && opts.to) {
      return this.repo.listByNightRange(userId, opts.from, opts.to);
    }
    const capped = Math.min(Math.max(opts.limit ?? ListSleepSessionsUseCase.DEFAULT_LIMIT, 1), 100);
    return this.repo.listRecentByUser(userId, capped);
  }
}
