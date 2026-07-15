/**
 * Streak/habit hesabı — saf domain (CLAUDE.md streak döngüsü). Gece tarihlerinden
 * (YYYY-MM-DD, oturum kaydı olan geceler) ardışık seri hesaplar. Deterministik.
 */
export interface StreakStats {
  /** Şu anki ardışık gece serisi (bugün veya dün'e kadar sürüyorsa; yoksa 0). */
  readonly current: number;
  /** Tüm zamanların en uzun ardışık serisi. */
  readonly longest: number;
  /** Kayıtlı toplam (benzersiz) gece sayısı. */
  readonly totalNights: number;
}

/** YYYY-MM-DD → epoch gün numarası (UTC). Ardışıklık = fark 1. */
function dayNumber(date: string): number {
  return Math.floor(new Date(`${date}T00:00:00.000Z`).getTime() / 86_400_000);
}

export function computeStreak(nightDates: readonly string[], today: string): StreakStats {
  const days = Array.from(new Set(nightDates))
    .map(dayNumber)
    .sort((a, b) => a - b);
  const totalNights = days.length;
  if (totalNights === 0) return { current: 0, longest: 0, totalNights: 0 };

  let longest = 1;
  let run = 1;
  let currentRun = 1;
  for (let i = 1; i < days.length; i++) {
    const cur = days[i]!;
    const prev = days[i - 1]!;
    if (cur === prev + 1) {
      run += 1;
    } else {
      run = 1;
    }
    longest = Math.max(longest, run);
  }
  // En sondan geriye ardışık say (mevcut seri uzunluğu).
  for (let i = days.length - 1; i > 0; i--) {
    if (days[i]! === days[i - 1]! + 1) currentRun += 1;
    else break;
  }

  const latest = days[days.length - 1]!;
  const todayNum = dayNumber(today);
  // Seri "canlı" ise (son gece bugün veya dün) mevcut sayılır; aksi halde kopmuş.
  const current = latest === todayNum || latest === todayNum - 1 ? currentRun : 0;

  return { current, longest, totalNights };
}
