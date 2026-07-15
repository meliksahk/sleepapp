import type { SleepSession } from './sleep-session.entity';

/**
 * Gece raporu — bir gecenin oturumlarının özeti (docs/02). Saf domain.
 * `calmScore` UYGULAMA-İÇİ göreli bir dinginlik göstergesidir (0-100): saat
 * başına daha az rahatsızlık (hareket+ses olayı) → daha yüksek. SAĞLIK ÖLÇÜSÜ
 * DEĞİL — "relaxation & sleep ritual" çerçevesi (CLAUDE.md §1.1).
 */
export interface NightReport {
  readonly nightDate: string;
  readonly sessionCount: number;
  readonly totalDurationMinutes: number;
  readonly movementEvents: number;
  readonly soundEvents: number;
  readonly calmScore: number;
}

function clamp(n: number, lo: number, hi: number): number {
  return Math.max(lo, Math.min(hi, n));
}

/** Göreli dinginlik göstergesi (0-100). Saf/deterministik. */
export function calmScore(totalDurationMinutes: number, disturbances: number): number {
  const hours = Math.max(totalDurationMinutes / 60, 0.5);
  const ratePerHour = disturbances / hours;
  return clamp(Math.round(100 - ratePerHour * 10), 0, 100);
}

/** Gecenin oturumlarını tek rapora indirger. Oturum yoksa null (rapor yok). */
export function buildNightReport(
  nightDate: string,
  sessions: readonly SleepSession[],
): NightReport | null {
  if (sessions.length === 0) return null;
  const totalDurationMinutes = sessions.reduce((s, x) => s + x.durationMinutes, 0);
  const movementEvents = sessions.reduce((s, x) => s + x.movementEvents, 0);
  const soundEvents = sessions.reduce((s, x) => s + x.soundEvents, 0);
  return {
    nightDate,
    sessionCount: sessions.length,
    totalDurationMinutes,
    movementEvents,
    soundEvents,
    calmScore: calmScore(totalDurationMinutes, movementEvents + soundEvents),
  };
}
