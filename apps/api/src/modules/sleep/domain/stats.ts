import type { SleepSession } from './sleep-session.entity';

/** Uyku istatistikleri özeti (son oturumlar üzerinden). Saf domain. */
export interface SleepStats {
  /** Kayıtlı benzersiz gece sayısı. */
  readonly nights: number;
  readonly totalDurationMinutes: number;
  readonly averageDurationMinutes: number;
}

/** Oturumları özet istatistiğe indirger. Oturum yoksa hepsi 0. */
export function aggregateStats(sessions: readonly SleepSession[]): SleepStats {
  if (sessions.length === 0) {
    return { nights: 0, totalDurationMinutes: 0, averageDurationMinutes: 0 };
  }
  const nights = new Set(sessions.map((s) => s.nightDate)).size;
  const totalDurationMinutes = sessions.reduce((sum, s) => sum + s.durationMinutes, 0);
  return {
    nights,
    totalDurationMinutes,
    averageDurationMinutes: Math.round(totalDurationMinutes / sessions.length),
  };
}
