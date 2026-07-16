import type { SleepSession } from './sleep-session.entity';

/**
 * Haftalık uyku trendi — saf domain. Son N gecenin (bugün dahil, eskiden yeniye)
 * gece-başına toplam süresini verir; oturumu olmayan gece 0'dır. Grafik/özet için.
 * Deterministik: "bugün" (kullanıcı yerel gece etiketi) parametre olarak verilir.
 */
export interface TrendNight {
  /** Gece etiketi YYYY-MM-DD. */
  readonly nightDate: string;
  /** O gecenin toplam uyku süresi (dk); oturum yoksa 0. */
  readonly durationMinutes: number;
}

export interface WeeklyTrend {
  /** Eskiden yeniye sıralı, uzunluk = istenen gün sayısı. */
  readonly nights: readonly TrendNight[];
  /** Yalnızca veri OLAN gecelerin ortalama süresi (yoksa 0). */
  readonly averageDurationMinutes: number;
  /** Aralıkta oturumu olan benzersiz gece sayısı. */
  readonly nightsWithData: number;
}

/** YYYY-MM-DD tarihine gün ekler/çıkarır (UTC takvim aritmetiği, DST-güvenli). */
function shiftNight(nightDate: string, deltaDays: number): string {
  const d = new Date(`${nightDate}T00:00:00.000Z`);
  d.setUTCDate(d.getUTCDate() + deltaDays);
  const y = d.getUTCFullYear().toString().padStart(4, '0');
  const m = (d.getUTCMonth() + 1).toString().padStart(2, '0');
  const day = d.getUTCDate().toString().padStart(2, '0');
  return `${y}-${m}-${day}`;
}

/**
 * [today-(days-1) .. today] penceresindeki oturumları gece-başına toplar.
 * @param sessions aralıktaki oturumlar (fazlası zararsız — yalnızca pencere kullanılır)
 * @param today kullanıcının yerel gece etiketi (YYYY-MM-DD)
 * @param days pencere uzunluğu (varsayılan 7)
 */
export function weeklyTrend(
  sessions: readonly SleepSession[],
  today: string,
  days = 7,
): WeeklyTrend {
  // Gece → toplam süre haritası.
  const byNight = new Map<string, number>();
  for (const s of sessions) {
    byNight.set(s.nightDate, (byNight.get(s.nightDate) ?? 0) + s.durationMinutes);
  }

  const nights: TrendNight[] = [];
  let sumWithData = 0;
  let nightsWithData = 0;
  // Eskiden yeniye: today-(days-1) ... today.
  for (let i = days - 1; i >= 0; i--) {
    const nightDate = shiftNight(today, -i);
    const durationMinutes = byNight.get(nightDate) ?? 0;
    if (byNight.has(nightDate)) {
      sumWithData += durationMinutes;
      nightsWithData += 1;
    }
    nights.push({ nightDate, durationMinutes });
  }

  return {
    nights,
    averageDurationMinutes: nightsWithData === 0 ? 0 : Math.round(sumWithData / nightsWithData),
    nightsWithData,
  };
}
