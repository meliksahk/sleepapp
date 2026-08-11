import type { SleepSession } from './sleep-session.entity';

/**
 * Gece raporu — bir gecenin oturumlarının özeti (docs/02). Saf domain.
 *
 * **`calmScore` KALDIRILDI (F0).** 0-100 arası "göreli dinginlik" alanı,
 * girdisi olan rahatsızlık sayacı üretimde hiç dolmadığı için gerçek veride
 * SABİTTİ (olay sayısı 0 → skor daima 100). Sabit bir sayıyı skor diye
 * göstermek, ölçmediğimiz bir şeyi ölçmüş gibi sunmaktır — kartta "Calm 100/100"
 * yazması, dürüstlük protokolünün (CLAUDE.md §0) ihlaliydi. Olay sayacı gerçekten
 * çalıştığı gün geri gelebilir; o gün ölçüme dayanır.
 */
export interface NightReport {
  readonly nightDate: string;
  readonly sessionCount: number;
  readonly totalDurationMinutes: number;
  readonly movementEvents: number;
  readonly soundEvents: number;
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
  };
}
